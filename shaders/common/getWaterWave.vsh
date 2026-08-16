#ifndef WATER_WAVE_PERIOD
   #define WATER_WAVE_PERIOD 120.0
#endif

vec3 getWaterWave(float random, vec3 feetPos) {
   float dist = max(length(feetPos.xz), 1.0);
   float distAmt = mix(1.0, 0.40, smoothstep(16.0, 180.0, dist));
   float v = distAmt * 0.12 * max(float(WATER_WAVE_SIZE), 1.0);

   float period = max(float(WATER_WAVE_PERIOD), 1.0);
   float u = fract(frameTimeCounter / period);
   float a = TAU * max(float(WATER_WAVE_SPEED), 1.0) * u + random;
   return v * vec3(
      pow3(sin(a)),
      0.0,
      pow3(cos(a * 2.0 + random))
   );
}
