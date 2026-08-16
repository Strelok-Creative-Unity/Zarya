#ifndef GET_WATER_SURFACE_GLSL
#define GET_WATER_SURFACE_GLSL


#ifndef WATER_WAVE_PERIOD
   #define WATER_WAVE_PERIOD 120.0
#endif
#ifndef WATER_WAVE_DIR
   #define WATER_WAVE_DIR 30
#endif

#ifndef NOISETEX_UNIFORM
#define NOISETEX_UNIFORM
uniform sampler2D noisetex;
#endif

float waterLoopU() {
   return fract(frameTimeCounter / max(float(WATER_WAVE_PERIOD), 1.0));
}

float waterFlowAngle() {
   return float(WATER_WAVE_DIR) * (PI / 180.0);
}

vec2 waterFlowDir() {
   float a = waterFlowAngle();
   return vec2(cos(a), sin(a));
}

void accumLoopWave(vec2 xz, float u, float angle, float cycles, float freq, float amp,
                   inout float h, inout vec2 g, inout float lap, float warp) {
   vec2 dir = vec2(cos(angle), sin(angle));
   float phase = dot(xz, dir) * freq + TAU * cycles * u + warp;
   float s = sin(phase);
   float c = cos(phase);
   h += amp * (0.5 - 0.5 * c);
   g += dir * (amp * 0.5 * freq * s);
   lap += amp * 0.5 * freq * freq * c;
}

float waterNoiseSample(vec2 xz, float u, float scale, float tiles) {
   return texture2D(noisetex, xz * scale + vec2(tiles * u, 0.0)).g;
}

float waterPatch(vec2 xz) {
   float a = texture2D(noisetex, xz * 0.0028 + vec2(0.17, 0.03)).g;
   float b = texture2D(noisetex, xz * 0.0069 + vec2(0.41, 0.62)).r;
   return clamp(a * 0.62 + b * 0.38, 0.0, 1.0);
}

float waterWarp(vec2 xz, vec2 shift, float scale) {
   return (texture2D(noisetex, xz * scale + shift).g - 0.5) * 2.2;
}

void sampleWaterSwell(vec3 worldPos, out float height, out vec2 grad, out float laplace) {
   float u = waterLoopU();
   float speed = max(float(WATER_WAVE_SPEED), 1.0);
   vec2 xz = worldPos.xz;
   float base = waterFlowAngle();
   float patch = waterPatch(xz);
   float live = mix(0.42, 1.18, patch);

   height = 0.0;
   grad = vec2(0.0);
   laplace = 0.0;

   float w0 = waterWarp(xz, vec2(0.11, 0.07), 0.014);
   float w1 = waterWarp(xz, vec2(0.52, 0.28), 0.027);
   float w2 = waterWarp(xz, vec2(0.08, 0.71), 0.041);
   accumLoopWave(xz, u, base + 0.00, 1.0 * speed, TAU / 13.7, 1.00, height, grad, laplace, w0);
   accumLoopWave(xz, u, base + 0.93, 2.0 * speed, TAU /  7.4, 0.46, height, grad, laplace, w1);
   accumLoopWave(xz, u, base - 1.21, 3.0 * speed, TAU /  4.2, 0.24, height, grad, laplace, w2);

   float ampSum = 1.70;
   height = height / ampSum * live;
   grad = grad / ampSum * live;
   laplace = laplace / ampSum * live;
}

