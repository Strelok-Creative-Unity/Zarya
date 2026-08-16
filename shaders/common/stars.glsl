#ifndef RF_STARS_GLSL
#define RF_STARS_GLSL

#ifndef RF_MATH_GLSL
   #include "/common/math.glsl"
#endif

#ifndef FRAME_TIME_COUNTER_UNIFORM
#define FRAME_TIME_COUNTER_UNIFORM
uniform float frameTimeCounter;
#endif

#ifndef STAR_BRIGHTNESS
   #define STAR_BRIGHTNESS 1.85
#endif
#ifndef STAR_AMOUNT
   #define STAR_AMOUNT 1.0
#endif
#ifndef STAR_SIZE
   #define STAR_SIZE 1.5
#endif
#ifndef STAR_PERIOD
   #define STAR_PERIOD 120.0
#endif
#ifndef STAR_SPEED
   #define STAR_SPEED 1.0
#endif
#ifndef STAR_PHASE
   #define STAR_PHASE 0.0
#endif

// MIT ref: David Hoskins — Hash without Sine (hash22)
// Source: https://www.shadertoy.com/view/4djSRW
// License text: THIRD_PARTY_NOTICES.md
vec2 starHash22(vec2 p) {
   vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
   q += dot(q, q.yzx + 33.33);
   return fract((q.xx + q.yz) * q.zy);
}

// MIT ref: David Hoskins — Hash without Sine (hash22); .x wrapper only
// Source: https://www.shadertoy.com/view/4djSRW
// License text: THIRD_PARTY_NOTICES.md
float starHash21(vec2 p) {
   return starHash22(p).x;
}

vec3 starLayer(vec2 uv, float density, float radius, float wrap, float u, float twinkleTurns) {
   vec2 cell0 = floor(uv);
   vec2 f0 = fract(uv);
   vec3 col = vec3(0.0);

   for (int oy = -1; oy <= 1; oy++) {
      for (int ox = -1; ox <= 1; ox++) {
         vec2 cell = cell0 + vec2(float(ox), float(oy));
         cell.x -= wrap * floor(cell.x / wrap);
         vec2 seed = starHash22(cell + vec2(3.17, 8.99));
         if (seed.x > density) {
            continue;
         }

         vec2 j = starHash22(cell + vec2(12.41, 0.73));
         vec2 starPos = j + vec2(float(ox), float(oy));
         float d = length(f0 - starPos);

         float rVar = starHash21(cell + vec2(21.7, 4.3));
         float r = max(radius * mix(0.35, 1.20, rVar), 1.0e-4);
         float disc = pow(clamp(1.0 - d / r, 0.0, 1.0), 5.0);
         disc += exp(-d * d / (r * r * 0.10)) * 0.55;
         if (disc < 1.0e-4) {
            continue;
         }

         float hue = starHash21(cell + vec2(5.8, 2.2));
         vec3 tint = mix(vec3(0.78, 0.88, 1.0), vec3(1.0, 0.90, 0.74), hue);
         float mag = 0.25 + 1.55 * pow(starHash21(cell + vec2(9.2, 14.6)), 2.2);
         float tw = 0.82 + 0.18 * sin(TAU * twinkleTurns * u + seed.y * TAU);
         col += tint * disc * mag * tw;
      }
   }

   return col;
}

vec3 getOverworldStars(vec3 viewDir) {
   vec3 dir = normalize(viewDir);
   vec3 up = gbufferModelView[1].xyz;
   float VoU = dot(dir, up);
   if (VoU < -0.02) {
      return vec3(0.0);
   }

   float sunVis = getSunVisibility();
   float night = smoothstep(0.55, 0.02, sunVis);
   float vis = night * (1.0 - rainStrength) * smoothstep(-0.02, 0.15, VoU);
   if (vis < 0.02) {
      return vec3(0.0);
   }

   float period = max(float(STAR_PERIOD), 1.0);
   float u = fract(frameTimeCounter / period + STAR_PHASE);
   float cycles = float(STAR_SPEED) <= 1.0e-5
      ? 0.0
      : max(floor(float(STAR_SPEED) * 2.0 + 0.5), 1.0);

   vec3 worldDir = mat3(gbufferModelViewInverse) * dir;
   vec2 plane = worldDir.xz / (abs(worldDir.y) + 1.0);

   float amount = clamp(float(STAR_AMOUNT), 0.35, 2.5);
   float size = max(float(STAR_SIZE), 0.25);
   float twinkleTurns = 12.0;
   float dens = clamp(amount * 0.55, 0.25, 1.4);
   const float wrap = 256.0;
   float slide = wrap * cycles * u;

   vec3 stars = starLayer(plane * (97.0 * amount) + vec2(slide, 0.0), 0.11 * dens, 0.145 * size, wrap, u, twinkleTurns);

   return stars * vis * STAR_BRIGHTNESS * 2.4;
}

#endif
