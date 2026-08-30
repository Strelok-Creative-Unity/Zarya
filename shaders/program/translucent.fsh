#include "/shader.h"

uniform float screenBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform sampler2D gtexture;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform float viewWidth;
uniform float viewHeight;
#ifndef FRAME_TIME_COUNTER_UNIFORM
#define FRAME_TIME_COUNTER_UNIFORM
uniform float frameTimeCounter;
#endif
uniform float rainStrength;
#define RAIN_STRENGTH_UNIFORM

varying float fogMix;
varying float reflectivity;
varying float waterTexStrength;
varying vec2 lightUV;
varying vec2 texUV;
varying vec3 feetPos;
varying vec3 gradientFogColor;
varying vec3 normal;
varying vec4 ambient;
varying vec4 color;

#if HAND_DYNAMIC_LIGHTING == 0
   uniform int heldBlockLightValue;
#elif HAND_DYNAMIC_LIGHTING == 1
   #define heldBlockLightValue 14
#endif

#ifdef VOXY
   varying float vanillaMix;
#endif

#ifdef DH_WATER
   varying float dhIsWater;
#endif

#include "/common/math.glsl"
#include "/common/getTorchColor.fsh"
#include "/common/transformations.glsl"
#include "/common/getWaterSurface.glsl"
#include "/common/getWaterFog.glsl"

#ifdef OVERWORLD
   #include "/common/getSkyColor.glsl"
#endif

uniform float near;
uniform float far;

#ifdef DH_WATER
   uniform int isEyeInWater;

   #include "/common/dh.glsl"
#else
   uniform int isEyeInWater;
#endif

