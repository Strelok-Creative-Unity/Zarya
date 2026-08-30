#include "/shader.h"
#include "/common/lpvCommon.glsl"

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

#if LPV_SIZE == 64
   const ivec3 workGroups = ivec3(16, 16, 16);
#elif LPV_SIZE == 96
   const ivec3 workGroups = ivec3(24, 24, 24);
#elif LPV_SIZE == 128
   const ivec3 workGroups = ivec3(32, 32, 32);
#else
   const ivec3 workGroups = ivec3(48, 48, 48);
#endif

#ifdef LPV_ACTIVE

#include "/common/lpvColors.glsl"

uniform int frameCounter;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform sampler3D lpvVoxelSampler;
uniform sampler3D lpvLightSamplerA;
uniform sampler3D lpvLightSamplerB;

layout(rgba16f) uniform writeonly image3D lpvLightImgA;
layout(rgba16f) uniform writeonly image3D lpvLightImgB;

void lpvDecodeCell(int id, bool porous, ivec3 pos, out vec3 inject, out vec3 trans) {
   inject = vec3(0.0);
   trans = vec3(1.0);

   if (id >= LPV_ID_LEVEL) {
      inject = lpvLevelRgb(id - LPV_ID_LEVEL);
      trans = porous ? vec3(1.0) : vec3(0.0);
   } else if (id >= LPV_ID_TINT) {
      vec3 tint = lpvTintRgb(id - LPV_ID_TINT);
      trans = exp((tint - vec3(1.0)) * 2.2);
   } else if (id >= LPV_ID_EMIT) {
      float intensity = 1.0;
      #ifdef FLOWER_FESTIVAL
         if (id >= LPV_ID_EMIT + LPV_EMIT_FLOWER && id <= LPV_ID_EMIT + LPV_EMIT_FLOWER_DARK) {
            vec3 rel = vec3(pos) - 0.5 * LPV_VOLUME_SIZEF;
            float falloff = clamp((length(rel) - EVENT_FLOWER_FADE_START) / max(EVENT_FLOWER_FADE_END - EVENT_FLOWER_FADE_START, 0.001), 0.0, 1.0);
            float fade = 1.0 - falloff * falloff * (3.0 - 2.0 * falloff);
            intensity = fade * EVENT_FLOWER_BRIGHTNESS;
         }
      #endif
      inject = lpvEmitRgb(id - LPV_ID_EMIT) * intensity;
      trans = porous ? vec3(1.0) : vec3(0.0);
   } else if (id == LPV_ID_SOLID) {
      trans = porous ? vec3(1.0) : vec3(0.0);
   }
}

vec3 lpvLoadPrev(sampler3D lightSampler, ivec3 pos) {
   if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, LPV_VOLUME_SIZE))) {
      return vec3(0.0);
   }

   return texelFetch(lightSampler, pos, 0).rgb;
}

vec3 lpvFaceFlow(sampler3D lightSampler, ivec3 pos) {
   vec3 n0 = lpvLoadPrev(lightSampler, pos + ivec3( 1,  0,  0));
   vec3 n1 = lpvLoadPrev(lightSampler, pos + ivec3(-1,  0,  0));
   vec3 n2 = lpvLoadPrev(lightSampler, pos + ivec3( 0,  1,  0));
   vec3 n3 = lpvLoadPrev(lightSampler, pos + ivec3( 0, -1,  0));
   vec3 n4 = lpvLoadPrev(lightSampler, pos + ivec3( 0,  0,  1));
   vec3 n5 = lpvLoadPrev(lightSampler, pos + ivec3( 0,  0, -1));

   float e0 = dot(n0, n0);
   float e1 = dot(n1, n1);
   float e2 = dot(n2, n2);
   float e3 = dot(n3, n3);
   float e4 = dot(n4, n4);
   float e5 = dot(n5, n5);

   vec3 mean = (n0 + n1 + n2 + n3 + n4 + n5) * (1.0 / 6.0);
   float energyW = e0 + e1 + e2 + e3 + e4 + e5;
   vec3 energy = energyW > 1.0e-8
      ? (n0 * e0 + n1 * e1 + n2 * e2 + n3 * e3 + n4 * e4 + n5 * e5) / energyW
      : mean;

   return mix(mean, energy, 0.6);
}

void main() {
   ivec3 pos = ivec3(gl_GlobalInvocationID);

   if (any(greaterThanEqual(pos, LPV_VOLUME_SIZE))) {
      return;
   }

   ivec3 prevPos = pos + ivec3(floor(cameraPosition) - floor(previousCameraPosition));
   bool writeA = (frameCounter & 1) == 0;

   float raw = texelFetch(lpvVoxelSampler, pos, 0).r;
   int id = lpvUnpackId(raw);
   bool porous = lpvCellPorous(raw, id);

   vec3 inject;
   vec3 trans;
   lpvDecodeCell(id, porous, pos, inject, trans);

   float decay = mix(0.70, 0.88, clamp((LPV_FALLOFF - 0.88) / 0.11, 0.0, 1.0));
   vec3 light = inject;

   if (frameCounter > 0 && lpvPeak(trans) > 1.0e-5) {
      vec3 incoming = writeA
         ? lpvFaceFlow(lpvLightSamplerB, prevPos)
         : lpvFaceFlow(lpvLightSamplerA, prevPos);

      light = lpvPickStronger(inject, incoming * trans * decay);
   }

   light = lpvLimitPeak(light, 14.0);

   if (writeA) {
      imageStore(lpvLightImgA, pos, vec4(light, 0.0));
   } else {
      imageStore(lpvLightImgB, pos, vec4(light, 0.0));
   }
}

#else

void main() {}

#endif
