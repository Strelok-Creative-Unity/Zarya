#ifndef FOG_RANGE_UNIFORMS
#define FOG_RANGE_UNIFORMS
uniform float fogEnd, fogStart;
uniform float near, far;
#endif

#ifdef DISTANT_HORIZONS
   #ifndef DH_RANGE_UNIFORMS
   #define DH_RANGE_UNIFORMS
   uniform float dhFarPlane;
   uniform int dhRenderDistance;
   #endif
#endif

float calcFogMix(vec3 feetPos, float fogStartMult, float fogFar) {
   float len = length(feetPos);
   float horiz = length(feetPos.xz);

   return max(
      rescale(len, fogStartMult * fogStart, fogEnd),
      rescale(mix(len, horiz, 0.4), fogStartMult * (fogFar - clamp(0.1 * fogFar, 4.0, 64.0)), fogFar)
   );
}

float getFogFarLimit() {
   #ifdef DISTANT_HORIZONS
      return max(far, max(dhFarPlane, float(dhRenderDistance)));
   #elif defined VOXY && !defined GBUFFERS_SKYBASIC && !defined GBUFFERS_CLOUDS
      return 48000.0;
   #else
      return far;
   #endif
}

float getTerrainFogMix(vec3 feetPos) {
   float fogFar = getFogFarLimit();

   #if defined VOXY && !defined GBUFFERS_SKYBASIC && !defined GBUFFERS_CLOUDS
      float near = 16.0;
   #endif

   #ifndef ENABLE_FOG
      if (fogEnd >= fogFar) {
         return 0.0;
      }
   #endif

   #if MC_VERSION >= 11700
      bool blindnessFog = fogEnd + 1.0 < far;

      if (blindnessFog) {
         return calcFogMix(feetPos, 1.0, far);
      }

      #if defined GBUFFERS_SKYBASIC
         return 0.0;
      #elif defined GBUFFERS_CLOUDS
         return clamp((length(feetPos) - fogFar) * (near * 0.01), 0.0, 1.0);
      #else
         #ifdef OVERWORLD
            float x = worldTime * NORMALIZE_TIME;

            x = clamp(25.0*(x < MIDNIGHT ? SUNSET - x : x - SUNRISE) + 0.3,
                     OVERWORLD_FOG_MIN,
                     OVERWORLD_FOG_MAX);

            x = min(x, 1.0 - rainStrength);
         #else
            float x = 1.0;
         #endif

         #ifdef DISTANT_HORIZONS
            float len = mix(length(feetPos), length(feetPos.xz), 0.4);
            #ifdef THE_END
               float start = x * max(fogFar * 0.28, far * 1.15);
               float distant = rescale(len, start, fogFar);
               float seam = smoothstep(far * 0.48, far * 2.1, len) * 0.40;
            #else
               float start = x * max(fogFar * 0.45, far * 2.0);
               float distant = rescale(len, start, fogFar);
               float seam = smoothstep(far * 0.55, far * 2.4, len) * 0.32;
            #endif
            return max(distant, seam);
         #else
            return calcFogMix(feetPos, x, fogFar);
         #endif
      #endif
   #else
      float len = length(feetPos);
      return clamp((len - fogStart) / max(fogEnd - fogStart, 1.0e-3), 0.0, 1.0);
   #endif
}

float getFogMix(vec3 feetPos) {
   #ifdef WATER_FOG
      if (isEyeInWater > 0) {
         return 0.0;
      }
   #endif

   #if defined AIR_FOG && defined OVERWORLD && MC_VERSION >= 11700
      if (!(fogEnd + 1.0 < far)) {
         return 0.0;
      }
   #endif

   #if defined NETHER_FOG && defined THE_NETHER && MC_VERSION >= 11700
      if (!(fogEnd + 1.0 < far)) {
         return 0.0;
      }
   #endif

   #if defined END_FOG && defined THE_END && MC_VERSION >= 11700
      if (!(fogEnd + 1.0 < far)) {
         return 0.0;
      }
   #endif

   return getTerrainFogMix(feetPos);
}
