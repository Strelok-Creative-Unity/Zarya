#ifndef SHADOW_VIS_GLSL
#define SHADOW_VIS_GLSL

float shadowCompare(vec3 shadowUV) {
   float soft = 0.0012 + 1.5 / float(shadowMapResolution);
   float shadow = texture2D(shadowtex1, shadowUV.xy).r;
   return smoothstep(shadowUV.z - soft, shadowUV.z + soft * 0.35, shadow);
}

vec3 feetToShadowUV(vec3 feetPos) {
   vec4 shadowView = shadowModelView * vec4(feetPos, 1.0);
   vec4 shadowClip = shadowProjection * shadowView;
   shadowClip.xyz = getShadowDistortion(shadowClip.xyz);
   vec3 shadowUV = clip2screen(shadowClip);
   shadowUV.z += 0.068 / float(shadowMapResolution);
   return shadowUV;
}

float shadowVisibility(vec3 feetPos) {
   vec3 shadowUV = feetToShadowUV(feetPos);
   if (shadowUV.z >= 1.0 ||
       shadowUV.s <= 0.0 || shadowUV.s >= 1.0 ||
       shadowUV.t <= 0.0 || shadowUV.t >= 1.0) {
      return 1.0;
   }

   float distT = squaredLength(feetPos) * INV_SHADOW_MAX_DIST_SQUARED;
   float distFade = 1.0 - smoothe(clamp((distT - 0.55) / 0.45, 0.0, 1.0));
   float border = min(min(shadowUV.s, 1.0 - shadowUV.s), min(shadowUV.t, 1.0 - shadowUV.t));
   float edgeFade = smoothe(clamp(border / 0.08, 0.0, 1.0));
   return mix(1.0, shadowCompare(shadowUV), distFade * edgeFade);
}

#endif
