#include "/shader.h"
#include "/common/lpvCommon.glsl"
#include "/common/lpvColors.glsl"
#include "/common/blockSemantics.glsl"

attribute vec4 mc_Entity;

#if defined WAVING_LEAVES || defined WAVING_PLANTS
attribute vec4 mc_midTexCoord;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float rfSnowBiome;
#endif

#if defined WAVING_LEAVES || defined WAVING_PLANTS || defined LPV_ACTIVE || defined COLORED_SHADOWS
uniform vec3 cameraPosition;
uniform mat4 shadowModelViewInverse;
#endif

#ifdef COLORED_SHADOWS
#ifndef AT_MIDBLOCK_ATTR
#define AT_MIDBLOCK_ATTR
attribute vec4 at_midBlock;
#endif
#endif

varying vec2 texUV;
varying float alpha;
varying float shadowTint;
varying vec3 shadowVertColor;
varying vec3 shadowFilterColor;

#ifdef MC_RENDER_STAGE_TERRAIN_TRANSLUCENT
#ifndef RENDER_STAGE_UNIFORM
#define RENDER_STAGE_UNIFORM
uniform int renderStage;
#endif
#endif

#include "/common/getShadowDistortion.glsl"
#include "/common/lpvVoxelize.vsh"

#if defined WAVING_LEAVES || defined WAVING_PLANTS
   #include "/common/getWaving.vsh"
#endif

void main() {
   RfBlockInfo block = rfDecodeBlock(mc_Entity.x);
   int id = block.rawId;

   shadowTint = 0.0;
   #ifdef MC_RENDER_STAGE_TERRAIN_TRANSLUCENT
      if (renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT) {
         shadowTint = 1.0;
      }
   #endif
   if ((id >= 21000 && id <= 21016) || id == 20018 || id == 10008
       || id == 20014 || id == 20015 || id == 20019 || id == 20034 || id == 21017) {
      shadowTint = 1.0;
   }

   shadowFilterColor = vec3(1.0);
   if (id >= 21000 && id <= 21016) {
      shadowFilterColor = LPV_TINT_COLOR[id - 21000];
   } else if (id == 20018) {
      shadowFilterColor = LPV_TINT_COLOR[17];
   } else if (id == 10008) {
      shadowFilterColor = LPV_TINT_COLOR[21];
   } else if (id == 20014 || id == 20015 || id == 20019) {
      shadowFilterColor = LPV_TINT_COLOR[18];
   } else if (id == 20034) {
      shadowFilterColor = LPV_TINT_COLOR[19];
   } else if (id == 21017) {
      shadowFilterColor = LPV_TINT_COLOR[20];
   }

   vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

   #if defined WAVING_LEAVES || defined WAVING_PLANTS
      if (isWavingBlock(block.flags)) {
         vec4 playerPos = shadowModelViewInverse * viewPos;
         float skyLight = clamp((gl_TextureMatrix[1] * gl_MultiTexCoord1).t, 0.0, 1.0);
         float isTop = float(gl_MultiTexCoord0.t < mc_midTexCoord.t);
         playerPos.xyz += getWavingOffset(playerPos.xyz, block.flags, skyLight, isTop);
         viewPos = gl_ModelViewMatrix * playerPos;
      }
   #endif

   #ifdef COLORED_SHADOWS
      if (shadowTint > 0.5 && id != 10008 && dot(at_midBlock.xyz, at_midBlock.xyz) > 2.0) {
         vec4 playerPos = shadowModelViewInverse * viewPos;
         vec3 rel = -at_midBlock.xyz * (1.0 / 64.0);
         vec3 cube = 0.499 * sign(rel + vec3(1.0e-4));
         playerPos.xyz += cube - rel;
         viewPos = gl_ModelViewMatrix * playerPos;
      }
   #endif

   gl_Position = gl_ProjectionMatrix * viewPos;
   gl_Position.xyz = getShadowDistortion(gl_Position.xyz);

   texUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
   alpha = (block.flags & RF_FIRE_ALPHA) != 0 ? 0.0 : gl_Color.a;
   shadowVertColor = gl_Color.rgb;

   #ifdef LPV_ACTIVE
      lpvVoxelizeVertex(mc_Entity.x);
   #endif

   #ifdef SHADOW_VOXELIZE_ONLY
      gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
   #endif
}
