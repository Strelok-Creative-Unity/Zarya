#ifndef FOG_COLOR_UNIFORM
#define FOG_COLOR_UNIFORM
uniform vec3 fogColor;
#endif

#ifndef SKY_COLOR_UNIFORM
#define SKY_COLOR_UNIFORM
uniform vec3 skyColor;
#endif

#ifdef OVERWORLD
   #include "/common/getSkyColor.glsl"
#endif

vec3 getFogColor(float fogMix, vec3 feetPos) {
   #ifdef OVERWORLD
      vec3 horizon = getHorizonFogColor();
      return mix(horizon, mix(horizon, max(skyColor, horizon * 0.65), 0.45),
                 fogMix * clamp(0.006 * feetPos.y, 0.0, 1.0));
   #elif defined THE_NETHER
      vec3 biome = max(fogColor, vec3(0.001));
      float y = cameraPosition.y + feetPos.y;
      float lava = exp(-max(y - 32.0, 0.0) / 36.0);
      float roof = smoothstep(100.0, 128.0, y);
      float biomeL = max(luma(biome), 0.05);
      vec3 hue = biome / biomeL;
      vec3 ember = vec3(0.62, 0.26, 0.10);
      vec3 ash = vec3(0.22, 0.11, 0.10);
      vec3 mid = mix(hue * 0.28, mix(hue, ember, 0.20), 0.35) * 0.90;
      vec3 col = mix(mid, ember * 0.32, lava * 0.35);
      return mix(col, mix(mid, ash, 0.40), roof * 0.35);
   #else
      return fogColor;
   #endif
}
