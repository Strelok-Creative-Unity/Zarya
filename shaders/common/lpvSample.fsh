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

vec3 lpvFetchLight(ivec3 pos) {
   if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, LPV_VOLUME_SIZE))) {
      return vec3(0.0);
   }

   if ((frameCounter & 1) == 0) {
      return texelFetch(lpvLightSamplerA, pos, 0).rgb;
   }

   return texelFetch(lpvLightSamplerB, pos, 0).rgb;
}

bool lpvSkipLightTap(float raw) {
   int id = lpvUnpackId(raw);

   if (id >= LPV_ID_EMIT && id < LPV_ID_TINT) {
      return true;
   }
   if (id >= LPV_ID_LEVEL) {
      return true;
   }
   if (id == LPV_ID_SOLID) {
      return !lpvCellPorous(raw, id);
   }

   return false;
}

vec3 lpvGather(vec3 samplePos) {
   vec3 texPos = samplePos - 0.5;
   ivec3 base = ivec3(floor(texPos));
   vec3 f = fract(texPos);
   vec3 w0 = 1.0 - f;
   vec3 w1 = f;

   vec3 acc = vec3(0.0);
   float wsum = 0.0;

   for (int i = 0; i < 8; i++) {
      ivec3 o = ivec3(i & 1, (i >> 1) & 1, (i >> 2) & 1);
      ivec3 p = base + o;
      if (any(lessThan(p, ivec3(0))) || any(greaterThanEqual(p, LPV_VOLUME_SIZE))) {
         continue;
      }

      float raw = texelFetch(lpvVoxelSampler, p, 0).r;
      if (lpvSkipLightTap(raw)) {
         continue;
      }

      float w = (o.x == 0 ? w0.x : w1.x)
              * (o.y == 0 ? w0.y : w1.y)
              * (o.z == 0 ? w0.z : w1.z);
      acc += w * lpvFetchLight(p);
      wsum += w;
   }

   return wsum > 1.0e-6 ? acc / wsum : vec3(0.0);
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

   vec3 light = lpvGather(voxelPos + n * 0.55) * LPV_DISPLAY_SCALE;

   return lpvLimitPeak(light, 2.35);
}

#endif
#endif
