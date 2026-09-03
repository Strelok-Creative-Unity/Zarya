#ifndef RF_LPV_SAMPLE_FSH
#define RF_LPV_SAMPLE_FSH

#include "/common/lpvCommon.glsl"

#ifdef LPV_ACTIVE

#include "/common/transformations.glsl"

#ifndef FRAME_COUNTER_UNIFORM
#define FRAME_COUNTER_UNIFORM
uniform int frameCounter;
#endif

uniform sampler3D lpvLightSamplerA;
uniform sampler3D lpvLightSamplerB;
uniform sampler3D lpvVoxelSampler;

vec3 lpvReadVolume(vec3 unitPos) {
   if ((frameCounter & 1) == 0) {
      return texture3D(lpvLightSamplerA, unitPos).rgb;
   }

   return texture3D(lpvLightSamplerB, unitPos).rgb;
}

vec3 lpvSample(vec3 feetPos, vec3 worldNormal, out float coverage) {
   coverage = 0.0;

   vec3 voxelPos = lpvFeetToVoxel(feetPos, cameraPosition);

   if (!lpvInsideVolume(voxelPos)) {
      return vec3(0.0);
   }

   float range = 0.5 * float(LPV_SIZE_XZ);
   coverage = 1.0 - smoothstep(range * 0.64, range * 0.93, length(feetPos.xz));

   vec3 n = worldNormal;
   float nLen = length(n);
   n = nLen > 1.0e-4 ? n / nLen : vec3(0.0, 1.0, 0.0);

   vec3 backCell = floor(voxelPos - n * 0.02);
   int backId = -1;
   if (all(greaterThanEqual(backCell, vec3(0.0)))
    && all(lessThan(backCell, LPV_VOLUME_SIZEF))) {
      vec3 backC = (backCell + 0.5) / LPV_VOLUME_SIZEF;
      backId = lpvUnpackId(texture3D(lpvVoxelSampler, backC).r);
   }
   if (backId >= LPV_ID_EMIT && backId < LPV_ID_TINT) {
      return vec3(0.0);
   }

   vec3 samplePos = voxelPos + n * 0.47;
   vec3 unitPos = clamp(samplePos / LPV_VOLUME_SIZEF, 0.0, 1.0);
   vec3 light = lpvReadVolume(unitPos) * LPV_DISPLAY_SCALE;

   return lpvLimitPeak(light, 2.35);
}

#endif
#endif
