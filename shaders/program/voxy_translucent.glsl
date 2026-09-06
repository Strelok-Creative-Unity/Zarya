#define VOXY_PATCH
#define VOXY_TRANSLUCENT
#define texture2D texture
#define texture2DLod textureLod
#define texture3D texture

#include "/shader.h"
#include "/common/voxyIrisInjected.glsl"

#ifdef LPV_ENABLED
#undef LPV_ENABLED
#endif
#ifdef LPV_ACTIVE
#undef LPV_ACTIVE
#endif

#if HAND_DYNAMIC_LIGHTING == 1
   #define heldBlockLightValue 14
#endif

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outMaterial;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/voxy.glsl"
#include "/common/dh_fade.glsl"
#include "/common/dh_lightmap.glsl"
#include "/common/getFogMix.vsh"
#include "/common/getFogColor.vsh"
#include "/common/getTorchColor.fsh"
#include "/common/getWaterSurface.glsl"
#include "/common/getWaterFog.glsl"

#ifdef OVERWORLD
   #include "/common/getSkyColor.glsl"
#endif

void voxy_emitFragment(VoxyFragmentParameters parameters) {
   vec2 fragUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
   vec3 viewPos = vxScreenToView(fragUV, gl_FragCoord.z);
   vec3 feetPos = vxViewToFeet(viewPos);
   vec3 vanillaView = feet2view(feetPos);

   float mcDepth = texture2D(depthtex0, fragUV).x;
   if (mcDepth < 1.0) {
      float mcLinear = length(screen2view(fragUV, mcDepth));
      if (mcLinear < length(vanillaView)) {
         discard;
      }
   }

   int blockId = int(parameters.customId);
   bool isWater = blockId == 10008 || blockId == 8;
   vec3 worldNormal = vxFaceNormalWorld(parameters.face);

   if (isWater && abs(worldNormal.y) < 0.5) {
      discard;
   }
   if (discardHiddenLod(feetPos)) {
      discard;
   }

   vec2 lightUV = vxRemapLightMap(parameters.lightMap);
   float sunHeight = view2feet(sunPosition).y;

   #ifndef THE_END
      vec4 ambient = getDhAmbientColor(lightUV.t, sunHeight);
   #else
      vec4 ambient = vec4(END_AMBIENT, 1.0);
   #endif

   float fogMixVal = getFogMix(feetPos);
   vec3 gradientFogColor = getFogColor(fogMixVal, feetPos);

   vec4 albedo = parameters.sampledColour * vec4(parameters.tinting.rgb, 1.0);
   float reflectivity = GLASS_REFLECTIVITY;
   vec3 packedNormal = ndc2screen(worldNormal);

   ambient.rgb += getTorchColor(lightUV.s, ambient.rgb, feetPos, worldNormal);

   if (isWater) {
      reflectivity = WATER_REFLECTIVITY;
      bool eyeInWater = isEyeInWater == 1;

      float behindZ = texture2D(vxDepthTexOpaque, fragUV).x;
      float thick = 80.0;
      if (isVxDepthValid(behindZ)) {
         thick = max(length(vxScreenToVanillaView(fragUV, behindZ)) - length(vanillaView), 0.0);
      } else {
         behindZ = texture2D(depthtex1, fragUV).x;
         if (behindZ < 1.0) {
            thick = max(length(screen2view(fragUV, behindZ)) - length(vanillaView), 0.0);
         }
      }

      if (eyeInWater) {
         thick = length(vanillaView);
      }

      vec3 waterWorld = feetPos + cameraPosition;
      vec3 viewDir = normalize(vanillaView);
      vec3 geoN = vec3(0.0, worldNormal.y >= 0.0 ? 1.0 : -1.0, 0.0);

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
            albedo.rgb += getSunMoonGlint(vanillaView, viewN, 0.14, WATER_REFLECTIVITY)
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
      albedo *= ambient;
   }

   if (!isWater && isEyeInWater == 0) {
      albedo.rgb = mix(albedo.rgb, gradientFogColor, fogMixVal);
   }

   outColor = albedo;
   outNormal = vec4(packedNormal, 1.0);
   #ifdef GENERATED_SPECULAR
      float packSmooth = clamp(max(reflectivity, 0.0), 0.0, 0.98);
      if (packSmooth < 0.5 && packSmooth < WATER_REFLECTIVITY - 0.05) {
         packSmooth = 0.0;
      }
      if (isEyeInWater == 1 && packSmooth > WATER_REFLECTIVITY - 0.05) {
         packSmooth = 0.0;
      }
      outMaterial = vec4(packSmooth, 0.0, 0.5, 1.0);
   #else
      float packReflect = reflectivity;
      if (isEyeInWater == 1 && packReflect > WATER_REFLECTIVITY - 0.05) {
         packReflect = 0.0;
      }
      outMaterial = vec4(packReflect, 0.0, 0.5, 1.0);
   #endif
}
