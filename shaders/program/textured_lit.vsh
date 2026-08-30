#include "/shader.h"

#if !defined DH_TERRAIN && !defined GBUFFERS_TEXTURED
#define HAS_BLOCK_ATTRIBUTES
attribute vec4 mc_Entity;

#ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
   attribute vec4 at_midBlock;
#endif
#endif

#if (defined GBUFFERS_TERRAIN || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND) && !defined DH_TERRAIN && (defined WAVING_LEAVES || defined WAVING_PLANTS || defined GENERATED_NORMALS)
attribute vec4 mc_midTexCoord;
#endif

#if (defined GBUFFERS_TERRAIN || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND) && !defined DH_TERRAIN && defined GENERATED_NORMALS
attribute vec4 at_tangent;
#endif

#if defined GBUFFERS_TERRAIN && !defined DH_TERRAIN && (defined WAVING_LEAVES || defined WAVING_PLANTS)
#ifndef FRAME_TIME_COUNTER_UNIFORM
#define FRAME_TIME_COUNTER_UNIFORM
uniform float frameTimeCounter;
#endif
uniform float rfSnowBiome;
#endif

uniform float rainStrength;
#define RAIN_STRENGTH_UNIFORM
uniform float screenBrightness;
uniform int isEyeInWater;
uniform int worldTime;
uniform vec3 sunPosition;
#define SUN_POSITION_UNIFORM

#ifdef HIGHLIGHT_WAXED
   uniform int heldItemId;
   uniform int heldItemId2;
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

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/blockSemantics.glsl"
#include "/common/getFogMix.vsh"
#include "/common/getFogColor.vsh"

#if defined GBUFFERS_TERRAIN && !defined DH_TERRAIN && (defined WAVING_LEAVES || defined WAVING_PLANTS)
   #include "/common/getWaving.vsh"
#endif

#ifdef DH_TERRAIN
   #define GET_DH_LIGHTMAP_UV
   #include "/common/dh_lightmap.glsl"

   uniform mat4 dhProjection;
#endif

#ifdef ENABLE_SHADOWS
   uniform vec3 shadowLightPosition;

   varying vec3 lightColor;
   varying float diffuse;
   varying vec3 shadowNormal;

   #include "/common/getDiffuse.vsh"
   #include "/common/getLightColor.vsh"
#endif

#if BLOCK_REFLECTIONS > 0 && !defined GENERATED_SPECULAR
   #include "/common/blockReflectivity.glsl"
#endif

