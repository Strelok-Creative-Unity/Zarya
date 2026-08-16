#ifndef TONEMAP_GLSL
#define TONEMAP_GLSL

float standIllumination(vec2 eyeBright01, float sunUp, float rain) {
   float blockL = eyeBright01.x;
   float skyL   = eyeBright01.y;

   float dayFactor = smoothstep(-0.12, 0.28, sunUp);
   dayFactor *= mix(1.0, 0.55, rain);
   float skyIllum = skyL * mix(0.06, 1.0, dayFactor);

   return clamp(max(skyIllum, blockL), 0.0, 1.0);
}

vec2 autoExposure(float standIllum, float prevEv, float dt) {
   float target = mix(2.80, 0.72, pow(standIllum, 0.85));
   target = clamp(target, 0.55, 3.20);

   float prev = prevEv;
   if (prev != prev || prev < 0.15 || prev > 10.0) {
      prev = target;
   }

   dt = max(dt, 1.0 / 60.0);

   float speedScale = max(AUTO_EXPOSURE_SPEED, 0.2);
   float rate = target < prev
      ? 0.12 * speedScale
      : 0.065 * speedScale;

   float blendWeight = exp(-rate * dt);
   float ev = mix(target, prev, blendWeight);

   float maxDeltaPerSec = 0.18 * speedScale;
   float maxStep = maxDeltaPerSec * dt;
   ev = clamp(ev, prev - maxStep, prev + maxStep);

   ev = mix(1.0, ev, AUTO_EXPOSURE_STRENGTH);
   float tgt = mix(1.0, target, AUTO_EXPOSURE_STRENGTH);
   return vec2(ev, tgt);
}

vec3 applyLightBleed(vec3 ldrColor, float exposureEv, float targetEv) {
   float mismatch = max(0.0, exposureEv / max(targetEv, 0.25) - 1.0);
   float darkAdapted = smoothstep(1.8, 2.8, exposureEv);
   float bleach = smoothstep(0.5, 2.0, mismatch) * darkAdapted * 0.45;
   bleach *= AUTO_EXPOSURE_STRENGTH;

   float grey = luma(ldrColor);
   vec3 washed = mix(ldrColor, vec3(grey), bleach * 0.45);
   washed = mix(washed, vec3(1.0), bleach * 0.40);
   return clamp(washed, 0.0, 1.08);
}

#endif
