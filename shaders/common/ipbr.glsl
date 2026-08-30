
#ifndef IPBR_GLSL
#define IPBR_GLSL

#include "/common/blockSemantics.glsl"

#define IPBR_METAL_HEAVY       1
#define IPBR_DEEPSLATE_BRICK   2
#define IPBR_POLISHED_TUFF     3
#define IPBR_STONE_BRICK       4
#define IPBR_BLACKSTONE        5
#define IPBR_POLISHED_DEEP     6
#define IPBR_WAXED_COPPER      7
#define IPBR_COPPER            8
#define IPBR_COPPER_OXIDIZED   41
#define IPBR_COBBLE            9
#define IPBR_POLISHED_GRANITE  10
#define IPBR_POLISHED_ANDESITE 11
#define IPBR_POLISHED_DIORITE  12
#define IPBR_IRON_BARS         13
#define IPBR_BLUE_ICE          14
#define IPBR_PACKED_ICE        15
#define IPBR_ORE_BLOCKS        16
#define IPBR_QUARTZ            17
#define IPBR_GLASS             18
#define IPBR_ICE               19
#define IPBR_RAW_METAL         20
#define IPBR_GEM_BLOCKS        21
#define IPBR_TERRACOTTA        22
#define IPBR_CONCRETE          23
#define IPBR_PRISMARINE        24
#define IPBR_OBSIDIAN          25
#define IPBR_NETHER_BRICK      26
#define IPBR_PLANKS            27
#define IPBR_SAND              28
#define IPBR_SCULK             29
#define IPBR_AMETHYST          30
#define IPBR_PURPUR            31
#define IPBR_BRICKS            32
#define IPBR_DARK              33
#define IPBR_SLIME_HONEY       34
#define IPBR_CALCITE           35
#define IPBR_END_STONE         36
#define IPBR_NETHERRACK        37
#define IPBR_WOOL              38
#define IPBR_GLOWSTONE         39
#define IPBR_GROUND            40

float ipbrChroma(vec3 c) {
   float mn = min(c.r, min(c.g, c.b));
   float mx = max(c.r, max(c.g, c.b));
   return mx - mn;
}

vec4 generateIPBR(float matClass, float flags, vec3 albedo) {
   float lumaA = clamp(luma(albedo), 0.0, 1.0);
   float luma2 = lumaA * lumaA;
   float luma3 = luma2 * lumaA;
   float chroma = ipbrChroma(albedo);

   float smoothness = 0.0;
   float metalness = 0.0;
   float emission = 0.0;

   int cls = int(matClass);
   int f = int(flags);

   #ifdef GENERATED_SPECULAR_ON_ALL
      smoothness = 0.03 * lumaA;
   #endif

   if ((f & RF_ORE) != 0) {
      emission = clamp(chroma * 2.2 - 0.1, 0.0, 1.0) * lumaA;
   } else if ((f & RF_EMIT_STRONG) != 0) {
      emission = max(emission, 0.9);
   } else if ((f & RF_EMIT_TORCH) != 0) {
      emission = max(emission, 0.65 + 0.3 * lumaA);
   }

   if (cls == IPBR_METAL_HEAVY) {
      smoothness = min(0.95, 0.78 + lumaA * 0.17);
      metalness = 0.98;
   } else if (cls == IPBR_WAXED_COPPER || cls == IPBR_COPPER) {
      smoothness = min(0.95, 0.82 + lumaA * 0.12);
      metalness = 0.96;
   } else if (cls == IPBR_COPPER_OXIDIZED) {
      smoothness = 0.0;
      metalness = 0.0;
   } else if (cls == IPBR_IRON_BARS) {
      smoothness = min(0.95, 0.80 + lumaA * 0.14);
      metalness = 0.96;
   } else if (cls == IPBR_ORE_BLOCKS) {
      smoothness = min(0.94, 0.70 + luma2 * 0.24);
      metalness = 0.92;
   } else if (cls == IPBR_RAW_METAL) {
      smoothness = min(0.88, 0.55 + lumaA * 0.30);
      metalness = 0.80;
   } else if (cls == IPBR_GEM_BLOCKS) {
      smoothness = 0.70 + luma2 * 0.25;
      metalness = 0.35;
   } else if (cls == IPBR_BLUE_ICE) {
      smoothness = 0.90 + lumaA * 0.05;
   } else if (cls == IPBR_PACKED_ICE) {
      smoothness = 0.82 + lumaA * 0.12;
   } else if (cls == IPBR_ICE) {
      smoothness = 0.78 + lumaA * 0.16;
   } else if (cls == IPBR_GLASS) {
      smoothness = 0.96;
   } else if (cls == IPBR_POLISHED_DEEP) {
      smoothness = 0.58 + lumaA * 0.30;
   } else if (cls == IPBR_POLISHED_GRANITE || cls == IPBR_POLISHED_ANDESITE || cls == IPBR_POLISHED_DIORITE) {
      smoothness = 0.52 + lumaA * 0.35;
   } else if (cls == IPBR_POLISHED_TUFF) {
      smoothness = 0.45 + lumaA * 0.30;
   } else if (cls == IPBR_OBSIDIAN) {
      smoothness = 0.50 + luma2 * 0.42;
   } else if (cls == IPBR_AMETHYST) {
      smoothness = 0.72 + lumaA * 0.20;
      emission = max(emission, chroma * 0.45);
   } else if (cls == IPBR_SLIME_HONEY) {
      smoothness = 0.72 + lumaA * 0.20;
   } else if (cls == IPBR_QUARTZ) {
      smoothness = 0.48 + lumaA * 0.35;
   } else if (cls == IPBR_PRISMARINE) {
      smoothness = 0.50 + lumaA * 0.35;
   } else if (cls == IPBR_CALCITE) {
      smoothness = 0.45 + lumaA * 0.28;
   } else if (cls == IPBR_STONE_BRICK || cls == IPBR_DEEPSLATE_BRICK || cls == IPBR_BLACKSTONE) {
      smoothness = 0.45 + lumaA * 0.30;
   } else if (cls == IPBR_SCULK) {
      emission = max(emission, chroma * 0.45 * lumaA);
   } else if (cls == IPBR_GLOWSTONE) {
      emission = max(emission, 0.85);
   }

   #ifndef GENERATED_EMISSION
      emission = 0.0;
   #endif

   #ifndef GENERATED_SPECULAR
      smoothness = 0.0;
      metalness = 0.0;
   #endif

   float emitDamp = mix(0.85, 0.25, metalness);
   smoothness = clamp(smoothness, 0.0, 0.95) * (1.0 - emitDamp * emission);
   metalness = clamp(metalness, 0.0, 1.0);
   emission = clamp(emission, 0.0, 1.0);

   float roughness = 1.0 - smoothness;
   return vec4(smoothness, metalness, emission, roughness);
}

#endif
