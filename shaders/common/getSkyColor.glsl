#ifndef GET_SKY_COLOR
#define GET_SKY_COLOR

#ifndef RAIN_STRENGTH_UNIFORM
#define RAIN_STRENGTH_UNIFORM
uniform float rainStrength;
#endif

#ifndef FOG_COLOR_UNIFORM
#define FOG_COLOR_UNIFORM
uniform vec3 fogColor;
#endif

#ifndef SKY_COLOR_UNIFORM
#define SKY_COLOR_UNIFORM
uniform vec3 skyColor;
#endif

#ifndef SUN_POSITION_UNIFORM
#define SUN_POSITION_UNIFORM
uniform vec3 sunPosition;
#endif

#ifndef MOON_POSITION_UNIFORM
#define MOON_POSITION_UNIFORM
uniform vec3 moonPosition;
#endif

float getSunUpFactor() {
   return dot(normalize(sunPosition), gbufferModelView[1].xyz);
}

float getSunVisibilityFrom(float sunUp) {
   return clamp((sunUp + 0.1) * 4.0, 0.0, 1.0);
}

float getSunsetFactorFrom(float sunUp) {
   float nearHorizon = exp(-sunUp * sunUp * 22.0);
   float stillLit = smoothstep(-0.32, 0.02, sunUp);
   return nearHorizon * stillLit;
}

float getTwilightFactorFrom(float sunUp) {
   return exp(-pow(sunUp + 0.06, 2.0) * 40.0) * smoothstep(-0.35, -0.02, sunUp);
}

float getSunVisibility() {
   return getSunVisibilityFrom(getSunUpFactor());
}

float getSunsetFactor() {
   return getSunsetFactorFrom(getSunUpFactor());
}

float getTwilightFactor() {
   return getTwilightFactorFrom(getSunUpFactor());
}

vec3 saturateSkyColor(vec3 c, float amount) {
   return mix(vec3(luma(c)), c, amount);
}

#if defined SHADER_STARS && defined OVERWORLD
   #ifndef TRANSFORMATIONS_GLSL
      #include "/common/transformations.glsl"
   #endif
   #include "/common/stars.glsl"
#endif

vec3 getHorizonFogColor() {
   float sunUp = getSunUpFactor();
   float sunVis = getSunVisibilityFrom(sunUp);
   float sunset = getSunsetFactorFrom(sunUp) * SUNSET_INTENSITY;
   float twilight = getTwilightFactorFrom(sunUp);

   vec3 dayFog = mix(max(fogColor, vec3(0.001)), max(skyColor, vec3(0.001)), 0.35);
   dayFog = saturateSkyColor(dayFog, 1.22) * 0.92;

   vec3 sunsetFog = vec3(1.08, 0.36, 0.12);
   vec3 twilightFog = vec3(0.48, 0.18, 0.34);
   vec3 nightFog = vec3(0.014, 0.024, 0.055);

   vec3 fog = mix(dayFog, sunsetFog, clamp(sunset * 0.95, 0.0, 1.0));
   fog = mix(fog, twilightFog, twilight * 0.55);
   fog = mix(nightFog, fog, sunVis);
   fog = mix(fog, mix(fogColor, vec3(luma(fogColor)), 0.25), rainStrength);

   return fog;
}

