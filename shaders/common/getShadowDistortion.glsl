const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

#ifndef SHADOW_WARP
   #define SHADOW_WARP 0.82
#endif
#ifndef SHADOW_DEPTH_SCALE
   #define SHADOW_DEPTH_SCALE 0.37
#endif

vec3 getShadowDistortion(vec3 shadowClipPos) {
   vec2 xy = shadowClipPos.xy;
   float r = length(xy);
   float distort = r * SHADOW_WARP + (1.0 - SHADOW_WARP);
   shadowClipPos.xy = xy / max(distort, 1.0e-4);
   shadowClipPos.z *= mix(SHADOW_DEPTH_SCALE, SHADOW_DEPTH_SCALE * 0.84, clamp(r, 0.0, 1.0));
   return shadowClipPos;
}
