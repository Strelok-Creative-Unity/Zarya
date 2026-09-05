#define VOXY_PATCH
#define VOXY_OPAQUE
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
#include "/common/getLightColor.vsh"

#ifdef ENABLE_SHADOWS
   #include "/common/getLightStrength.fsh"
#endif

void voxy_emitFragment(VoxyFragmentParameters parameters) {
   vec2 fragUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
   vec3 viewPos = vxScreenToView(fragUV, gl_FragCoord.z);
   vec3 feetPos = vxViewToFeet(viewPos);

   if (discardHiddenLod(feetPos)) {
      discard;
   }

   int blockId = int(parameters.customId);
   vec2 lightUV = vxRemapLightMap(parameters.lightMap);
   vec3 worldNormal = vxFaceNormalWorld(parameters.face);

   float isLeaves = float(blockId == 10301);
   float isThinPlant = float(
      blockId == 10031 || blockId == 10059 || blockId == 10302 || blockId == 10077
      || (blockId >= 10060 && blockId <= 10075 && blockId != 10068 && blockId != 10072)
   );
   float lightSourceLevel = float(
      blockId == 10068 || blockId == 10072 || blockId == 10076
      || blockId == 10496 || blockId == 10528 || blockId == 10604
      || blockId == 10652 || blockId == 10656 || blockId == 10984
   );

   vec4 color = parameters.tinting;
   color.a = 1.0;
   color.rgb = applyLodTerrainNoise(color.rgb, feetPos + cameraPosition, worldNormal);

   if (blockId == 10068) {
      color.rgb = mix(vec3(0.8, 0.5, 0.3), vec3(1.0), rescale(color.rgb, vec3(0.54), vec3(0.9)));
   }

   #ifndef FLAT_LIGHTING
      if (isThinPlant < 0.5) {
         color.rgb *= clamp(
            worldNormal.x * worldNormal.x * 0.6
            + worldNormal.y * worldNormal.y * 0.25 * (3.0 + worldNormal.y)
            + worldNormal.z * worldNormal.z * 0.8,
            step(0.933, lightSourceLevel),
            1.0
         );
      }
   #endif

   float nY = clamp(worldNormal.y * 0.5 + 0.5, 0.0, 1.0);
   float ambientOcclusion = isLeaves > 0.5
      ? mix(0.52, 1.0, nY * nY)
      : (isThinPlant > 0.5 ? 1.0 : mix(0.86, 1.0, nY));

   float sunHeight = view2feet(sunPosition).y;
   #ifndef THE_END
      vec4 ambient = getDhAmbientColor(lightUV.t, sunHeight);
   #else
      vec4 ambient = vec4(END_AMBIENT, 1.0);
   #endif

   vec4 albedo = parameters.sampledColour * color;
   float albedoLuma = luma(albedo.rgb);
   float fogMixVal = getFogMix(feetPos);
   fogMixVal = mix(fogMixVal, fogMixVal * fogMixVal, lightSourceLevel);
   if (fogMixVal > 0.999) {
      discard;
   }
   vec3 gradientFogColor = getFogColor(fogMixVal, feetPos);

   #if defined ENABLE_SHADOWS && !defined THE_END
      float skyLight = clamp(lightUV.t, 0.0, 1.0);
      vec3 lightDirWorld = normalize(view2eye(shadowLightPosition));
      float NoL = clamp(2.5 * dot(worldNormal, lightDirWorld), -0.3333, 1.0);
      float leafWrap = clamp(dot(worldNormal, lightDirWorld) * 0.5 + 0.5, 0.0, 1.0);
      float leafLit = mix(NoL, leafWrap * leafWrap, 0.72);
      float diffuse = (isEyeInWater == 0 ? 1.0 : 0.5)
                    * (1.0 - fogMixVal)
                    * (1.0 - rainStrength)
                    * (isThinPlant > 0.5 ? 0.82 : (isLeaves > 0.5 ? leafLit : NoL))
                    * clamp(0.1 * abs(sunHeight) - 0.4453, 0.0, 1.0);

      vec3 lightColor = getLightColor(sunHeight, skyLight);
      float lightStrength = getLightStrength(diffuse, skyLight, feetPos, worldNormal);

      float beyondShadow = 0.0;
      if (isLeaves > 0.5) {
         beyondShadow = smoothe(clamp(length(feetPos) / max(shadowDistance, 16.0) - 0.72, 0.0, 1.0));
      }

      #if defined FOLIAGE_SSS || defined DH_FOLIAGE_SSS
         float wrapT = 0.0;
         if (isLeaves > 0.5) {
            wrapT = pow(clamp(dot(normalize(worldNormal), lightDirWorld) * 0.62 + 0.38, 0.0, 1.0), 1.35);
            float shadow = diffuse > 1.0e-4
               ? clamp(lightStrength / max(diffuse, 1.0e-4), 0.0, 1.0)
               : 1.0;
            float s = FOLIAGE_SSS_STRENGTH * 2.5;
            float mixAmt = clamp(s * 0.48, 0.0, 0.95);
            float sss = 0.18 + 0.64 * wrapT * wrapT;
            lightStrength = mix(max(diffuse, 0.0), sss, mixAmt) * mix(0.34, 1.0, shadow);
         }
      #endif

      if (isLeaves > 0.5) {
         float canopy = 0.46 + 0.54 * leafWrap * nY;
         lightStrength *= mix(1.0, canopy, beyondShadow);
      }

      float lightBrightness = max(0.0, LIGHT_BRIGHTNESS - 0.5 * pow3(albedoLuma));
      lightStrength = max(lightStrength, 0.75 * lightSourceLevel);

      ambient.rgb *= mix(SHADOW_COLOR, vec3(1.0), lightStrength);
      ambient.rgb *= 0.70 + (lightBrightness * lightStrength) * lightColor;

      #if defined FOLIAGE_SSS || defined DH_FOLIAGE_SSS
         if (isLeaves > 0.5) {
            float s = FOLIAGE_SSS_STRENGTH * 2.5;
            ambient.rgb += lightColor * wrapT * (0.12 * s) * vec3(0.55, 0.85, 0.35);
            float towardSun = clamp(dot(normalize(feetPos), lightDirWorld), 0.0, 1.0);
            ambient.rgb += lightColor * pow(towardSun, 2.2) * (0.18 * s)
                         * vec3(0.50, 0.92, 0.30) * (1.0 - beyondShadow);
         }
      #endif
   #endif

   ambient.rgb += getTorchColor(lightUV.s, ambient.rgb, feetPos, worldNormal);

   #ifdef THE_NETHER
      float underGlow = pow(clamp(0.52 - worldNormal.y * 0.52, 0.0, 1.0), 1.12);
      ambient.rgb += vec3(0.80, 0.30, 0.08) * underGlow * 0.035 * NETHER_AMBIENT;
   #endif

   albedo.rgb *= ambientOcclusion;
   albedo *= ambient;

   #ifdef OVERWORLD
      albedo.rgb = applyTerrainRainGrade(albedo.rgb, rainStrength, gradientFogColor, 0.58);
      albedo.rgb = applyTerrainAtmosphereGrade(albedo.rgb, feetPos, gradientFogColor, 0.50, vxFarPlane());
   #endif

   #if defined THE_NETHER && defined NETHER_COLOR_GRADING
      float netherL = luma(albedo.rgb);
      albedo.rgb *= mix(1.02, 0.98, smoothstep(0.28, 0.88, netherL));
   #endif

   albedo.rgb = mix(albedo.rgb, gradientFogColor, fogMixVal);

   outColor = albedo;
   outNormal = vec4(ndc2screen(worldNormal), 1.0);
   outMaterial = vec4(0.0, isThinPlant * 0.20, 0.5, 1.0);
}
