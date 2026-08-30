#include "/shader.h"

uniform float screenBrightness;
uniform int entityId;
#ifndef EYE_BRIGHTNESS_SMOOTH_UNIFORM
#define EYE_BRIGHTNESS_SMOOTH_UNIFORM
uniform ivec2 eyeBrightnessSmooth;
#endif
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform vec4 entityColor;

#if defined GBUFFERS_TEXTURED || defined GENERATED_NORMALS
   uniform ivec2 atlasSize;
#endif

flat varying float lightSourceLevel;
varying float fogMix;
varying float sunHeight;
varying vec2 lightUV;
varying vec2 texUV;
varying vec3 feetPos;
varying vec3 gradientFogColor;

#ifdef DH_TERRAIN
   varying vec3 dhWorldNormal;
   flat varying float dhIsLeaves;
#endif

#ifdef FOLIAGE_SSS
   flat varying float isFoliage;
#endif

#if defined GBUFFERS_TERRAIN || defined GBUFFERS_TEXTURED
   varying vec4 color;
#else
   flat varying vec4 color;
#endif

#ifdef THE_END
   varying vec3 endTint;
#endif

#if BLOCK_REFLECTIONS > 0 || defined GENERATED_SPECULAR || defined GENERATED_NORMALS
   flat varying vec3 blockReflectivity;
   varying vec3 normal;
#endif

#if defined GENERATED_SPECULAR || defined GENERATED_EMISSION || defined GENERATED_NORMALS
   flat varying float materialId;
   flat varying float blockFlags;
#endif

#ifdef FLOWER_FESTIVAL
   flat varying float isFlower;
#endif

#ifdef GENERATED_NORMALS
   #if (defined GBUFFERS_TERRAIN || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND) && !defined DH_TERRAIN
      varying vec3 tangent;
      varying vec3 binormal;
      flat varying vec2 absMidCoordPos;
      varying vec2 signMidCoordPos;
   #endif
#endif

#ifdef GLOWING_ORES
   flat varying float isOre;
#endif

#if HAND_DYNAMIC_LIGHTING == 0
   uniform int heldBlockLightValue;
#elif HAND_DYNAMIC_LIGHTING == 1
   #define heldBlockLightValue 14
#endif

#include "/common/math.glsl"
#include "/common/getTorchColor.fsh"
#include "/common/getAmbientColor.glsl"

#if defined GENERATED_SPECULAR || defined GENERATED_EMISSION
   #include "/common/ipbr.glsl"
#endif

#ifdef GENERATED_SPECULAR
   #ifdef ENABLE_SHADOWS
      #include "/common/specularHighlight.glsl"
   #endif
#endif

#if defined DH_TERRAIN || defined ENABLE_SHADOWS || BLOCK_REFLECTIONS > 0 || defined GENERATED_SPECULAR || defined GENERATED_NORMALS
   #ifndef TRANSFORMATIONS_INCLUDED
      #include "/common/transformations.glsl"
      #define TRANSFORMATIONS_INCLUDED
   #endif
#endif

#ifdef GENERATED_NORMALS
   #if (defined GBUFFERS_TERRAIN || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND) && !defined DH_TERRAIN
      #include "/common/generatedNormals.glsl"
   #endif
#endif

#ifdef DH_TERRAIN
   uniform float near;
   uniform float far;
   uniform float viewWidth;
   uniform float viewHeight;

   #ifndef TRANSFORMATIONS_INCLUDED
      #include "/common/transformations.glsl"
      #define TRANSFORMATIONS_INCLUDED
   #endif
   #include "/common/dh.glsl"
#endif

#if defined DH_TERRAIN || (defined OVERWORLD && defined GBUFFERS_TERRAIN)
   #include "/common/dh_lightmap.glsl"
#endif

#if defined OVERWORLD && (defined GBUFFERS_TERRAIN || defined DH_TERRAIN)
   #ifndef RAIN_STRENGTH_UNIFORM
   #define RAIN_STRENGTH_UNIFORM
   uniform float rainStrength;
   #endif
   #ifndef DH_TERRAIN
      uniform float far;
   #endif
#endif

