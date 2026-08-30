#include "/common/blockSemantics.glsl"

bool isWavingBlock(int flags) {
   #if defined WAVING_LEAVES || defined WAVING_PLANTS
      return (flags & (RF_WAVE_LEAVES | RF_WAVE_PLANT | RF_WAVE_UPPER)) != 0;
   #else
      return false;
   #endif
}

vec3 wavingHarmonics(float a, vec3 phase) {
   return sin(vec3(a) + phase)
        + 0.5  * sin(vec3(2.0 * a) + phase.yzx)
        + 0.35 * sin(vec3(3.0 * a) + phase.zxy)
        + 0.25 * sin(vec3(4.0 * a) + phase);
}

vec3 getWavingOffset(vec3 feetPos, int flags, float skyLight, float isTop) {
   bool isLeaves = (flags & RF_WAVE_LEAVES) != 0;
   bool isPlant = (flags & RF_WAVE_PLANT) != 0;
   bool isPlantUpper = (flags & RF_WAVE_UPPER) != 0;

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
