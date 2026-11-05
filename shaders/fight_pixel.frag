#version 460 core

// Jungle Fist pixel look: turns a low-resolution render into pixel art.
//
// Drawn 1:1 into an offscreen image the size of the low-res render, so
// FlutterFragCoord() is exactly the texel being produced. For each texel:
//   - transparent texels next to an opaque one become the ink outline (when
//     uInk.a > 0), which gives sprites their one-pixel dark border;
//   - opaque texels snap to the nearest palette colour, optionally after a
//     4x4 Bayer offset (uDither > 0) so gradients become classic dithering.
// The result is upscaled by the caller with nearest-neighbour sampling.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;      // low-res image size in texels
uniform float uPalCount; // colours used from uPal (<= 64)
uniform float uDither;   // Bayer strength in 0..1 colour units, 0 = off
uniform vec4 uInk;       // outline colour (premultiplied), alpha 0 = no outline

uniform sampler2D uTex;  // the low-res render
uniform sampler2D uPal;  // 64x1 palette

out vec4 fragColor;

float bayer(vec2 p) {
  int x = int(mod(p.x, 4.0));
  int y = int(mod(p.y, 4.0));
  int i = y * 4 + x;
  // 0 8 2 10 / 12 4 14 6 / 3 11 1 9 / 15 7 13 5
  float v = 0.0;
  if (i == 0) v = 0.0; else if (i == 1) v = 8.0; else if (i == 2) v = 2.0; else if (i == 3) v = 10.0;
  else if (i == 4) v = 12.0; else if (i == 5) v = 4.0; else if (i == 6) v = 14.0; else if (i == 7) v = 6.0;
  else if (i == 8) v = 3.0; else if (i == 9) v = 11.0; else if (i == 10) v = 1.0; else if (i == 11) v = 9.0;
  else if (i == 12) v = 15.0; else if (i == 13) v = 7.0; else if (i == 14) v = 13.0; else v = 5.0;
  return v / 16.0 - 0.5;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 px = 1.0 / uSize;
  vec2 uv = p * px;
  vec4 c = texture(uTex, uv);

  if (c.a < 0.45) {
    float n = texture(uTex, uv + vec2(px.x, 0.0)).a
            + texture(uTex, uv - vec2(px.x, 0.0)).a
            + texture(uTex, uv + vec2(0.0, px.y)).a
            + texture(uTex, uv - vec2(0.0, px.y)).a;
    fragColor = (uInk.a > 0.0 && n > 0.45) ? uInk : vec4(0.0);
    return;
  }

  vec3 col = c.rgb / max(c.a, 0.001);
  col = clamp(col + vec3(bayer(p) * uDither), 0.0, 1.0);

  float best = 1e9;
  vec3 pick = col;
  for (int i = 0; i < 64; i++) {
    vec3 q = texture(uPal, vec2((float(i) + 0.5) / 64.0, 0.5)).rgb;
    vec3 d = q - col;
    float e = dot(d * d, vec3(0.30, 0.59, 0.11)) + step(uPalCount, float(i)) * 1e6;
    if (e < best) {
      best = e;
      pick = q;
    }
  }
  fragColor = vec4(pick, 1.0);
}
