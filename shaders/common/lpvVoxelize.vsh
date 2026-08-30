#ifndef RF_LPV_VOXELIZE_VSH
#define RF_LPV_VOXELIZE_VSH

#include "/common/lpvCommon.glsl"

#ifdef LPV_ACTIVE

attribute vec4 at_midBlock;

uniform int renderStage;

layout(r32f) uniform writeonly image3D lpvVoxelImg;

int lpvBlockId(float matId) {
   int mat = int(matId + 0.5);

   if (mat >= 21000 && mat <= 21015) return LPV_ID_TINT + (mat - 21000);

   if (mat == 21016) return LPV_ID_TINT + LPV_TINT_TINTED;
   if (mat == 21017) return LPV_ID_TINT + LPV_TINT_HONEY;
   if (mat == 20018) return LPV_ID_TINT + LPV_TINT_GLASS;
   if (mat == 20019 || mat == 20014 || mat == 20015) return LPV_ID_TINT + LPV_TINT_ICE;
   if (mat == 20034) return LPV_ID_TINT + LPV_TINT_SLIME;
   if (mat == 10008) return LPV_ID_TINT + LPV_TINT_WATER;
   if (mat == 10301) return LPV_ID_TINT + LPV_TINT_LEAVES;

   if (mat == 10496) return LPV_ID_EMIT + LPV_EMIT_TORCH;
   if (mat == 10528) return LPV_ID_EMIT + LPV_EMIT_SOUL_TORCH;
   if (mat == 10604) return LPV_ID_EMIT + LPV_EMIT_REDSTONE_TORCH;
   if (mat == 10984) return LPV_ID_EMIT + LPV_EMIT_COPPER_TORCH;
   if (mat == 10652) return LPV_ID_EMIT + LPV_EMIT_CAMPFIRE;
   if (mat == 10656) return LPV_ID_EMIT + LPV_EMIT_SOUL_CAMPFIRE;
   if (mat == 10072) return LPV_ID_EMIT + LPV_EMIT_FIRE;
   if (mat == 10076) return LPV_ID_EMIT + LPV_EMIT_SOUL_FIRE;

   if (mat == 21035) return LPV_ID_EMIT + LPV_EMIT_END_PORTAL;
   if (mat == 21036) return LPV_ID_EMIT + LPV_EMIT_NETHER_PORTAL;
   if (mat == 21041) return LPV_ID_EMIT + LPV_EMIT_LIGHT_BLOCK;
   if (mat == 21044) return LPV_ID_EMIT + LPV_EMIT_ENCHANTING_TABLE;
   if (mat == 21050) return LPV_ID_EMIT + LPV_EMIT_LANTERN;
   if (mat == 21051) return LPV_ID_EMIT + LPV_EMIT_SOUL_LANTERN;
   if (mat == 21053) return LPV_ID_EMIT + LPV_EMIT_END_ROD;
   if (mat == 21054) return LPV_ID_EMIT + LPV_EMIT_CANDLE;
   if (mat == 21055) return LPV_ID_EMIT + LPV_EMIT_BREWING_STAND;
   if (mat == 21056) return LPV_ID_EMIT + LPV_EMIT_GLOW_LICHEN;
   if (mat == 21057) return LPV_ID_EMIT + LPV_EMIT_GLOW_BERRIES;
   if (mat == 21058) return LPV_ID_EMIT + LPV_EMIT_FIREFLY_BUSH;
   if (mat == 21059) return LPV_ID_EMIT + LPV_EMIT_EYEBLOSSOM;
   if (mat == 21060) return LPV_ID_EMIT + LPV_EMIT_SEA_PICKLE;
   if (mat == 21061) return LPV_ID_EMIT + LPV_EMIT_TORCHFLOWER;
   if (mat == 21062) return LPV_ID_EMIT + LPV_EMIT_AMETHYST;

   #ifdef FLOWER_FESTIVAL
      if (mat == 10060 || mat == 10071) return LPV_ID_EMIT + LPV_EMIT_FLOWER_YELLOW;
      if (mat == 10063 || mat == 10073) return LPV_ID_EMIT + LPV_EMIT_FLOWER_RED;
      if (mat == 10064) return LPV_ID_EMIT + LPV_EMIT_FLOWER_BLUE;
      if (mat == 10065 || mat == 10074) return LPV_ID_EMIT + LPV_EMIT_FLOWER_PURPLE;
      if (mat == 10066) return LPV_ID_EMIT + LPV_EMIT_FLOWER_WHITE;
      if (mat == 10067 || mat == 10075) return LPV_ID_EMIT + LPV_EMIT_FLOWER_PINK;
      if (mat == 10069) return LPV_ID_EMIT + LPV_EMIT_FLOWER_ORANGE;
      if (mat == 10070) return LPV_ID_EMIT + LPV_EMIT_FLOWER_DARK;
      if (mat == 10062) return LPV_ID_EMIT + LPV_EMIT_FLOWER;
   #endif

   if (mat == 10068) return LPV_ID_EMIT + LPV_EMIT_LAVA;
   if (mat == 21020) return LPV_ID_EMIT + LPV_EMIT_GLOWSTONE;
   if (mat == 21021) return LPV_ID_EMIT + LPV_EMIT_SHROOMLIGHT;
   if (mat == 21022) return LPV_ID_EMIT + LPV_EMIT_FROGLIGHT_OCHRE;
   if (mat == 21023) return LPV_ID_EMIT + LPV_EMIT_FROGLIGHT_VERD;
   if (mat == 21024) return LPV_ID_EMIT + LPV_EMIT_FROGLIGHT_PEARL;
   if (mat == 21025) return LPV_ID_EMIT + LPV_EMIT_SEA_LANTERN;
   if (mat == 21026) return LPV_ID_EMIT + LPV_EMIT_JACK_O_LANTERN;
   if (mat == 21030) return LPV_ID_EMIT + LPV_EMIT_REDSTONE_LAMP;
   if (mat == 21031) return LPV_ID_EMIT + LPV_EMIT_MAGMA;
   if (mat == 21032) return LPV_ID_EMIT + LPV_EMIT_BEACON;
   if (mat == 21033) return LPV_ID_EMIT + LPV_EMIT_CONDUIT;
   if (mat == 21034) return LPV_ID_EMIT + LPV_EMIT_RESPAWN_ANCHOR;
   if (mat == 21037) return LPV_ID_EMIT + LPV_EMIT_FURNACE;
   if (mat == 21039) return LPV_ID_EMIT + LPV_EMIT_TRIAL_SPAWNER;
   if (mat == 21040) return LPV_ID_EMIT + LPV_EMIT_CREAKING_HEART;
   if (mat == 21043) return LPV_ID_EMIT + LPV_EMIT_CRYING_OBSIDIAN;

   return -1;
}