#ifdef ENABLE_SHADOWS
   uniform mat4 shadowModelView;
   uniform mat4 shadowProjection;
   uniform sampler2D shadowtex1;
   uniform vec3 shadowLightPosition;

   varying vec3 lightColor;
   varying float diffuse;
   varying vec3 shadowNormal;

   #ifndef DH_TERRAIN
      uniform float viewWidth;
      uniform float viewHeight;
   #endif
   #ifndef TRANSFORMATIONS_INCLUDED
      #include "/common/transformations.glsl"
      #define TRANSFORMATIONS_INCLUDED
   #endif
   #include "/common/getLightStrength.fsh"
#endif

void main() {
   if (fogMix > 0.999) {
      discard;
   }

   vec3 litFeet = feetPos;

   #ifdef DH_TERRAIN
      vec2 fragUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
      litFeet = view2feet(dhScreenToView(fragUV, gl_FragCoord.z));

      if (discardHiddenLod(litFeet)) {
         discard;
      }

      vec4 albedo = vec4(1.0);
   #elif defined GBUFFERS_TEXTURED
      vec2 uv = texUV;
      if (atlasSize.x > 0) {
         uv = (floor(texUV * vec2(atlasSize)) + 0.5) / vec2(atlasSize);
      }
      vec4 albedo = texture2D(gtexture, uv);
      if (albedo.a < 0.1) {
         discard;
      }
   #else
      vec4 albedo = texture2D(gtexture, texUV);
   #endif
   vec4 color  = color;

   #ifdef DH_TERRAIN
      color.rgb = applyDhTerrainNoise(color.rgb, litFeet + cameraPosition, dhWorldNormal);
      float nY = clamp(dhWorldNormal.y * 0.5 + 0.5, 0.0, 1.0);
      float ambientOcclusion = mix(0.86, 1.0, nY);
      color.a = 1.0;
   #elif defined GBUFFERS_TERRAIN
      float ambientOcclusion = color.a;
      color.a = 1.0;
   #else
      float ambientOcclusion = 1.0;
   #endif

   #ifdef MOD_COLORWHEEL
      vec2 lightUV;
      vec4 entityColor;

      clrwl_computeFragment(albedo, albedo, lightUV, ambientOcclusion, entityColor);
   #endif

   #if defined DH_TERRAIN && !defined THE_END
      vec4 ambient = getDhAmbientColor(lightUV.t, sunHeight);
   #else
      vec4 ambient = getAmbientColor(lightUV.t, sunHeight);
   #endif

   #ifdef THE_END
      ambient.rgb *= endTint;
   #endif

   #ifdef GLOWING_ORES
      ambient.rgb = mix(
         ambient.rgb,
         vec3(1.0, 0.9, 0.9),
         isOre * 0.3333*squaredLength(rescale(albedo.rgb, vec3(0.59), vec3(1.0)))
      );
   #endif

   albedo *= color;

   #ifndef DH_TERRAIN
      albedo.a = entityId == 11000.0 ? 0.15 : albedo.a;
      #ifndef GBUFFERS_TEXTURED
         albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
      #endif
   #endif

   float albedoLuma = luma(albedo.rgb);

   #ifdef FLOWER_FESTIVAL
      float flowerFalloff = clamp((length(litFeet) - EVENT_FLOWER_FADE_START) / max(EVENT_FLOWER_FADE_END - EVENT_FLOWER_FADE_START, 0.001), 0.0, 1.0);
      float flowerFade = 1.0 - flowerFalloff * flowerFalloff * (3.0 - 2.0 * flowerFalloff);
      float flowerGlow = isFlower * flowerFade;
   #else
      float flowerGlow = 0.0;
   #endif

   float emissionLevel = max(lightSourceLevel, flowerGlow * EVENT_FLOWER_BRIGHTNESS);

   #if defined GENERATED_SPECULAR || defined GENERATED_EMISSION
      vec4 ipbr = generateIPBR(materialId, blockFlags, albedo.rgb);
      #ifdef GENERATED_EMISSION
         emissionLevel = max(emissionLevel, ipbr.z);
      #endif
   #else
      vec4 ipbr = vec4(0.0, 0.0, 0.0, 1.0);
   #endif

   vec3 litNormal = vec3(0.0, 1.0, 0.0);
   vec3 viewLitNormal = vec3(0.0, 0.0, 1.0);
   #ifdef ENABLE_SHADOWS
      litNormal = shadowNormal;
      viewLitNormal = normalize(mat3(gbufferModelView) * screen2ndc(normal));
   #endif

   vec3 outNormalModel = vec3(0.0, 1.0, 0.0);
   #if BLOCK_REFLECTIONS > 0 || defined GENERATED_SPECULAR || defined GENERATED_NORMALS
      outNormalModel = screen2ndc(normal);
      viewLitNormal = normalize(mat3(gbufferModelView) * outNormalModel);
      litNormal = view2eye(viewLitNormal);
   #endif

   float bumpShade = 1.0;
   float ambBump = 1.0;

   #ifdef GENERATED_NORMALS
      #if (defined GBUFFERS_TERRAIN || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND) && !defined DH_TERRAIN
         vec3 viewN = viewLitNormal;
         vec3 flatViewN = viewN;
         applyGeneratedNormals(viewN, albedo.rgb, tangent, binormal,
                               texUV, absMidCoordPos, signMidCoordPos);
         viewLitNormal = viewN;
         litNormal = view2eye(viewN);

         vec3 toCam = normalize(-feet2view(litFeet));
         vec3 viewUp = normalize(mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0));
         float flatCam = max(dot(flatViewN, toCam), 0.12);
         float bumpCam = max(dot(viewN, toCam), 0.0);
         float flatUp = max(dot(flatViewN, viewUp) * 0.5 + 0.5, 0.08);
         float bumpUp = clamp(dot(viewN, viewUp) * 0.5 + 0.5, 0.0, 1.0);
         float cave = 1.0 - clamp((lightUV.t - 0.12) / 0.78, 0.0, 1.0);
         float camW = mix(0.38, 0.72, cave);
         ambBump = mix(1.0, clamp((1.0 - camW) * (bumpUp / flatUp) + camW * (bumpCam / flatCam), 0.58, 1.42), 0.9);

         #ifdef ENABLE_SHADOWS
            vec3 L = normalize(shadowLightPosition);
            float flatNoL = max(dot(flatViewN, L), 0.001);
            float bumpNoL = max(dot(viewN, L), 0.0);
            bumpShade = mix(1.0, clamp(bumpNoL / flatNoL, 0.55, 1.45), 0.85);
         #endif
      #endif
   #endif

   #ifdef ENABLE_SHADOWS
      vec3 lightEye = vec3(0.0);
      float wrapT = 0.0;
      float foliageAmt = 0.0;
      #ifdef DH_TERRAIN
         foliageAmt = dhIsLeaves;
      #elif defined FOLIAGE_SSS
         foliageAmt = isFoliage;
      #endif

      #ifdef DH_TERRAIN
         float lightStrength = getLightStrength(diffuse, lightUV.t, litFeet, dhWorldNormal);
      #else
         float lightStrength = getLightStrength(diffuse, lightUV.t, litFeet, litNormal) * bumpShade;
      #endif

      #if defined FOLIAGE_SSS || defined DH_FOLIAGE_SSS
         if (foliageAmt > 0.5) {
            vec3 foliageN = litNormal;
            #ifdef DH_TERRAIN
               foliageN = dhWorldNormal;
            #endif
            lightEye = normalize(view2eye(shadowLightPosition));
            wrapT = pow(clamp(dot(normalize(foliageN), lightEye) * 0.62 + 0.38, 0.0, 1.0), 1.35);
            float shadow = diffuse > 1.0e-4
               ? clamp(lightStrength / max(diffuse, 1.0e-4), 0.0, 1.0)
               : 1.0;
            float s = FOLIAGE_SSS_STRENGTH * 2.5;
            float mixAmt = clamp(s * 0.48, 0.0, 0.95);
            float sss = 0.18 + 0.64 * wrapT * wrapT;
            lightStrength = mix(max(diffuse, 0.0), sss, mixAmt) * mix(0.34, 1.0, shadow);
         }
      #endif
      float lightBrightness = max(0.0, LIGHT_BRIGHTNESS - 0.5*pow3(albedoLuma));

      lightStrength = max(lightStrength, 0.75 * emissionLevel);

      ambient.rgb *= mix(SHADOW_COLOR, vec3(1.0), lightStrength);
      ambient.rgb *= 0.70 + (lightBrightness * lightStrength) * lightColor;

      #if defined FOLIAGE_SSS || defined DH_FOLIAGE_SSS
         if (foliageAmt > 0.5) {
            float s = FOLIAGE_SSS_STRENGTH * 2.5;
            ambient.rgb += lightColor * wrapT * (0.16 * s) * vec3(0.55, 0.85, 0.35);

            float towardSun = clamp(dot(normalize(litFeet), lightEye), 0.0, 1.0);
            ambient.rgb += lightColor * pow(towardSun, 2.2) * (0.28 * s) * vec3(0.50, 0.92, 0.30);
         }
      #endif
   #else
      float lightStrength = emissionLevel;
   #endif

   #ifdef THE_NETHER
      vec3 netherN = litNormal;
      #ifdef DH_TERRAIN
         netherN = dhWorldNormal;
      #endif
      float underGlow = pow(clamp(0.52 - netherN.y * 0.52, 0.0, 1.0), 1.12);
      ambient.rgb += vec3(0.80, 0.30, 0.08) * underGlow * 0.035 * NETHER_AMBIENT;
   #endif

   

   
   vec3 lpvNormal = outNormalModel;
   #ifdef DH_TERRAIN
      lpvNormal = dhWorldNormal;
   #elif !(BLOCK_REFLECTIONS > 0 || defined GENERATED_SPECULAR || defined GENERATED_NORMALS) && defined ENABLE_SHADOWS
      lpvNormal = shadowNormal;
   #endif

   ambient.rgb += getTorchColor(lightUV.s, ambient.rgb, litFeet, lpvNormal);
   ambient.rgb *= ambBump;

   #ifdef GENERATED_EMISSION
      ambient.rgb += albedo.rgb * ipbr.z * EMISSION_STRENGTH;
   #endif

   #ifdef FLOWER_FESTIVAL
      ambient.rgb += albedo.rgb * flowerGlow * EVENT_FLOWER_BRIGHTNESS;
   #endif

   vec3 baseAlbedo = albedo.rgb;

   albedo.rgb *= ambientOcclusion;
   albedo *= ambient;

   #if defined OVERWORLD && (defined GBUFFERS_TERRAIN || defined DH_TERRAIN)
      albedo.rgb = applyTerrainRainGrade(albedo.rgb, rainStrength, gradientFogColor, 0.58);
      albedo.rgb = applyTerrainAtmosphereGrade(albedo.rgb, litFeet, gradientFogColor, 0.50, far);
   #endif

   #if defined GENERATED_SPECULAR && defined ENABLE_SHADOWS && !defined DH_TERRAIN
      if (ipbr.x > 0.04) {
         vec3 viewPos = feet2view(litFeet);
         float specLight = max(lightStrength, ipbr.y * 0.4);
         albedo.rgb += ipbrSpecularHighlight(
            viewLitNormal, viewPos, shadowLightPosition,
            ipbr.x, ipbr.y, baseAlbedo,
            specLight, lightColor
         ) * mix(1.0, 2.0, ipbr.y);
      }
   #endif

   #if defined THE_NETHER && defined NETHER_COLOR_GRADING
      float netherL = luma(albedo.rgb);
      albedo.rgb *= mix(1.02, 0.98, smoothstep(0.28, 0.88, netherL));
   #endif

   albedo.rgb = mix(albedo.rgb, gradientFogColor, fogMix);

   /* DRAWBUFFERS:067 */
   gl_FragData[0] = albedo;

   #if BLOCK_REFLECTIONS > 0 || defined GENERATED_SPECULAR
      #ifdef GENERATED_SPECULAR
         float smoothness = 0.0;
         float metalness = 0.0;

         #ifdef DH_TERRAIN
            smoothness = 0.0;
            metalness = 0.0;
         #else
            smoothness = ipbr.x;
            metalness = ipbr.y;
         #endif

         float reflScale = max(float(BLOCK_REFLECTIONS) * 0.1, 0.01);
         if (metalness > 0.45) {
            smoothness = max(smoothness * max(reflScale, 0.7), 0.78);
         } else {
            smoothness *= reflScale;
            if (smoothness < 0.50) {
               smoothness = 0.0;
               metalness = 0.0;
            }
         }
      #else
         float smoothness = max(0.0, (albedoLuma - blockReflectivity.y) * blockReflectivity.x * 0.2 * float(BLOCK_REFLECTIONS));
         float metalness = 0.0;
      #endif

      gl_FragData[1] = vec4(ndc2screen(outNormalModel), 1.0);
      #ifdef GENERATED_SPECULAR
         gl_FragData[2] = vec4(clamp(smoothness, 0.0, 0.95), metalness, 0.5, 1.0);
      #else
         gl_FragData[2] = vec4(smoothness, blockReflectivity.z, 0.5, 1.0);
      #endif
   #else
      gl_FragData[1] = vec4(vec3(0.0), 1.0);
      gl_FragData[2] = vec4(vec3(0.0), 1.0);
   #endif
}