void main() {
   #ifdef HAS_BLOCK_ATTRIBUTES
      RfBlockInfo block = rfDecodeBlock(mc_Entity.x);
   #endif

   vec4 viewPos;

   #ifdef DH_TERRAIN
      vec3 cameraOffset = fract(cameraPosition);
      vec3 local = gl_Vertex.xyz;
      local.xz = floor(local.xz + cameraOffset.xz + 0.5) - cameraOffset.xz;
      viewPos = gl_ModelViewMatrix * vec4(local, 1.0);
   #else
      viewPos = gl_ModelViewMatrix * gl_Vertex;
   #endif

   sunHeight = view2feet(sunPosition).y;
   color     = gl_Color;
   texUV     = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;

   #ifdef DH_TERRAIN
      lightUV = getDhLightMapUV();
   #else
      lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
   #endif

   #if defined GBUFFERS_TERRAIN && !defined DH_TERRAIN && (defined WAVING_LEAVES || defined WAVING_PLANTS)
      if (isWavingBlock(block.flags)) {
         float isTop = float(gl_MultiTexCoord0.t < mc_midTexCoord.t);
         vec3 wavedFeet = view2feet(viewPos.xyz);
         wavedFeet += getWavingOffset(wavedFeet, block.flags, clamp(lightUV.t, 0.0, 1.0), isTop);
         viewPos = vec4(feet2view(wavedFeet), 1.0);
      }
   #endif

   #ifdef DH_TERRAIN
      gl_Position = dhProjection * viewPos;
   #else
      gl_Position = gl_ProjectionMatrix * viewPos;
   #endif

   #ifdef DH_TERRAIN
      #ifndef DH_BLOCK_LEAVES
         #define DH_BLOCK_LEAVES 1
      #endif
      #ifndef DH_BLOCK_LAVA
         #define DH_BLOCK_LAVA 7
      #endif
      #ifndef DH_BLOCK_ILLUMINATED
         #define DH_BLOCK_ILLUMINATED 15
      #endif

      lightSourceLevel = float(dhMaterialId == DH_BLOCK_ILLUMINATED || dhMaterialId == DH_BLOCK_LAVA);
      dhIsLeaves = float(dhMaterialId == DH_BLOCK_LEAVES);
      #ifdef FOLIAGE_SSS
         isFoliage = dhIsLeaves;
      #endif
      bool isThin = false;

      if (dhMaterialId == DH_BLOCK_LAVA) {
         color.rgb = mix(vec3(0.8, 0.5, 0.3), vec3(1.0), rescale(color.rgb, vec3(0.54), vec3(0.9)));
      }
   #elif defined HAS_BLOCK_ATTRIBUTES
      lightSourceLevel = float((block.flags & RF_LIGHT) != 0);

      #ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
         lightSourceLevel = max(lightSourceLevel, at_midBlock.w < 16.0 ? at_midBlock.w / 15.0 : 0.0);
      #endif

      #ifdef FOLIAGE_SSS
         isFoliage = float((block.flags & RF_FOLIAGE_SSS) != 0);
      #endif

      bool isThin = (block.flags & RF_THIN) != 0;

      if ((block.flags & RF_LAVA_TINT) != 0) {
         color.rgb = mix(vec3(0.8, 0.5, 0.3), vec3(1.0), rescale(color.rgb, vec3(0.54), vec3(0.9)));
      }
   #else
      lightSourceLevel = 0.0;
      bool isThin = false;
      #ifdef FOLIAGE_SSS
         isFoliage = 0.0;
      #endif
   #endif

   #ifdef THE_END
      endTint = END_AMBIENT + 0.02*(gl_NormalMatrix * gl_Normal).xyz;
   #endif

   #if defined GENERATED_SPECULAR || defined GENERATED_EMISSION || defined GENERATED_NORMALS
      #ifdef DH_TERRAIN
         materialId = 0.0;
         blockFlags = 0.0;
      #elif defined HAS_BLOCK_ATTRIBUTES
         materialId = float(block.matClass);
         blockFlags = float(block.flags);
      #else
         materialId = 0.0;
         blockFlags = 0.0;
      #endif
   #endif

   #ifdef FLOWER_FESTIVAL
      #ifdef HAS_BLOCK_ATTRIBUTES
         isFlower = float((block.flags & RF_FLOWER) != 0);
      #else
         isFlower = 0.0;
      #endif
   #endif

   #if BLOCK_REFLECTIONS > 0 || defined GENERATED_SPECULAR || defined GENERATED_NORMALS
      normal = ndc2screen(gl_Normal);

      #ifdef DH_TERRAIN
         blockReflectivity = vec3(0.15, 0.35, 0.0);
      #elif defined GENERATED_SPECULAR
         blockReflectivity = vec3(0.0);
      #elif defined HAS_BLOCK_ATTRIBUTES
         blockReflectivity = BLOCK_REFLECTIVITY[int(clamp(float(block.matClass), 0.0, 39.0))];
      #else
         blockReflectivity = vec3(0.0);
      #endif
   #endif

   #ifdef GENERATED_NORMALS
      #if (defined GBUFFERS_TERRAIN || defined GBUFFERS_BLOCK || defined GBUFFERS_ENTITIES || defined GBUFFERS_HAND) && !defined DH_TERRAIN
         vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).st;
         vec2 texMinMidCoord = texUV - midCoord;
         signMidCoordPos = sign(texMinMidCoord);
         absMidCoordPos = abs(texMinMidCoord);

         tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
         binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
      #endif
   #endif

   #ifdef GLOWING_ORES
      #ifdef HAS_BLOCK_ATTRIBUTES
         isOre = float((block.flags & RF_ORE) != 0);
      #else
         isOre = 0.0;
      #endif
   #endif

   #ifdef HAS_BLOCK_ATTRIBUTES
      #ifdef HIGHLIGHT_WAXED
         color.rgb *= (heldItemId == 20007 || heldItemId2 == 20007) && block.rawId == 20007 ? 0.4 : 1.0;
      #endif
   #endif

   #ifndef FLAT_LIGHTING
      vec3 lightNormal = gl_NormalMatrix * gl_Normal;

      lightNormal = isThin ? vec3(0.0, 1.0, 0.0) : view2eye(lightNormal);

      color.rgb *= clamp(lightNormal.x * lightNormal.x * 0.6
                       + lightNormal.y * lightNormal.y * 0.25 * (3.0 + lightNormal.y)
                       + lightNormal.z * lightNormal.z * 0.8, step(0.933, lightSourceLevel), 1.0);
   #endif

   feetPos = view2feet(viewPos.xyz);

   #ifdef DH_TERRAIN
      dhWorldNormal = view2eye(gl_NormalMatrix * gl_Normal);
   #endif

   fogMix = getFogMix(feetPos);
   fogMix = mix(fogMix, fogMix*fogMix, lightSourceLevel);
   gradientFogColor = getFogColor(fogMix, feetPos);

   #ifdef ENABLE_SHADOWS
      float skyLight = clamp(lightUV.t, 0.0, 1.0);

      diffuse = getDiffuse(sunHeight, skyLight, isThin);
      lightColor = getLightColor(sunHeight, skyLight);
      shadowNormal = view2eye(gl_NormalMatrix * gl_Normal);
   #endif
}