bool lpvIsPartialEmitter(int mat) {
   return mat == 10496 || mat == 10528 || mat == 10604 || mat == 10984
       || mat == 10652 || mat == 10656 || mat == 10072 || mat == 10076
       || mat == 21035 || mat == 21036 || mat == 21041 || mat == 21044
       || mat == 21050 || mat == 21051 || mat == 21053 || mat == 21054
       || mat == 21055 || mat == 21056 || mat == 21057 || mat == 21058
       || mat == 21059 || mat == 21060 || mat == 21061 || mat == 21062
   #ifdef FLOWER_FESTIVAL
       || mat == 10060 || mat == 10062 || mat == 10063 || mat == 10064
       || mat == 10065 || mat == 10066 || mat == 10067 || mat == 10069
       || mat == 10070 || mat == 10071 || mat == 10073 || mat == 10074
       || mat == 10075
   #endif
   ;
}

void lpvVoxelizeVertex(float matId) {
   if (renderStage != MC_RENDER_STAGE_TERRAIN_SOLID
    && renderStage != MC_RENDER_STAGE_TERRAIN_TRANSLUCENT
    && renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT
    && renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED) {
      return;
   }

   vec3 modelPos = gl_Vertex.xyz + at_midBlock.xyz / 64.0;
   vec3 viewPos = (gl_ModelViewMatrix * vec4(modelPos, 1.0)).xyz;
   vec3 playerPos = (shadowModelViewInverse * vec4(viewPos, 1.0)).xyz;
   vec3 voxelPos = lpvFeetToVoxel(playerPos, cameraPosition);

   if (!lpvInsideVolume(voxelPos)) {
      return;
   }

   int mat = int(matId + 0.5);
   int id = lpvBlockId(matId);
   bool porous;

   if (id >= 0) {
      porous = lpvIsPartialEmitter(mat) || (id >= LPV_ID_TINT && id < LPV_ID_LEVEL);
   } else {
      int level = int(at_midBlock.w + 0.5);
      id = (level > 0 && level < 16) ? LPV_ID_LEVEL + level : LPV_ID_SOLID;
      porous = renderStage != MC_RENDER_STAGE_TERRAIN_SOLID;
   }

   imageStore(lpvVoxelImg, ivec3(voxelPos), vec4(lpvPackCell(id, porous), 0.0, 0.0, 0.0));
}

#endif
#endif
