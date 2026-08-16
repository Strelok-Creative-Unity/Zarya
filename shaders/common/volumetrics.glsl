#ifndef VOLUMETRICS_GLSL
#define VOLUMETRICS_GLSL

#ifndef RAIN_STRENGTH_UNIFORM
#define RAIN_STRENGTH_UNIFORM
uniform float rainStrength;
#endif

#if defined VL && defined OVERWORLD && defined ENABLE_SHADOWS
#include "/common/shadowVis.glsl"

// MIT ref: David Hoskins — Hash without Sine (hash12)
// Source: https://www.shadertoy.com/view/4djSRW
// License text: THIRD_PARTY_NOTICES.md
float volumetricsDither(vec2 p) {
   vec3 m = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
   m += dot(m, m.yzx + 33.33);
   return fract((m.x + m.y) * m.z);
}

vec3 computeVolumetrics(vec3 viewPos, vec3 sunCol) {
   float sceneDist = length(viewPos);
   float maxDist = min(sceneDist, min(shadowDistance * 0.85, 160.0));
   if (maxDist < 1.0) {
      return vec3(0.0);
   }

   vec3 rayDir = normalize(viewPos);
   vec3 lightDir = normalize(shadowLightPosition);
   float VoL = clamp(dot(rayDir, lightDir), 0.0, 1.0);
   float phase = 0.16 + pow(VoL, 3.0) * 0.85 + pow(VoL, 8.0) * 0.95;

   float dither = volumetricsDither(gl_FragCoord.xy);

   vec3 accum = vec3(0.0);
   float weightSum = 0.0;
   float litSum = 0.0;
   float stepLen = maxDist / float(VL_SAMPLES);

   for (int i = 0; i < VL_SAMPLES; i++) {
      float t = (float(i) + dither) * stepLen;
      if (t >= maxDist) {
         continue;
      }

      float w = 1.0 - 0.45 * (t / maxDist);

      vec3 posView = rayDir * t;
      vec3 posFeet = view2feet(posView);

      #if SHADOW_PIXEL > 0
         vec3 pos = world2feet(bandify(feet2world(posFeet), SHADOW_PIXEL));
      #else
         vec3 pos = posFeet;
      #endif

      float lit = shadowVisibility(pos);
      float worldY = feet2world(posFeet).y;
      float heightAtt = exp(-max(worldY - 64.0, 0.0) * 0.008);
      float sampleW = w * heightAtt;

      accum += vec3(lit) * sampleW;
      litSum += lit * sampleW;
      weightSum += sampleW;
   }

   if (weightSum < 1e-4) {
      return vec3(0.0);
   }

   accum /= weightSum;
   float avgLit = litSum / weightSum;

   float openWash = smoothstep(0.70, 0.94, avgLit) * pow(VoL, 4.5);
   float sunKeep = mix(1.0, 0.12, openWash);

   float sunUp = view2feet(shadowLightPosition).y;
   float duskBoost = 1.0 + 1.15 * exp(-sunUp * sunUp * 28.0) * smoothstep(-0.25, 0.08, sunUp);
   float intensity = VL_STRENGTH * 1.85 * duskBoost * (1.0 - rainStrength * 0.65);

   return accum * sunCol * phase * intensity * sunKeep;
}
#endif

#endif
