#ifndef RF_BLOCK_SEMANTICS_GLSL
#define RF_BLOCK_SEMANTICS_GLSL

// 10xxx behavior (fluids, fire, plants, light), 20xxx material class (= id - 20000), 21xxx LPV palette (!!!MVP!!!) (folds into 10xxx/20xxx)

#define RF_WAVE_LEAVES    1
#define RF_WAVE_PLANT     2
#define RF_WAVE_UPPER     4
#define RF_THIN           8
#define RF_FOLIAGE_SSS   16
#define RF_LIGHT         32
#define RF_ORE           64
#define RF_LAVA_TINT    128
#define RF_WATER        256
#define RF_FIRE_ALPHA   512
#define RF_EMIT_STRONG 1024
#define RF_EMIT_TORCH  2048
#define RF_FLOWER      4096

struct RfBlockInfo {
   int flags;
   int matClass;
   int rawId;
};

float rfEffectiveId(float rawId) {
   int mat = int(rawId + 0.5);

   if (mat < 21000 || mat > 21062) {
      return rawId;
   }
   if (mat <= 21016) return 20018.0;
   if (mat == 21017) return 20034.0;
   if (mat >= 21020 && mat <= 21026) return 20039.0;
   if (mat == 21043) return 20025.0;
   if (mat >= 21061) return 10014.0;
   if (mat >= 21056 && mat <= 21059) return 10059.0;

   return 0.0;
}

void rfSetBehaviorFlags(int id, inout int flags) {
   if (id == 10301) {
      flags |= RF_WAVE_LEAVES | RF_FOLIAGE_SSS;
   } else if (id == 10302) {
      flags |= RF_WAVE_UPPER | RF_THIN;
   } else if (id == 10008) {
      flags |= RF_WATER;
   } else if (id == 10014) {
      flags |= RF_ORE;
   } else if (id == 10031 || id == 10059) {
      flags |= RF_WAVE_PLANT | RF_THIN;
   } else if (id == 10060 || id == 10063 || id == 10064 || id == 10065
           || id == 10066 || id == 10067 || id == 10069 || id == 10070) {
      flags |= RF_WAVE_PLANT | RF_THIN | RF_FLOWER;
   } else if (id == 10071 || id == 10073 || id == 10074 || id == 10075) {
      flags |= RF_WAVE_UPPER | RF_THIN | RF_FLOWER;
   } else if (id == 10062) {
      flags |= RF_FLOWER;
   } else if (id == 10175 || id == 10176) {
      flags |= RF_THIN;
   } else if (id == 10068) {
      flags |= RF_LIGHT | RF_LAVA_TINT | RF_EMIT_STRONG;
   } else if (id == 10072) {
      flags |= RF_LIGHT | RF_EMIT_STRONG | RF_FIRE_ALPHA;
   } else if (id == 10076) {
      flags |= RF_LIGHT | RF_EMIT_STRONG;
   } else if (id == 10496 || id == 10528 || id == 10604 || id == 10984
           || id == 10652 || id == 10656) {
      flags |= RF_LIGHT | RF_EMIT_TORCH;
   }
}

RfBlockInfo rfDecodeBlock(float rawId) {
   RfBlockInfo info;
   info.rawId = int(rawId + 0.5);
   info.flags = 0;
   info.matClass = 0;

   float effective = rfEffectiveId(rawId);
   int id = int(effective + 0.5);

   if (id > 0) {
      rfSetBehaviorFlags(id, info.flags);
   }

   if (info.rawId >= 20001 && info.rawId <= 20040) {
      info.matClass = info.rawId - 20000;
   } else if (info.rawId == 20041) {
      info.matClass = 41;
   } else if (id >= 20001 && id <= 20040) {
      info.matClass = id - 20000;
   } else if (id == 20041) {
      info.matClass = 41;
   }

   if (info.matClass == 39) {
      info.flags |= RF_LIGHT;
   }

   return info;
}

#endif
