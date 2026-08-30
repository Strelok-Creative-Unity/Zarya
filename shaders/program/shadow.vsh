#include "/shader.h"
#include "/common/lpvCommon.glsl"
#include "/common/blockSemantics.glsl"

attribute vec4 mc_Entity;

#if defined WAVING_LEAVES || defined WAVING_PLANTS
attribute vec4 mc_midTexCoord;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float rfSnowBiome;
#endif

#if defined WAVING_LEAVES || defined WAVING_PLANTS || defined LPV_ACTIVE
uniform vec3 cameraPosition;
uniform mat4 shadowModelViewInverse;
#endif

varying vec2 texUV;
varying float alpha;

#include "/common/getShadowDistortion.glsl"
#include "/common/lpvVoxelize.vsh"

#if defined WAVING_LEAVES || defined WAVING_PLANTS
   #include "/common/getWaving.vsh"
#endif

void main() {
   RfBlockInfo block = rfDecodeBlock(mc_Entity.x);

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

   gl_Position = gl_ProjectionMatrix * viewPos;
   gl_Position.xyz = getShadowDistortion(gl_Position.xyz);

   texUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
   alpha = (block.flags & RF_FIRE_ALPHA) != 0 ? 0.0 : gl_Color.a;

   #ifdef LPV_ACTIVE
      lpvVoxelizeVertex(mc_Entity.x);
   #endif

   #ifdef SHADOW_VOXELIZE_ONLY
      gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
   #endif
}
