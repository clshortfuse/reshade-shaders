#pragma once

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#define COLOR_SPACE_UNKNOWN   0u
#define COLOR_SPACE_SRGB      1u
#define COLOR_SPACE_SCRGB     2u
#define COLOR_SPACE_HDR10_PQ  3u
#define COLOR_SPACE_HDR10_HLG 4u

#ifndef BUFFER_COLOR_SPACE
#define BUFFER_COLOR_SPACE COLOR_SPACE_UNKNOWN
#endif

#if ((BUFFER_COLOR_SPACE == COLOR_SPACE_UNKNOWN) || (BUFFER_COLOR_SPACE == COLOR_SPACE_SRGB))
#define IS_SDR
#else
#define IS_HDR
#endif

namespace math {
static const float FLT10_MAX = 64512.f;
static const float FLT11_MAX = 65024.f;

static const float FLT16_MIN = 0.00006103515625f;
static const float FLT16_MAX = 65504.f;
static const float FLT32_MIN = 1.17549435082228750797e-38f;
static const float FLT32_MAX = 3.40282346638528859812e+38f;
static const float FLT_MIN = FLT32_MIN;
static const float FLT_MAX = FLT32_MAX;
static const float INFINITY = (1.0 / 0.0);
static const float NEG_INFINITY = (-1.0 / 0.0);
static const float PI = 3.14159265358979323846f;

float Sign(float x) {
  return mad(saturate(mad(x, FLT_MAX, 0.5f)), 2.f, -1.f);
}

float3 Sign(float3 x) {
  return mad(saturate(mad(x, FLT_MAX, 0.5f)), 2.f, -1.f);
}

float SignPow(float value, float exponent) {
  return Sign(value) * pow(abs(value), exponent);
}
float3 SignPow(float3 value, float exponent) {
  return Sign(value) * pow(abs(value), exponent);
}
}  // namespace math

namespace srgb {
float Encode(float channel) {
  return (channel <= 0.0031308f) ? (channel * 12.92f)
                                 : (1.055f * pow(channel, 1.f / 2.4f) - 0.055f);
}
float3 Encode(float3 color) {
  return float3(
      Encode(color.r),
      Encode(color.g),
      Encode(color.b));
}

float EncodeSafe(float color) {
  return sign(color) * Encode(abs(color));
}

float3 EncodeSafe(float3 color) {
  return sign(color) * Encode(abs(color));
}

float Decode(float channel) {
  return (channel <= 0.04045f) ? (channel / 12.92f)
                               : pow((channel + 0.055f) / 1.055f, 2.4f);
}
float3 Decode(float3 color) {
  return float3(
      Decode(color.r),
      Decode(color.g),
      Decode(color.b));
}

float DecodeSafe(float color) {
  return sign(color) * Decode(abs(color));
}

float3 DecodeSafe(float3 color) {
  return sign(color) * Encode(abs(color));
}

}  // namespace srgb

namespace gamma {
float Encode(float color, float gamma = 2.2f) {
  return pow(color, 1.f / gamma);
}

float3 Encode(float3 color, float gamma = 2.2f) {
  return pow(color, 1.f / gamma);
}

float EncodeSafe(float color, float gamma = 2.2f) {
  return math::SignPow(color, 1.f / gamma);
}

float3 EncodeSafe(float3 color, float gamma = 2.2f) {
  return math::SignPow(color, 1.f / gamma);
}

float Decode(float color, float gamma = 2.2f) {
  return pow(color, gamma);
}

float3 Decode(float3 color, float gamma = 2.2f) {
  return pow(color, gamma);
}

}  // namespace gamma

namespace pq {
static const float M1 = 2610.f / 16384.f;           // 0.1593017578125f;
static const float M2 = 128.f * (2523.f / 4096.f);  // 78.84375f;
static const float C1 = 3424.f / 4096.f;            // 0.8359375f;
static const float C2 = 32.f * (2413.f / 4096.f);   // 18.8515625f;
static const float C3 = 32.f * (2392.f / 4096.f);   // 18.6875f;

float3 Encode(float3 color, float scaling = 10000.f) {
  color *= (scaling / 10000.f);
  float3 y_m1 = pow(color, M1);
  return pow((C1 + C2 * y_m1) / (1.f + C3 * y_m1), M2);
}

float3 Decode(float3 color, float scaling = 10000.f) {
  float3 e_m12 = pow(color, 1.f / M2);
  float3 out_color = pow(max(0, e_m12 - C1) / (C2 - C3 * e_m12), 1.f / M1);
  return out_color * (10000.f / scaling);
}
}  // namespace pq

namespace correct {
float Gamma(float x, bool pow_to_srgb = false, float gamma_value = 2.2f) {
  if (pow_to_srgb) {
    return srgb::Decode(gamma::Encode(x, gamma_value));
  } else {
    return gamma::Decode(srgb::Encode(x), gamma_value);
  }
}

float GammaSafe(float x, bool pow_to_srgb = false, float gamma_value = 2.2f) {
  if (pow_to_srgb) {
    return sign(x) * srgb::Decode(gamma::Encode(abs(x), gamma_value));
  } else {
    return sign(x) * gamma::Decode(srgb::Encode(abs(x)), gamma_value);
  }
}

float3 Gamma(float3 color, bool pow_to_srgb = false, float gamma_value = 2.2f) {
  [branch]
  if (pow_to_srgb) {
    return srgb::Decode(gamma::Encode(color, gamma_value));
  } else {
    return gamma::Decode(srgb::Encode(color), gamma_value);
  }
}

float3 GammaSafe(float3 color, bool pow_to_srgb = false, float gamma_value = 2.2f) {
  return math::Sign(color) * Gamma(abs(color), pow_to_srgb, gamma_value);
}

float4 Gamma(float4 color, bool pow_to_srgb = false, float gamma_value = 2.2f) {
  return float4(Gamma(color.rgb, pow_to_srgb, gamma_value), color.a);
}

float4 GammaSafe(float4 color, bool pow_to_srgb = false, float gamma_value = 2.2f) {
  return float4(Gamma(color.rgb, pow_to_srgb, gamma_value), color.a);
}
}

namespace core {
float3 DecodeBackBuffer(float3 inputColor, float diffuse_white_nits = 203.f) {
  float3 linearColor = inputColor;
  switch (BUFFER_COLOR_SPACE) {
    default:
    case COLOR_SPACE_UNKNOWN:
    case COLOR_SPACE_SRGB:
      linearColor = srgb::Decode(inputColor);
      break;
    case COLOR_SPACE_SCRGB:
      linearColor = inputColor / diffuse_white_nits * 80.f;
      break;
    case COLOR_SPACE_HDR10_PQ:
      linearColor = pq::Decode(inputColor, diffuse_white_nits);
      break;
  }
  return linearColor;
}

float3 EncodeBackBuffer(float3 inputColor, float diffuse_white_nits = 203.f) {
  float3 outputColor = inputColor;
  switch (BUFFER_COLOR_SPACE) {
    default:
    case COLOR_SPACE_UNKNOWN:
    case COLOR_SPACE_SRGB:
      outputColor = srgb::Encode(inputColor);
      break;
    case COLOR_SPACE_SCRGB:
      outputColor = inputColor * diffuse_white_nits / 80.f;
      break;
    case COLOR_SPACE_HDR10_PQ:
      outputColor = pq::Encode(inputColor, diffuse_white_nits);
      break;
  }
  return outputColor;
}
}  // namespace core

// Slang helpers
#if defined(__SLANG__)
#define tex2D Texture2D
#endif 