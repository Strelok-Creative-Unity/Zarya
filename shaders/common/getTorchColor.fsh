vec3 getTorchColor(float torchLight, vec3 ambient, vec3 feetPos) {
   float strength = rescale(torchLight, TORCH_UV_SCALE.x, TORCH_UV_SCALE.y);

   #if HAND_DYNAMIC_LIGHTING >= 0

      strength = max(strength, rescale(float(heldBlockLightValue) - SQRT_2 * length(feetPos), 0.0, 15.0));

   #endif

   strength = mix(strength*strength, smoothe(strength), screenBrightness);
   strength = mix(strength*strength, strength, max(1.0 - screenBrightness, eyeBrightnessSmooth.y/240.0));

   float fill = max(0.0, 1.0 - luma(ambient));
   float gloom = fill * fill;
   strength = mix(strength, sqrt(max(strength, 0.0)), gloom * 0.22);
   float intensity = mix(1.0, 1.38, gloom);

   vec3 torch = mix(
      mix(TORCH_OUTER_COLOR, TORCH_MIDDLE_COLOR, strength),
      TORCH_INNER_COLOR,
      slopeTo1(strength, 8.0)
   );

   #ifdef TMP_COLORED_LPV
      float lpv = TMP_LPV_STRENGTH;
      torch = mix(vec3(luma(torch)), torch, 1.0 + 0.55 * lpv);
      intensity *= mix(1.0, 1.22, lpv * gloom);

      float wash = pow(clamp(strength, 0.0, 1.0), 0.65) * fill * 0.18 * lpv;
      torch += TORCH_MIDDLE_COLOR * wash;
      strength = max(strength, wash * 0.35);
   #endif

   return fill * intensity * strength * torch;
}
