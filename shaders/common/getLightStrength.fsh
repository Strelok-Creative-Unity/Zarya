#include "/common/getShadowDistortion.glsl"

#if SHADOW_FILTER <= 0
   #define SHADOW_SAMPLES 8
#elif SHADOW_FILTER == 1
   #define SHADOW_SAMPLES 8
#elif SHADOW_FILTER == 2
   #define SHADOW_SAMPLES 10
#else
   #define SHADOW_SAMPLES 12
#endif

#if defined(CLOUD_SHADOWS)
   #include "/common/shaderCloudsCommon.glsl"
#endif

float texture2DShadow(vec3 shadowPos) {
   float shadow = texture2D(shadowtex1, shadowPos.xy).r;

   return clamp((shadow - shadowPos.z) * 65536.0, 0.0, 1.0);
}

float shadowBayer4(vec2 p) {
   p = floor(mod(p, 4.0));
   float x = mod(p.x, 2.0);
   float y = mod(p.y, 2.0);
   float v0 = mod(1.5 * x + y * 2.0, 4.0);
   float v1 = mod(1.5 * floor(p.x * 0.5) + floor(p.y * 0.5) * 2.0, 4.0);
   return (v0 + 4.0 * v1) / 16.0;
}

float filterShadow(vec3 shadowPos, float radiusTexels) {
   float texel = 1.0 / float(shadowMapResolution);
   float radius = radiusTexels * texel;
   float rot = shadowBayer4(gl_FragCoord.xy) * 6.2831853;
   float ca = cos(rot);
   float sa = sin(rot);
   float invN = 1.0 / float(SHADOW_SAMPLES);
   float lit = 0.0;

   for (int i = 0; i < SHADOW_SAMPLES; i++) {
      float fi = float(i) + 0.5;
      float r = sqrt(fi * invN) * radius;
      float a = fi * 2.39996323;
      vec2 dir = vec2(cos(a), sin(a));
      vec2 o = vec2(ca * dir.x - sa * dir.y, sa * dir.x + ca * dir.y) * r;
      lit += texture2DShadow(vec3(shadowPos.xy + o, shadowPos.z));
   }

   return lit * invN;
}

float getLightStrength(float diffuse, float skyLight, vec3 feetPos, vec3 worldNormal) {
   diffuse *= rescale(skyLight, 0.3137, 0.6235);

   #ifdef GBUFFERS_HAND
      return 0.5 * diffuse;
   #endif

   vec3 sampleFeet = feetPos;
   float dist = length(sampleFeet);
   float nDotUp = abs(worldNormal.y);
   sampleFeet += worldNormal * (0.08 + dist * 0.00115 + (1.0 - nDotUp) * 0.045 + nDotUp * 0.05);

   #if SHADOW_PIXEL > 0
      vec3 pos = world2feet(bandify(feet2world(sampleFeet), SHADOW_PIXEL));
   #else
      vec3 pos = sampleFeet;
   #endif

   float posDistance = squaredLength(pos);
   vec4 shadowView   = shadowModelView * vec4(pos, 1.0);
   vec4 shadowClip   = shadowProjection * shadowView;

   shadowClip.xyz = getShadowDistortion(shadowClip.xyz);

   vec3 shadowUV = clip2screen(shadowClip);
   shadowUV.z += (0.10 + 0.22 * nDotUp) / float(shadowMapResolution);

   if (diffuse > 0.0 &&
       shadowUV.z < 1.0 &&
       shadowUV.s > 0.0 && shadowUV.s < 1.0 &&
       shadowUV.t > 0.0 && shadowUV.t < 1.0)
   {
      float distT = posDistance * INV_SHADOW_MAX_DIST_SQUARED;
      float distFade = 1.0 - smoothe(clamp((distT - 0.55) / 0.45, 0.0, 1.0));
      float border = min(min(shadowUV.s, 1.0 - shadowUV.s), min(shadowUV.t, 1.0 - shadowUV.t));
      float edgeFade = smoothe(clamp(border / 0.08, 0.0, 1.0));
      float shadowFade = distFade * edgeFade;

      float sharpness = clamp(float(SHADOW_SHARPNESS) / 10.0, 0.0, 1.0);
      #if SHADOW_FILTER <= 0
         float radius = mix(3.4, 1.85, sharpness);
      #else
         float radius = mix(6.5, 2.4, sharpness) * float(SHADOW_FILTER);
      #endif
      float lit = filterShadow(shadowUV, radius);

      diffuse *= (1.0 - shadowFade * (1.0 - lit));
   }

   #if defined(CLOUD_SHADOWS)
      if (skyLight > 0.04) {
         vec3 worldLight = normalize(view2eye(shadowLightPosition));
         float cloudSh = rfCloudShadow(feet2world(sampleFeet), worldLight);
         float skyF = clamp(skyLight * 1.45, 0.0, 1.0);
         diffuse *= mix(1.0, cloudSh, skyF);
      }
   #endif

   return diffuse;
}
