
bool isWavingBlock(float blockId) {
   #ifdef WAVING_LEAVES
      if (blockId == 30001.0) return true;
   #endif

   #ifdef WAVING_PLANTS
      if (blockId == 10031.0 || blockId == 10059.0 || blockId == 300010.0) return true;
   #endif

   return false;
}

vec3 wavingHarmonics(float a, vec3 phase) {
   return sin(vec3(a) + phase)
        + 0.5  * sin(vec3(2.0 * a) + phase.yzx)
        + 0.35 * sin(vec3(3.0 * a) + phase.zxy)
        + 0.25 * sin(vec3(4.0 * a) + phase);
}

vec3 getWavingOffset(vec3 feetPos, float blockId, float skyLight, float isTop) {
   bool isLeaves = false;
   bool isPlant = false;
   bool isPlantUpper = false;

   #ifdef WAVING_LEAVES
      isLeaves = blockId == 30001.0;
   #endif

   #ifdef WAVING_PLANTS
      isPlant = blockId == 10031.0 || blockId == 10059.0;
      isPlantUpper = blockId == 300010.0;
   #endif

   if (!(isLeaves || isPlant || isPlantUpper)) {
      return vec3(0.0);
   }

   float snowing = rfSnowBiome * rainStrength;
   float raining = rainStrength * (1.0 - rfSnowBiome);
   float weather = (1.0 - snowing) * mix(1.0, WAVING_RAIN_MULT, raining);
   float amp = WAVING_AMPLITUDE * weather * skyLight * skyLight;

   if (amp < 1e-5) {
      return vec3(0.0);
   }

   if (isPlant && isTop < 0.5) {
      return vec3(0.0);
   }

   vec3 worldPos = feetPos + cameraPosition;

   float u = fract(frameTimeCounter / WAVING_CYCLE);
   float aClear = TAU * float(WAVING_WAVES) * u;
   float aRain  = TAU * float(WAVING_WAVES_RAIN) * u;

   vec3 phase = vec3(
      dot(worldPos, vec3(0.17, 0.31, 0.23)),
      dot(worldPos, vec3(0.29, 0.13, 0.37)),
      dot(worldPos, vec3(0.19, 0.41, 0.11))
   );

   vec3 wave = mix(wavingHarmonics(aClear, phase), wavingHarmonics(aRain, phase), raining);

   vec3 scale = isLeaves ? vec3(0.04) : vec3(0.12, 0.03, 0.12);
   return wave * scale * amp;
}
