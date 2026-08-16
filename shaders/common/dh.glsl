#ifdef DISTANT_HORIZONS

uniform float dhNearPlane;
#ifndef DH_RANGE_UNIFORMS
#define DH_RANGE_UNIFORMS
uniform float dhFarPlane;
uniform int dhRenderDistance;
#endif
uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;

uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;

#ifndef DH_BLOCK_LEAVES
   #define DH_BLOCK_LEAVES 1
#endif
#ifndef DH_BLOCK_LAVA
   #define DH_BLOCK_LAVA 7
#endif
#ifndef DH_BLOCK_WATER
   #define DH_BLOCK_WATER 8
#endif
#ifndef DH_BLOCK_ILLUMINATED
   #define DH_BLOCK_ILLUMINATED 15
#endif

float dhBayer2(vec2 p) {
   p = floor(p);
   return fract(1.5 * p.x + p.y * 0.75);
}

float dhBayer4(vec2 p) {
   return 0.25 * dhBayer2(0.5 * p) + dhBayer2(p);
}

float dhBayer8(vec2 p) {
   return 0.25 * dhBayer4(0.5 * p) + dhBayer2(p);
}

bool isDhLodSurface(float mcDepth, float dhDepth) {
   return mcDepth >= 1.0 && dhDepth < 1.0;
}

vec3 dhNdcToView(vec3 ndc) {
   return nvec3(dhProjectionInverse * vec4(ndc, 1.0));
}

vec3 dhScreenToView(vec2 uv, float depth) {
   return dhNdcToView(screen2ndc(vec3(uv, depth)));
}

vec3 dhViewToNdc(vec3 view) {
   return nvec3(dhProjection * vec4(view, 1.0));
}

vec3 dhViewToScreen(vec3 view) {
   return ndc2screen(dhViewToNdc(view));
}

float dhLinearDepth(float depth) {
   float z = depth * 2.0 - 1.0;
   return (2.0 * dhNearPlane * dhFarPlane)
        / (dhFarPlane + dhNearPlane - z * (dhFarPlane - dhNearPlane));
}

float mcLinearDepth(float depth) {
   float z = depth * 2.0 - 1.0;
   return (2.0 * near * far) / (far + near - z * (far - near));
}

#include "/common/dh_fade.glsl"

vec3 applyDhTerrainNoise(vec3 albedo, vec3 worldPos, vec3 worldNormal) {
   #ifndef DH_TERRAIN_NOISE
      return albedo;
   #endif

   vec3 cell = floor(worldPos * 4.0 + 0.01);
   float grain = random(cell) - 0.5;
   float amount = (1.0 - luma(albedo) * luma(albedo)) * 0.12;
   float weight = abs(worldNormal.x) + abs(worldNormal.y) + abs(worldNormal.z);

   return clamp(albedo + grain * amount * max(weight, 0.001), 0.0, 1.0);
}

#endif
