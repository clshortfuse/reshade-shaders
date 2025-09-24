#include "ShortFuse.fxh"

// Convert Kelvin temperature to CIE 1931 XYZ white point (daylight locus approximation)
// eg: 6500 returns float3(0.95047, 1.00000, 1.08883)
float3 KelvinToWhiteXYZ(float T) {
  // T = clamp(T, 4000.0, 25000.0);

  float x_D = (T <= 7000.0)
                  ? (-4.6070e9 / (T * T * T)) + (2.9678e6 / (T * T)) + (99.11 / T) + 0.244063
                  : (-2.0064e9 / (T * T * T)) + (1.9018e6 / (T * T)) + (247.48 / T) + 0.237040;

  float y_D = (-3.0 * x_D * x_D) + (2.87 * x_D) - 0.275;

  float Y = 1.0;
  float X = x_D / y_D;
  float Z = (1.0 - x_D - y_D) / y_D;

  return float3(X, Y, Z);
}

// Build Bradford chromatic adaptation matrix from source to target white point
float3x3 ChromaticAdaptationMatrix(float3 srcWhiteXYZ, float3 dstWhiteXYZ) {
  const float3x3 M_Bradford = float3x3(
      0.8951, 0.2664, -0.1614,
      -0.7502, 1.7135, 0.0367,
      0.0389, -0.0685, 1.0296);

  const float3x3 M_BradfordInv = float3x3(
      0.9869929, -0.1470543, 0.1599627,
      0.4323053, 0.5183603, 0.0492912,
      -0.0085287, 0.0400428, 0.9684867);

  float3 srcLMS = mul(M_Bradford, srcWhiteXYZ);
  float3 dstLMS = mul(M_Bradford, dstWhiteXYZ);
  float3 scale = dstLMS / max(srcLMS, 1e-5); // Safe division

  float3x3 ScaleMatrix = float3x3(
      scale.x, 0, 0,
      0, scale.y, 0,
      0, 0, scale.z);

  return mul(M_BradfordInv, mul(ScaleMatrix, M_Bradford));
}

// Adapt XYZ color from one white point to another using Kelvin temperatures
float3 AdaptXYZKelvin(float3 inputXYZ, float srcKelvin, float dstKelvin) {
  float3 srcWhiteXYZ = KelvinToWhiteXYZ(srcKelvin);
  float3 dstWhiteXYZ = KelvinToWhiteXYZ(dstKelvin);

  float3x3 adaptation = ChromaticAdaptationMatrix(srcWhiteXYZ, dstWhiteXYZ);
  return mul(adaptation, inputXYZ);
}

#ifdef __RESHADE__

uniform float KELVIN_INPUT < ui_type = "slider";
ui_min = 1500;
ui_max = 10000;
ui_step = 1;
ui_label = "Input Temperature";
> = 6500;

uniform float KELVIN_OUTPUT < ui_type = "slider";
ui_min = 1500;
ui_max = 10000;
ui_step = 1;
ui_label = "Output Temperature";
> = 6500;

uniform uint SDR_EOTF < ui_type = "combo";
ui_label = "SDR EOTF";
ui_items =
    "sRGB\0"
    "2.2\0" "2.4\0";
#ifndef IS_SDR
hidden = true;
#endif
> = 1u;

#else
#define KELVIN_OUTPUT 6500.f
#define SDR_EOTF      1u
#endif

#define DIFFUSE_WHITE_NITS 203.f

float3 main(float4 pos: SV_Position, float2 texcoord: TexCoord) : COLOR {
  const float3 input_color = tex2D(ReShade::BackBuffer, texcoord).rgb;
  float3 linear_color = core::DecodeBackBuffer(input_color, DIFFUSE_WHITE_NITS);

  float3 xyz_color;
  if (BUFFER_COLOR_SPACE == COLOR_SPACE_HDR10_PQ) {
    xyz_color = mul(color::BT2020_TO_XYZ_MAT, linear_color);
  } else {
    xyz_color = mul(color::BT709_TO_XYZ_MAT, linear_color);
  }

  xyz_color = AdaptXYZKelvin(xyz_color, KELVIN_INPUT, KELVIN_OUTPUT);

  if (BUFFER_COLOR_SPACE == COLOR_SPACE_HDR10_PQ) {
    linear_color = mul(color::XYZ_TO_BT2020_MAT, xyz_color);
  } else {
    linear_color = mul(color::XYZ_TO_BT709_MAT, xyz_color);
  }

  float3 output_color =
      core::EncodeBackBuffer(linear_color, DIFFUSE_WHITE_NITS);

  return output_color;
}

#ifdef __RESHADE__
technique ShortFuseColorTemperature {
  pass {
    VertexShader = PostProcessVS;
    PixelShader = main;
  }
}
#endif 