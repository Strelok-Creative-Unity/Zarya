#ifndef GET_WATER_FOG_GLSL
#define GET_WATER_FOG_GLSL


#ifndef WATER_FOG_DENSITY
   #define WATER_FOG_DENSITY 2.2
#endif

#ifndef WATER_FOG_EXPONENT
   #define WATER_FOG_EXPONENT (-1.6)
#endif

vec3 getWaterBaseTint() {
   vec3 tint = vec3(0.18, 0.41, 0.58) * vec3(1.0, 0.88, 0.82);
   tint.b *= WATER_B / 1.3;
   tint *= 0.52 + WATER_BRIGHTNESS;
   return tint;
}

vec3 getUnderwaterFogColor(float skyLight) {
   vec3 fogCol = getWaterBaseTint();

   #ifdef OVERWORLD
      fogCol *= 0.12 + skyLight * 0.62;
      #ifdef RAIN_STRENGTH_UNIFORM
         fogCol = mix(fogCol, fogCol * vec3(0.82, 0.91, 1.06), rainStrength * 0.32);
      #endif
   #else
      fogCol *= 0.33;
   #endif

   fogCol = max(fogCol, vec3(0.012, 0.028, 0.042));
   return fogCol;
}

vec4 getWaterFog(inout vec3 colorMult, vec3 viewDelta, float skyLight) {
   float dist = length(viewDelta);
   float depthK = max(abs(float(WATER_FOG_EXPONENT)), 0.35) * WATER_FOG_DENSITY;

   vec3 sigmaA = vec3(0.058, 0.017, 0.0085) * depthK;
   vec3 transmittance = exp(-sigmaA * dist);
   colorMult *= transmittance;

   float scatterSigma = 0.011 * depthK;
   float fog = 1.0 - exp(-scatterSigma * dist);
   fog = clamp(fog, 0.0, 1.0);

   vec3 waterFogColor = getUnderwaterFogColor(skyLight);
   waterFogColor *= mix(1.0, 0.58, fog * fog);

   return vec4(waterFogColor, fog);
}

vec3 applyUnderwaterFog(vec3 color, vec3 viewPos, float skyLight) {
   vec3 colorMult = vec3(1.0);
   vec4 waterFog = getWaterFog(colorMult, viewPos, skyLight);

   float nearFilm = 1.0 - exp(-length(viewPos) * 0.048);
   waterFog.a = max(waterFog.a, nearFilm * 0.12);

   color *= colorMult;
   color = mix(color, waterFog.rgb, waterFog.a * waterFog.a);
   return color;
}

#endif
