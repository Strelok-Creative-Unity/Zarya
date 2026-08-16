#ifndef DH_LIGHTMAP_GLSL
#define DH_LIGHTMAP_GLSL

#ifndef FOG_COLOR_UNIFORM
#define FOG_COLOR_UNIFORM
uniform vec3 fogColor;
#endif

#ifndef RAIN_STRENGTH_UNIFORM
#define RAIN_STRENGTH_UNIFORM
uniform float rainStrength;
#endif

#if defined VERTEX || defined GET_DH_LIGHTMAP_UV
vec2 getDhLightMapUV() {
   vec2 raw1 = gl_MultiTexCoord1.xy;
   vec2 raw2 = gl_MultiTexCoord2.xy;
   vec2 raw  = (raw2.x + raw2.y > raw1.x + raw1.y) ? raw2 : raw1;

   float peak = max(raw.x, raw.y);
   vec2 lm;
   if (peak > 1.5) {
      lm = raw * ((peak > 32.0) ? (1.0 / 240.0) : (1.0 / 16.0));
   } else {
      lm = raw;
   }

   lm = clamp(lm, 0.0, 1.0);

   if (lm.x + lm.y < 1.0e-4) {
      lm = AMBIENT_UV;
   }

   return lm;
}
#endif

vec4 getDhAmbientColor(float skyLight, float sunHeight) {
   float sky = clamp(rescale(skyLight, AMBIENT_UV.s, AMBIENT_UV.t), 0.0, 1.0);
   float brightness = sky / max(4.0 - 3.0 * sky, 0.001);
   float dayAmt = smoothstep(-0.02, 0.12, sunHeight);

   vec3 night = vec3(0.20, 0.21, 0.28);
   vec3 day   = vec3(0.99, 0.98, 0.93);

   #ifndef ENABLE_SHADOWS
      night = vec3(0.24, 0.25, 0.31);
      day   = vec3(0.96, 0.96, 0.92);
   #endif

   vec4 ambient = vec4(mix(night, day, dayAmt) * mix(0.16, 1.0, brightness), 1.0);

   #ifdef THE_NETHER
      vec3 biome = max(fogColor, vec3(0.02));
      vec3 netherAmb = mix(vec3(0.42, 0.28, 0.24), biome, 0.12);
      ambient.rgb = netherAmb * NETHER_AMBIENT;
   #elif defined THE_END
      ambient.rgb = vec3(0.28, 0.24, 0.32);
   #else
      float sunset = exp(-sunHeight * sunHeight * 22.0) * smoothstep(-0.32, 0.08, sunHeight);
      ambient.rgb *= mix(vec3(1.0), vec3(1.06, 0.84, 0.64), clamp(sunset * 0.50, 0.0, 1.0));
      float twilight = exp(-pow(sunHeight + 0.06, 2.0) * 40.0) * smoothstep(-0.35, -0.02, sunHeight);
      ambient.rgb = mix(ambient.rgb, ambient.rgb * vec3(0.90, 0.76, 0.86), twilight * 0.38);

      float rain = clamp(rainStrength, 0.0, 1.0);
      ambient.rgb *= mix(1.0, 0.62, rain);
      float rainY = luma(ambient.rgb);
      ambient.rgb = mix(vec3(rainY), ambient.rgb, mix(1.0, 0.78, rain));
   #endif

   return ambient;
}

float terrainRainLuma(vec3 c) {
   return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 applyTerrainRainGrade(vec3 rgb, float rain, vec3 rainFog, float weight) {
   float r = clamp(rain * weight, 0.0, 1.0);
   if (r <= 0.0) {
      return rgb;
   }

   rgb *= mix(1.0, 0.72, r);
   float y = terrainRainLuma(rgb);
   rgb = mix(vec3(y), rgb, mix(1.0, 0.60, r));
   rgb = mix(rgb, rainFog * (0.80 + 0.20 * y), r * 0.28);
   return rgb;
}

vec3 applyTerrainAtmosphereGrade(vec3 rgb, vec3 feetPos, vec3 atmosFog, float weight, float farPlane) {
   float dist = mix(length(feetPos), length(feetPos.xz), 0.38);
   float start = farPlane * 0.38;
   float end = farPlane * 1.06;
   float t = smoothstep(start, end, dist) * clamp(weight, 0.0, 1.0);
   if (t <= 0.0) {
      return rgb;
   }

   float y = terrainRainLuma(rgb);
   return mix(rgb, atmosFog * (0.74 + 0.26 * y), t * 0.34);
}

#endif