void sampleWaterField(vec3 worldPos, out float height, out vec2 grad, out float laplace) {
   float u = waterLoopU();
   float speed = max(float(WATER_WAVE_SPEED), 1.0);
   vec2 xz = worldPos.xz;
   float base = waterFlowAngle();
   float patch = waterPatch(xz);
   float live = mix(0.36, 1.28, patch * patch * (3.0 - 2.0 * patch));

   height = 0.0;
   grad = vec2(0.0);
   laplace = 0.0;

   float w0 = waterWarp(xz, vec2(0.09, 0.14), 0.012);
   float w1 = waterWarp(xz, vec2(0.61, 0.22), 0.023);
   float w2 = waterWarp(xz, vec2(0.17, 0.58), 0.037);
   float w3 = waterWarp(xz, vec2(0.44, 0.81), 0.055);
   float w4 = waterWarp(xz, vec2(0.73, 0.06), 0.079);
   accumLoopWave(xz, u, base + 0.00, 1.0 * speed, TAU / 12.5, 1.00, height, grad, laplace, w0);
   accumLoopWave(xz, u, base + 0.91, 2.0 * speed, TAU /  7.2, 0.45, height, grad, laplace, w1);
   accumLoopWave(xz, u, base - 1.18, 3.0 * speed, TAU /  4.15, 0.24, height, grad, laplace, w2);
   accumLoopWave(xz, u, base + 1.87, 5.0 * speed, TAU /  2.38, 0.12, height, grad, laplace, w3);
   accumLoopWave(xz, u, base - 0.62, 7.0 * speed, TAU /  1.37, 0.06, height, grad, laplace, w4);

   vec2 flow = waterFlowDir();
   vec2 perp = vec2(-flow.y, flow.x);
   float eps = 0.42;
   float n0 = waterNoiseSample(xz, u, 0.038, 4.0 * speed);
   float nF = waterNoiseSample(xz + flow * eps, u, 0.038, 4.0 * speed);
   float nP = waterNoiseSample(xz + perp * eps, u, 0.038, 4.0 * speed);
   float nFine = waterNoiseSample(xz, u, 0.086, 7.0 * speed);
   float microAmp = mix(0.05, 0.13, patch);
   height += ((n0 + nFine) * 0.5 - 0.5) * microAmp;
   grad += flow * ((nF - n0) / eps) * microAmp;
   grad += perp * ((nP - n0) / eps) * microAmp;
   laplace += ((n0 + nFine) * 0.5 - 0.5) * microAmp * 6.0;

   float ampSum = 1.87;
   height = height / ampSum * live;
   grad = grad / ampSum * live;
   laplace = laplace / ampSum * live;
}

vec3 getWaterRippleNormalFromGrad(vec3 worldPos, vec3 geoNormal, vec2 g) {
   #if WATER_WAVE_SIZE <= 0
      return geoNormal;
   #endif

   if (abs(geoNormal.y) < 0.35) {
      return geoNormal;
   }

   float upSign = geoNormal.y >= 0.0 ? 1.0 : -1.0;
   vec3 flatN = abs(geoNormal.y) > 0.70
      ? vec3(0.0, upSign, 0.0)
      : geoNormal;

   float bump = 0.38 * (0.40 + 0.60 * float(WATER_WAVE_SIZE));
   #ifdef RAIN_STRENGTH_UNIFORM
      bump *= 1.0 + rainStrength * 0.70;
   #endif

   vec3 toPos = worldPos - cameraPosition;
   float dist = length(toPos);
   float facing = abs(dot(flatN, toPos / max(dist, 1.0e-4)));
   bump *= smoothstep(0.04, 0.22, facing);

   vec3 n = normalize(vec3(-g.x * bump, upSign, -g.y * bump));
   n.y = upSign > 0.0 ? max(n.y, 0.78) : min(n.y, -0.78);
   n = normalize(n);

   vec3 I = toPos / max(dist, 1.0e-4);
   vec3 R = reflect(I, n);
   float into = 1.0 - smoothstep(0.02, 0.20, dot(R, flatN));
   n = normalize(mix(n, flatN, into));
   return n;
}

vec3 getWaterRippleNormal(vec3 worldPos, vec3 geoNormal) {
   #if WATER_WAVE_SIZE <= 0
      return geoNormal;
   #endif
   float h;
   vec2 g;
   float lap;
   sampleWaterField(worldPos, h, g, lap);
   return getWaterRippleNormalFromGrad(worldPos, geoNormal, g);
}

