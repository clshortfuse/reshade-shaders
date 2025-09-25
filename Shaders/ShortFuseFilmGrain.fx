#include "ShortFuse.fxh"

// Better random generator
// https://web.archive.org/web/20130701000000*/http://lumina.sourceforge.net/Tutorials/Noise.html
float rand(float2 uv) {
  return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

// This is an attempt to replicate Kodak Vision 5242 with (0,3) range:
// Should be channel independent (R/G/B), but just using R curve for now
// Reference target is actually just luminance * 2.046f;
// (0, 0)
// (0.5, 0.22)
// (1.5, 1.08)
// (2.5, 2.01)
// (3.0, 2.3)
float computeFilmDensity(float luminance) {
  float scaledX = luminance * 3.0f;
  float result = 3.386477f + (0.08886645f - 3.386477f) / pow(1.f + (scaledX / 2.172591f), 2.240936f);
  return result;
}

// Bartleson
// https://www.imaging.org/common/uploaded%20files/pdfs/Papers/2003/PICS-0-287/8583.pdf
float computeFilmGraininess(float density) {
  float preComputedMin = 7.5857757502918375f;
  if (density < 0)
    return 0;  // Because Luminance can be negative, pow can be unsafe
  float bofDOverC = 0.880f - (0.736f * density) - (0.003f * pow(density, 7.6f));
  return pow(10.f, bofDOverC);
}

float3 computeFilmGrain(float3 color, float2 xy, float seed, float strength,
                        float paperWhite, bool debug) {
  float randomNumber = rand(xy + seed);

  // Film grain is based on film density
  // Film works in negative, meaning black has no density
  // The greater the film density (lighter), more perceived grain
  // Simplified, grain scales with Y

  // Scaling is not not linear

  float colorY = dot(color, float3(0.2126, 0.7152, 0.0722));
  //
  float adjustedColorY = colorY * (1.f / paperWhite);

  // Emulate density from a chosen film stock (Removed)
  // float density = computeFilmDensity(adjustedColorY);

  // Ideal film density matches 0-3. Skip emulating film stock
  // https://www.mr-alvandi.com/technique/measuring-film-speed.html
  float density = adjustedColorY * 3.f;

  float graininess = computeFilmGraininess(density);
  float randomFactor = (randomNumber * 2.f) - 1.f;
  float boost = 1.667f;  // Boost max to 0.05

  float yChange = randomFactor * graininess * strength * boost;
  float3 outputColor = color * (1.f + yChange);

  if (debug) {
    // Output Visualization
    outputColor = abs(yChange) * paperWhite;
  }

  return outputColor;
}

#ifdef IS_RESHADE
uniform float FILM_GRAIN_STRENGTH < ui_type = "slider";
ui_min = 0;
ui_max = 100;
ui_step = 1;
ui_label = "Strength";
ui_tooltip = "Strength of film grain";
> = 50;

uniform uint SDR_EOTF < ui_type = "combo";
ui_label = "SDR EOTF";
ui_items =
    "sRGB\0"
    "2.2\0" "2.4\0";
#ifndef IS_SDR
hidden = true;
#endif
> = 1u;

uniform float DIFFUSE_WHITE_NITS < ui_type = "slider";
ui_min = 80;
ui_max = 500;
ui_step = 1;
ui_label = "Diffuse White Nits";
#ifndef IS_HDR
hidden = true;
#endif
> = 203;

uniform bool DEBUG_ON < ui_type = "slider";
ui_label = "Debug";
> = 0;

uniform float timer < source = "timer";
> ;

#else
#define FILM_GRAIN_STRENGTH 50.f
#define SDR_EOTF            1u
#define DIFFUSE_WHITE_NITS  203.f
#define DEBUG_ON            0.f
#define timer               0.f
#endif

float3 main(float4 pos: SV_Position, float2 texcoord: TexCoord) : COLOR {
  const float3 input_color = tex2D(ReShade::BackBuffer, texcoord).rgb;
  float3 linear_color = core::DecodeBackBuffer(input_color, DIFFUSE_WHITE_NITS);

  float3 grained_color = computeFilmGrain(
      linear_color, texcoord.xy, frac(timer / 1000.f),
      (FILM_GRAIN_STRENGTH * 0.02f) * 0.03f, 1.f, DEBUG_ON == 1.f);

  float3 output_color = core::EncodeBackBuffer(grained_color, DIFFUSE_WHITE_NITS);

  return output_color;
}

#ifdef IS_RESHADE
technique ShortFuseFilmGrain {
  pass {
    VertexShader = PostProcessVS;
    PixelShader = main;
  }
}
#endif 