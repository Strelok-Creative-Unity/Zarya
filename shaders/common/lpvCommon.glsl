#ifndef RF_LPV_COMMON_GLSL
#define RF_LPV_COMMON_GLSL

#if defined LPV_ENABLED && defined IRIS_FEATURE_CUSTOM_IMAGES && defined IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
   #define LPV_ACTIVE
#endif

#ifdef LPV_ACTIVE

const ivec3 LPV_VOLUME_SIZE  = ivec3(LPV_SIZE);
const vec3  LPV_VOLUME_SIZEF = vec3(LPV_SIZE);

#if LPV_SIZE == 64
   const float voxelDistance = 32.0;
#elif LPV_SIZE == 96
   const float voxelDistance = 48.0;
#elif LPV_SIZE == 128
   const float voxelDistance = 64.0;
#else
   const float voxelDistance = 96.0;
#endif

#define LPV_ID_AIR   0
#define LPV_ID_SOLID 1
#define LPV_ID_EMIT  16
#define LPV_ID_TINT  96
#define LPV_ID_LEVEL 144

#define LPV_PACK_SEAL 0.25
#define LPV_PACK_OPEN 0.75

#define LPV_DISPLAY_SCALE 0.265

#define LPV_EMIT_TORCH            0
#define LPV_EMIT_SOUL_TORCH       1
#define LPV_EMIT_REDSTONE_TORCH   2
#define LPV_EMIT_COPPER_TORCH     3
#define LPV_EMIT_LANTERN          4
#define LPV_EMIT_SOUL_LANTERN     5
#define LPV_EMIT_COPPER_LANTERN   6
#define LPV_EMIT_CAMPFIRE         7
#define LPV_EMIT_SOUL_CAMPFIRE    8
#define LPV_EMIT_FIRE             9
#define LPV_EMIT_SOUL_FIRE        10
#define LPV_EMIT_LAVA             11
#define LPV_EMIT_MAGMA            12
#define LPV_EMIT_GLOWSTONE        13
#define LPV_EMIT_SHROOMLIGHT      14
#define LPV_EMIT_FROGLIGHT_OCHRE  15
#define LPV_EMIT_FROGLIGHT_VERD   16
#define LPV_EMIT_FROGLIGHT_PEARL  17
#define LPV_EMIT_SEA_LANTERN      18
#define LPV_EMIT_JACK_O_LANTERN   19
#define LPV_EMIT_END_ROD          20
#define LPV_EMIT_REDSTONE_LAMP    21
#define LPV_EMIT_REDSTONE_BLOCK   22
#define LPV_EMIT_BEACON           23
#define LPV_EMIT_CONDUIT          24
#define LPV_EMIT_CRYING_OBSIDIAN  25
#define LPV_EMIT_RESPAWN_ANCHOR   26
#define LPV_EMIT_GLOW_LICHEN      27
#define LPV_EMIT_CANDLE           28
#define LPV_EMIT_BREWING_STAND    29
#define LPV_EMIT_ENCHANTING_TABLE 30
#define LPV_EMIT_NETHER_PORTAL    31
#define LPV_EMIT_END_PORTAL       32
#define LPV_EMIT_FURNACE          33
#define LPV_EMIT_COPPER_BULB      34
#define LPV_EMIT_SCULK            35
#define LPV_EMIT_TRIAL_SPAWNER    36
#define LPV_EMIT_VAULT            37
#define LPV_EMIT_CREAKING_HEART   38
#define LPV_EMIT_AMETHYST         39
#define LPV_EMIT_GLOW_BERRIES     40
#define LPV_EMIT_SEA_PICKLE       41
#define LPV_EMIT_FIREFLY_BUSH     42
#define LPV_EMIT_EYEBLOSSOM       43
#define LPV_EMIT_TORCHFLOWER      44
#define LPV_EMIT_LIGHT_BLOCK      45
#define LPV_EMIT_FLOWER           46
#define LPV_EMIT_FLOWER_YELLOW    47
#define LPV_EMIT_FLOWER_RED       48
#define LPV_EMIT_FLOWER_BLUE      49
#define LPV_EMIT_FLOWER_PURPLE    50
#define LPV_EMIT_FLOWER_WHITE     51
#define LPV_EMIT_FLOWER_PINK      52
#define LPV_EMIT_FLOWER_ORANGE    53
#define LPV_EMIT_FLOWER_DARK      54

#define LPV_TINT_WHITE      0
#define LPV_TINT_ORANGE     1
#define LPV_TINT_MAGENTA    2
#define LPV_TINT_LIGHT_BLUE 3
#define LPV_TINT_YELLOW     4
#define LPV_TINT_LIME       5
#define LPV_TINT_PINK       6
#define LPV_TINT_GRAY       7
#define LPV_TINT_LIGHT_GRAY 8
#define LPV_TINT_CYAN       9
#define LPV_TINT_PURPLE     10
#define LPV_TINT_BLUE       11
#define LPV_TINT_BROWN      12
#define LPV_TINT_GREEN      13
#define LPV_TINT_RED        14
#define LPV_TINT_BLACK      15
#define LPV_TINT_TINTED     16
#define LPV_TINT_GLASS      17
#define LPV_TINT_ICE        18
#define LPV_TINT_SLIME      19
#define LPV_TINT_HONEY      20
#define LPV_TINT_WATER      21
#define LPV_TINT_LEAVES     22

float lpvPackCell(int id, bool porous) {
   return float(id) + (porous ? LPV_PACK_OPEN : LPV_PACK_SEAL);
}

int lpvUnpackId(float raw) {
   return int(floor(raw + 0.001));
}

bool lpvCellPorous(float raw, int id) {
   return id == LPV_ID_AIR || (raw - float(id)) > 0.5;
}

vec3 lpvFeetToVoxel(vec3 feetPos, vec3 cameraPos) {
   vec3 volumeOrigin = vec3(floor(cameraPos)) - 0.5 * LPV_VOLUME_SIZEF;
   return feetPos + cameraPos - volumeOrigin;
}

bool lpvInsideVolume(vec3 voxelPos) {
   return all(greaterThanEqual(voxelPos, vec3(0.0)))
       && all(lessThan(voxelPos, LPV_VOLUME_SIZEF));
}

float lpvPeak(vec3 c) {
   return max(c.r, max(c.g, c.b));
}

vec3 lpvLimitPeak(vec3 c, float limit) {
   float peak = lpvPeak(c);
   return peak > limit ? c * (limit / peak) : c;
}

vec3 lpvPickStronger(vec3 a, vec3 b) {
   return dot(a, a) >= dot(b, b) ? a : b;
}

#endif
#endif