vec3 getWaterUndersideNormal(vec3 worldPos, vec3 geoNormal) {
   #if WATER_WAVE_SIZE <= 0
      return geoNormal;
   #endif

   if (abs(geoNormal.y) < 0.35) {
      return geoNormal;
   }

   float upSign = geoNormal.y >= 0.0 ? 1.0 : -1.0;
   vec3 flatN = abs(geoNormal.y) > 0.70
      ? vec3(0.0, upSign, 0.0)
      : geoNormal;

   float h;
   vec2 g;
   float lap;
   sampleWaterSwell(worldPos, h, g, lap);

   float bump = 0.16 * (0.45 + 0.55 * float(WATER_WAVE_SIZE));
   vec3 n = normalize(vec3(-g.x * bump, upSign, -g.y * bump));
   n.y = upSign > 0.0 ? max(n.y, 0.88) : min(n.y, -0.88);
   return normalize(mix(flatN, n, 0.85));
}

float getWaterSoftFilm(vec3 worldPos) {
   float u = waterLoopU();
   float speed = max(float(WATER_WAVE_SPEED), 1.0);
   float base = waterFlowAngle();
   vec2 xz = worldPos.xz;
   float p0 = dot(xz, vec2(cos(base), sin(base))) * (TAU / 18.0) + TAU * 1.0 * speed * u;
   float p1 = dot(xz, vec2(cos(base + 1.1), sin(base + 1.1))) * (TAU / 11.0) + TAU * 2.0 * speed * u;
   return clamp(0.5 + 0.32 * sin(p0) + 0.18 * sin(p1), 0.0, 1.0);
}

float getWaterCausticsFromField(vec3 worldPos, float lap) {
   #if WATER_WAVE_SIZE <= 0
      return 0.32;
   #endif

   float focus = max(-lap, 0.0);

   float u = waterLoopU();
   float speed = max(float(WATER_WAVE_SPEED), 1.0);
   float noise = waterNoiseSample(worldPos.xz, u, 0.07, 5.0 * speed);
   float glitter = pow(max(noise * 1.8 - 0.65, 0.0), 1.6);

   return clamp(focus * 5.5 + glitter * 1.05, 0.0, 1.6);
}

float getWaterCaustics(vec3 worldPos) {
   float h;
   vec2 g;
   float lap;
   sampleWaterField(worldPos, h, g, lap);
   return getWaterCausticsFromField(worldPos, lap);
}

float getSnellWindowAmount(float NoV) {
   return smoothstep(0.18, 0.95, NoV);
}

float getSnellWindow(vec3 feetPos, bool eyeInWater) {
   if (!eyeInWater) {
      return 1.0;
   }

   float horiz = length(feetPos.xz);
   float window = pow(clamp(horiz * 0.05, 0.0, 1.0), 4.0);
   return clamp(window, 0.05, 1.0);
}

vec3 applyWaterNoiseColor(vec3 albedo, vec3 worldPos, float cau) {
   float u = waterLoopU();
   float speed = max(float(WATER_WAVE_SPEED), 1.0);
   vec2 xz = worldPos.xz;

   float tex = waterNoiseSample(xz, u, 0.042, 3.0 * speed);
   float tex2 = waterNoiseSample(xz, u, 0.11, 6.0 * speed);
   float patch = waterPatch(xz);
   float wobble = ((tex - 0.5) * 1.20 + (tex2 - 0.5) * 0.50) * mix(0.10, 0.22, patch);

   float sparkle = pow(max(cau - 0.35, 0.0), 1.4) * 0.28;

   albedo = albedo * (1.0 + wobble) + albedo.brg * wobble * 0.08;
   albedo += albedo * sparkle;
   return albedo;
}

float getWaterSheetAlpha(float thicknessFog, float fresnel) {
   float beer = mix(0.11, 0.46, thicknessFog);
   float rim = fresnel * fresnel * (3.0 - 2.0 * fresnel);
   return mix(beer, 0.70, rim * 0.52) * WATER_A;
}

#endif