vec3 getSkyColorNoStars(vec3 viewDir) {
   vec3 dir = normalize(viewDir);
   vec3 up = gbufferModelView[1].xyz;
   vec3 sunDir = normalize(sunPosition);
   vec3 moonDir = normalize(moonPosition);

   float upDot = dot(dir, up);
   float VoS = dot(dir, sunDir);
   float VoM = dot(dir, moonDir);
   float VoS01 = VoS * 0.5 + 0.5;
   float VoSPos = max(VoS, 0.0);
   float VoS2 = VoSPos * VoSPos;

   float sunUp = getSunUpFactor();
   float sunVis = getSunVisibilityFrom(sunUp);
   float sunVis2 = sunVis * sunVis;
   float sunset = getSunsetFactorFrom(sunUp) * SUNSET_INTENSITY;
   float twilight = getTwilightFactorFrom(sunUp);
   float rain = rainStrength;

   float height = clamp(upDot, 0.0, 1.0);
   float invHeight = 1.0 - height;

   vec3 skySafe = max(skyColor, vec3(0.07, 0.10, 0.20));
   vec3 zenith = pow(skySafe, vec3(1.48)) * vec3(0.32, 0.50, 1.16);
   vec3 middle = pow(skySafe, vec3(0.92)) * vec3(0.74, 0.86, 1.16);
   vec3 horizon = mix(max(fogColor, skySafe * 0.75), skySafe, 0.38) * vec3(1.02, 0.96, 0.88);

   vec3 sunsetHorizon = vec3(1.18, 0.32, 0.08);
   vec3 sunsetMid     = vec3(1.08, 0.42, 0.22);
   vec3 sunsetZenith  = vec3(0.22, 0.12, 0.46);
   vec3 sunsetPink    = vec3(1.02, 0.26, 0.40);

   zenith  = mix(zenith,  sunsetZenith,  sunset * 0.85 + twilight * 0.7);
   middle  = mix(middle,  sunsetMid,     sunset * 0.9);
   horizon = mix(horizon, sunsetHorizon, sunset);

   float zenithMix = pow(invHeight * invHeight, 1.0 - VoS2 * 0.35);
   vec3 sky = mix(zenith, middle, zenithMix);

   float band = pow(1.0 - abs(upDot), 2.8);
   band = band * band * (3.0 - 2.0 * band);
   sky = mix(sky, horizon, band * (0.45 + sunset * 0.55));
   sky = mix(sky, sunsetPink, pow(max(-VoS, 0.0), 2.0) * band * sunset * 0.35);

   float wash = band * sunset * mix(0.35, 0.95, VoS01);
   wash *= (1.0 - rain * 0.55);
   vec3 warmWash = mix(sunsetMid, sunsetHorizon, VoS2);
   warmWash = mix(warmWash, sunsetPink, pow(max(-VoS, 0.0), 1.6) * 0.4);
   sky = mix(sky, warmWash, clamp(wash, 0.0, 0.85));

   float coolRing = smoothstep(0.22, 0.02, abs(upDot - 0.05)) * twilight;
   coolRing *= (1.0 - VoSPos) * (1.0 - rain);
   sky += vec3(0.04, 0.10, 0.18) * coolRing * 0.35;

   float mie = mix(henyeyGreenstein(VoS, 0.82), henyeyGreenstein(VoS, 0.42), mix(0.2, 0.55, sunset));
   vec3 mieColor = mix(vec3(1.0, 0.92, 0.78), sunsetHorizon, sunset);
   mieColor = mix(mieColor, vec3(1.0, 0.55, 0.22), sunset * VoS2);
   sky += mieColor * mie * mix(0.012, 0.055, sunset) * sunVis * (1.0 - rain);

   #ifndef VANILLA_LIKE_SUN
      float sunCos = clamp(VoS, -1.0, 1.0);
      float sunAng2 = 2.0 - 2.0 * sunCos;
      float sunRad = mix(0.028, 0.038, sunset);
      float sunCore = 1.0 - smoothstep(sunRad * 0.40, sunRad, sqrt(max(sunAng2, 0.0)));
      float sunGlow = exp(-sunAng2 / (mix(0.07, 0.20, sunset) * mix(0.07, 0.20, sunset)));
      vec3 sunCol = mix(vec3(1.18, 1.08, 0.92), sunsetHorizon, sunset * 0.88);
      sky += sunCol * (sunCore * mix(1.6, 2.2, sunset) + sunGlow * mix(0.22, 0.80, sunset))
           * sunVis2 * (1.0 - rain);
   #endif

   vec3 night = mix(vec3(0.005, 0.010, 0.032), vec3(0.014, 0.022, 0.052), pow(invHeight, 1.5));
   #ifndef VANILLA_LIKE_MOON
      float moonCos = clamp(VoM, -1.0, 1.0);
      float moonAng2 = 2.0 - 2.0 * moonCos;
      float moonCore = 1.0 - smoothstep(0.022, 0.034, sqrt(max(moonAng2, 0.0)));
      float moonGlow = exp(-moonAng2 / 0.0121);
      night += MOON_COLOR * (
         henyeyGreenstein(VoM, 0.72) * 0.035
         + moonCore * 0.72
         + moonGlow * 0.20
      );
   #else
      night += MOON_COLOR * henyeyGreenstein(VoM, 0.72) * 0.022;
   #endif
   sky = mix(night, sky, sunVis2);

   sky *= mix(0.22, 1.0, smoothstep(-0.15, 0.04, upDot));

   vec3 rainSky = mix(fogColor, vec3(luma(fogColor)), 0.22);
   rainSky *= 0.38 + 0.36 * invHeight;
   sky = mix(sky, rainSky, rain);
   sky = saturateSkyColor(sky, 1.16 + sunset * 0.28);

   return sky;
}

vec3 getSkyColor(vec3 viewDir) {
   vec3 sky = getSkyColorNoStars(viewDir);
   #if defined SHADER_STARS && defined OVERWORLD
      sky += getOverworldStars(viewDir);
   #endif
   return sky;
}

vec3 getSunMoonGlint(vec3 viewPos, vec3 normal, float roughness, float reflectivity) {
   vec3 V = normalize(viewPos);
   vec3 N = normalize(normal);
   vec3 R = reflect(V, N);

   float nv = 1.0 - max(dot(N, -V), 0.0);
   float fresnel = mix(0.14, 1.0, nv * nv * nv * nv * nv);
   float smoothF = 1.0 - clamp(roughness * 3.5, 0.0, 1.0);
   float sunUp = getSunUpFactor();
   float sunVis = getSunVisibilityFrom(sunUp);
   float sunset = clamp(getSunsetFactorFrom(sunUp) * SUNSET_INTENSITY, 0.0, 1.0);

   vec3 sunDir = normalize(sunPosition);
   float sunDot = max(dot(R, sunDir), 0.0);
   vec3 sunCol = mix(vec3(1.0, 0.97, 0.88), vec3(1.0, 0.42, 0.12), sunset);
   vec3 sunGlint = sunCol * (
      pow(sunDot, mix(40.0, 340.0, smoothF)) * mix(1.35, 2.15, sunset)
      + pow(sunDot, mix(7.0, 16.0, sunset)) * mix(0.1, 0.65, sunset)
   ) * sunVis;

   vec3 moonDir = normalize(moonPosition);
   float moonDot = max(dot(R, moonDir), 0.0);
   vec3 moonGlint = MOON_COLOR * (
      pow(moonDot, mix(32.0, 220.0, smoothF)) * 0.70
      + pow(moonDot, 9.0) * 0.10
   ) * (1.0 - sunVis);

   float waterish = smoothstep(GLASS_REFLECTIVITY, WATER_REFLECTIVITY, reflectivity);
   float strength = mix(0.4, 1.0, waterish) * SUN_MOON_GLINT;
   strength *= fresnel * clamp(reflectivity, 0.0, 1.0);
   strength *= 1.0 - rainStrength * 0.8;

   return (sunGlint + moonGlint) * strength;
}

#endif
