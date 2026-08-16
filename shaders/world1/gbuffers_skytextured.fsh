#version 120

#define THE_END

#include "/shader.h"

uniform float frameTimeCounter;
uniform sampler2D gtexture;
uniform vec3 fogColor;

varying vec2 texUV;
varying vec3 feetPos;
varying vec3 viewDir;
varying vec4 color;

void main() {
   vec4 albedo = texture2D(gtexture, texUV) * color;

   #if MC_VERSION >= 12100
      albedo.rgb = mix(albedo.rgb, albedo.rgb * fogColor, 0.9);
   #endif

   float theta   = mod(atan(feetPos.y, feetPos.x), PI) - HALF_PI;
   float phi     = acos(feetPos.z / length(feetPos))   - HALF_PI;
   float slice   = ceil(atan(theta, phi) * END_STARS_AMOUNT);
   float offset  = cos(slice);
   float invDist = offset / (theta*theta + phi*phi);

   float period = max(float(END_STARS_PERIOD), 1.0);
   float u = fract(frameTimeCounter / period + END_STARS_PHASE);
   float raw = max(float(END_STARS_SPEED), 0.0);
   float passes = raw <= 1.0e-8
      ? 0.0
      : max(floor(period * raw + 0.5), 1.0);
   float time = u * passes;

   slice *= offset;

   vec4 stars = exp(fract(invDist + slice + time) * -END_STARS_DRAG) / invDist;
   stars = clamp(stars, vec4(0.0), vec4(1.0)) * END_STARS_OPACITY;

   float down = clamp(-normalize(viewDir).y, 0.0, 1.0);
   float voidAmt = smoothstep(0.08, 0.62, down);

   stars *= 1.0 - voidAmt;
   albedo.rgb *= mix(1.0, 0.02, voidAmt);

   gl_FragData[0] = albedo + stars;
}
