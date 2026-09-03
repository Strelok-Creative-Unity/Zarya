#include "/common/lpvSample.fsh"

float rfShapeTorchStrength(float strength, float gloom) {
   strength = mix(strength*strength, smoothe(strength), screenBrightness);
   strength = mix(strength*strength, strength, max(1.0 - screenBrightness, eyeBrightnessSmooth.y/240.0));
   return mix(strength, sqrt(max(strength, 0.0)), gloom * 0.22);
}

vec3 rfTorchGradient(float strength) {
   return mix(
      mix(TORCH_OUTER_COLOR, TORCH_MIDDLE_COLOR, strength),
      TORCH_INNER_COLOR,
      slopeTo1(strength, 8.0)
   );
}

vec3 getTorchColor(float torchLight, vec3 ambient, vec3 feetPos, vec3 worldNormal) {
   float mapLight = rescale(torchLight, TORCH_UV_SCALE.x, TORCH_UV_SCALE.y);

   #if HAND_DYNAMIC_LIGHTING >= 0
      float handLight = rescale(float(heldBlockLightValue) - SQRT_2 * length(feetPos), 0.0, 15.0);
   #else
      float handLight = 0.0;
   #endif

   float fill = max(0.0, 1.0 - luma(ambient));
   #if defined THE_END || defined THE_NETHER
      fill = max(fill, 0.88);
   #endif
   float gloom = fill * fill;
   float intensity = mix(1.0, 1.38, gloom);

   float strength = rfShapeTorchStrength(max(mapLight, handLight), gloom);
   vec3 result = fill * intensity * strength * rfTorchGradient(strength);

   #ifdef LPV_ACTIVE
      float lpvCoverage;
      vec3 lpv = lpvSample(feetPos, worldNormal, lpvCoverage)
               * (LPV_BRIGHTNESS * intensity * mix(LPV_DAY_LEAK, 1.0, fill));

      float volumePeak = lpvPeak(lpv);
      float vanillaPeak = lpvPeak(result);

      if (volumePeak > 1.0e-4) {
         float mapWeight = smoothstep(0.02, 0.12, vanillaPeak);
         lpv *= mix(volumePeak, max(volumePeak, vanillaPeak), mapWeight) / volumePeak;
         result = mix(result, lpv, lpvCoverage);
      }
   #endif

   return result;
}
