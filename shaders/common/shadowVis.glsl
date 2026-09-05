#ifndef SHADOW_VIS_GLSL
#define SHADOW_VIS_GLSL

#ifndef SHADOWTEX1_UNIFORM
#define SHADOWTEX1_UNIFORM
uniform sampler2D shadowtex1;
#endif
#ifdef COLORED_SHADOWS
#ifndef SHADOWTEX0_UNIFORM
#define SHADOWTEX0_UNIFORM
uniform sampler2D shadowtex0;
#endif
#ifndef SHADOWCOLOR0_UNIFORM
#define SHADOWCOLOR0_UNIFORM
uniform sampler2D shadowcolor0;
#endif
#endif

float shadowDepthLit(sampler2D depthMap, vec3 shadowUV) {
   float shadow = texture2D(depthMap, shadowUV.xy).r;
   return clamp((shadow - shadowUV.z) * 65536.0, 0.0, 1.0);
}

float shadowCompare(vec3 shadowUV) {
   float soft = 0.0012 + 1.5 / float(shadowMapResolution);
   float shadow = texture2D(shadowtex1, shadowUV.xy).r;
   return smoothstep(shadowUV.z - soft, shadowUV.z + soft * 0.35, shadow);
}

vec3 shadowSampleColored(vec3 shadowUV) {
   float opaque = shadowDepthLit(shadowtex1, shadowUV);
#ifdef COLORED_SHADOWS
   float allCasters = shadowDepthLit(shadowtex0, shadowUV);
   vec3 glass = vec3(1.0);
   if (allCasters < 0.999 && opaque > 0.5) {
      glass = texture2D(shadowcolor0, shadowUV.xy).rgb;
      float lum = dot(glass, vec3(0.22, 0.54, 0.24));
      glass = clamp(mix(vec3(lum), glass, 1.75), 0.0, 1.0);
   }
   return mix(vec3(opaque), glass, (1.0 - allCasters) * opaque);
#else
   return vec3(opaque);
#endif
}

vec3 feetToShadowUV(vec3 feetPos) {
   vec4 shadowView = shadowModelView * vec4(feetPos, 1.0);
   vec4 shadowClip = shadowProjection * shadowView;
   shadowClip.xyz = getShadowDistortion(shadowClip.xyz);
   vec3 shadowUV = clip2screen(shadowClip);
   shadowUV.z += 0.068 / float(shadowMapResolution);
   return shadowUV;
}

vec3 shadowVisibility(vec3 feetPos) {
   vec3 shadowUV = feetToShadowUV(feetPos);
   if (shadowUV.s <= 0.0 || shadowUV.s >= 1.0 ||
       shadowUV.t <= 0.0 || shadowUV.t >= 1.0) {
      return vec3(1.0);
   }
   if (shadowUV.z <= 0.0 || shadowUV.z >= 1.0) {
      return vec3(0.0);
   }

   float distT = squaredLength(feetPos) * INV_SHADOW_MAX_DIST_SQUARED;
   float distFade = 1.0 - smoothe(clamp((distT - 0.55) / 0.45, 0.0, 1.0));
   float border = min(min(shadowUV.s, 1.0 - shadowUV.s), min(shadowUV.t, 1.0 - shadowUV.t));
   float edgeFade = smoothe(clamp(border / 0.08, 0.0, 1.0));
   return mix(vec3(1.0), shadowSampleColored(shadowUV), distFade * edgeFade);
}

#endif