void main() {
   #ifndef DH_WATER
      if (fogMix > 0.999) {
         discard;
      }
   #endif

   #ifdef DH_WATER
      float dhWaterFade = 1.0;

      vec2 screenUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
      float mcDepth = texture2D(depthtex0, screenUV).x;
      if (mcDepth < 1.0) {
         float mcLinear = length(screen2view(screenUV, mcDepth));
         float dhLinear = length(feet2view(feetPos));
         if (mcLinear < dhLinear) {
            discard;
         }
      }

      if (dhIsWater > 0.5) {
         dhWaterFade = getWaterLodMix(feetPos);
      } else if (discardHiddenLod(feetPos)) {
         discard;
      }

      vec4 albedo = vec4(1.0);
   #else
      vec4 albedo  = texture2D(gtexture, texUV);
   #endif
   vec4 ambient = ambient;
   vec4 color   = color;

   #ifdef VOXY
      vec4 vanilla = albedo * color * ambient;
   #endif

   
   ambient.rgb += getTorchColor(lightUV.s, ambient.rgb, feetPos, screen2ndc(normal));

   vec3 packedNormal = normal;

   if (reflectivity > WATER_REFLECTIVITY - 0.01) {
      vec2 waterUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);

      vec3 waterView = feet2view(feetPos);
      vec3 waterFeet = feetPos;
      bool eyeInWater = isEyeInWater == 1;

      #ifdef DH_WATER
         float behindZ = texture2D(dhDepthTex1, waterUV).x;
         float thick = 80.0;
         if (behindZ < 1.0) {
            thick = max(length(dhScreenToView(waterUV, behindZ)) - length(waterView), 0.0);
         }
      #else
         float behindZ = texture2D(depthtex1, waterUV).x;
         float thick = 80.0;
         if (behindZ < 1.0) {
            thick = max(length(screen2view(waterUV, behindZ)) - length(waterView), 0.0);
         }
      #endif

      if (eyeInWater) {
         thick = length(waterView);
      }

      vec3 waterWorld = waterFeet + cameraPosition;
      vec3 viewDir = normalize(waterView);
      vec3 geoN = screen2ndc(normal);

      float cau = 0.0;
      vec3 worldN;
      if (eyeInWater) {
         worldN = getWaterUndersideNormal(waterWorld, geoN);
      } else {
         float waveH;
         vec2 waveG;
         float waveLap;
         sampleWaterField(waterWorld, waveH, waveG, waveLap);
         worldN = getWaterRippleNormalFromGrad(waterWorld, geoN, waveG);
         cau = getWaterCausticsFromField(waterWorld, waveLap);
      }
      vec3 viewN = normalize(mat3(gbufferModelView) * worldN);

      vec3 glColorM = getWaterBaseTint();
      albedo.rgb = 0.375 * glColorM * ambient.rgb;

      float waterFog = 1.0 - exp(-max(thick, 0.0) * (eyeInWater ? 0.045 : 0.11));
      float NoV = max(dot(viewN, -viewDir), 0.0);
      float fresnel = clamp(1.0 - NoV, 0.0, 1.0);

      if (eyeInWater) {
         float window = getSnellWindowAmount(NoV);
         float soft = getWaterSoftFilm(waterWorld);
         window = clamp(window * (0.82 + 0.28 * soft) + soft * 0.10, 0.0, 1.0);
         float tir = 1.0 - window;
         float skyLight = float(eyeBrightnessSmooth.y) / 240.0;
         float nearSurface = exp(-thick * 1.6);
         vec3 fogCol = getUnderwaterFogColor(skyLight);

         albedo.rgb = fogCol * (0.42 + 0.40 * ambient.rgb);
         albedo.rgb *= 0.88 + 0.22 * soft;

         #ifdef OVERWORLD
            vec3 refracted = refract(viewDir, viewN, 1.333);
            vec3 aboveCol = fogCol * 0.45;
            if (dot(refracted, refracted) > 1.0e-4) {
               aboveCol = getSkyColor(normalize(refracted));
            }
            albedo.rgb = mix(albedo.rgb, aboveCol * (0.50 + 0.50 * skyLight), window * 0.85);
            albedo.rgb += aboveCol * soft * nearSurface * window * 0.22 * skyLight;
            albedo.rgb += getSunMoonGlint(waterView, viewN, 0.14, WATER_REFLECTIVITY)
                        * (0.10 + 0.35 * tir) * skyLight;
         #endif

         albedo.a = mix(0.72, 0.14, window);
         albedo.a = mix(albedo.a, 0.82, pow(fresnel, 2.2) * tir * 0.85);
         albedo.a = mix(albedo.a, albedo.a * 0.70, nearSurface * window);
         albedo.a = clamp(albedo.a * (0.55 + 0.55 * WATER_A), 0.0, 1.0);
      } else {
         albedo.rgb = applyWaterNoiseColor(albedo.rgb, waterWorld, cau);
         float shallow = exp(-max(thick, 0.0) * 0.08);
         albedo.rgb *= 1.0 + cau * shallow * 0.55;
         albedo.rgb += getWaterBaseTint() * cau * shallow * 0.18;

         albedo.a = getWaterSheetAlpha(waterFog, fresnel);
         albedo.rgb *= 0.55 + 0.45 * WATER_BRIGHTNESS;
      }

      albedo.a = clamp(albedo.a, 0.0, 1.0);
      packedNormal = ndc2screen(worldN);
   } else {
      albedo *= color * ambient;
   }

   #ifdef VOXY
      float reflectivity = mix(reflectivity, 0.0, vanillaMix);

      albedo = mix(albedo, vanilla, vanillaMix);
   #endif

   if (reflectivity <= WATER_REFLECTIVITY - 0.01 && isEyeInWater == 0) {
      albedo.rgb = mix(albedo.rgb, gradientFogColor, fogMix);
   }

   #ifdef DH_WATER
      albedo.a *= dhWaterFade;
   #endif

   /* DRAWBUFFERS:067 */
   gl_FragData[0] = albedo;
   gl_FragData[1] = vec4(packedNormal, 1.0);
   #ifdef GENERATED_SPECULAR
      float packSmooth = clamp(max(reflectivity, 0.0), 0.0, 0.98);
      if (packSmooth < 0.5 && packSmooth < WATER_REFLECTIVITY - 0.05) {
         packSmooth = 0.0;
      }
      if (isEyeInWater == 1 && packSmooth > WATER_REFLECTIVITY - 0.05) {
         packSmooth = 0.0;
      }
      gl_FragData[2] = vec4(packSmooth, 0.0, 0.5, 1.0);
   #else
      float packReflect = reflectivity;
      if (isEyeInWater == 1 && packReflect > WATER_REFLECTIVITY - 0.05) {
         packReflect = 0.0;
      }
      gl_FragData[2] = vec4(packReflect, 0.0, 0.5, 1.0);
   #endif
}
