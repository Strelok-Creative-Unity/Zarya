#ifndef NETHER_FOG_GLSL
#define NETHER_FOG_GLSL

#if defined NETHER_FOG && defined THE_NETHER

#ifndef NETHER_FOG_STRENGTH
   #define NETHER_FOG_STRENGTH 1.0
#endif
#ifndef NETHER_FOG_DENSITY
   #define NETHER_FOG_DENSITY 1.15
#endif
#ifndef NETHER_FOG_GLOW
   #define NETHER_FOG_GLOW 0.45
#endif
#ifndef NETHER_FOG_SAMPLES
   #define NETHER_FOG_SAMPLES 12
#endif
#ifndef NETHER_BLOOM
   #define NETHER_BLOOM 0.35
#endif

#ifndef FOG_COLOR_UNIFORM
#define FOG_COLOR_UNIFORM
uniform vec3 fogColor;
#endif

#ifdef NETHER_FOG_EMBERS
   #ifndef NOISETEX_UNIFORM
   #define NOISETEX_UNIFORM
   uniform sampler2D noisetex;
   #endif
   #ifndef FRAME_TIME_COUNTER_UNIFORM
   #define FRAME_TIME_COUNTER_UNIFORM
   uniform float frameTimeCounter;
   #endif
#endif

float netherFogFar() {
   #ifdef DISTANT_HORIZONS
      return max(far, max(dhFarPlane, float(dhRenderDistance)));
   #else
      return far;
   #endif
}

// MIT ref: David Hoskins — Hash without Sine (hash12)
// Source: https://www.shadertoy.com/view/4djSRW
// License text: THIRD_PARTY_NOTICES.md
float netherFogDither(vec2 p) {
   vec3 m = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
   m += dot(m, m.yzx + 33.33);
   return fract((m.x + m.y) * m.z);
}

vec3 netherFogAtmosColor() {
   vec3 biome = max(fogColor, vec3(0.001));
   float biomeL = max(luma(biome), 0.04);
   vec3 hue = biome / biomeL;
   hue = mix(vec3(1.0), hue, 0.78);
   float warm = clamp((hue.r - hue.b) * 1.6, 0.0, 1.0);
   vec3 murk = mix(hue, vec3(0.52, 0.16, 0.07), warm * 0.22);
   return murk * 0.13;
}

float netherFogDensity(vec3 worldPos, float camDist) {
   float y = worldPos.y;
   float floorHaze = exp(-max(y - 32.0, 0.0) / 56.0);
   float dens = mix(0.88, 1.12, floorHaze * 0.70);
   dens *= mix(0.82, 1.0, smoothstep(0.0, 14.0, camDist));

   #ifdef NETHER_FOG_EMBERS
      vec2 drift = vec2(0.09, -0.06) * frameTimeCounter * 0.00016;
      float n0 = texture2D(noisetex, worldPos.xz * 0.00026 + drift).r;
      dens *= 0.93 + 0.12 * n0;
   #endif

   return dens * NETHER_FOG_STRENGTH;
}

void computeNetherFog(vec3 viewPos, bool sky, out vec3 scattering, out vec3 transmittance) {
   scattering = vec3(0.0);
   transmittance = vec3(1.0);

   float fogEnd = netherFogFar();
   vec3 worldStart = cameraPosition;
   vec3 worldEnd = feet2world(view2feet(viewPos));
   vec3 worldDelta = worldEnd - worldStart;
   float rayLen = length(worldDelta);
   if (rayLen < 1e-3 && !sky) {
      return;
   }

   vec3 worldDir = (sky || rayLen < 1e-3)
      ? normalize(view2eye(viewPos))
      : worldDelta / rayLen;
   if (sky) {
      rayLen = fogEnd;
   } else {
      rayLen = min(rayLen, fogEnd);
   }

   float dither = netherFogDither(gl_FragCoord.xy);
   float stepLen = rayLen / float(NETHER_FOG_SAMPLES);
   vec3 atmos = netherFogAtmosColor();
   float sigma = 0.0124 * NETHER_FOG_DENSITY;
   vec3 extScale = vec3(0.90, 1.06, 1.22);

   vec3 T = vec3(1.0);
   vec3 scatter = vec3(0.0);

   for (int i = 0; i < NETHER_FOG_SAMPLES; i++) {
      float t = (float(i) + 0.5 + (dither - 0.5) * 0.08) * stepLen;
      if (t >= rayLen) {
         continue;
      }

      vec3 worldPos = worldStart + worldDir * t;
      float dens = netherFogDensity(worldPos, t) * stepLen;
      vec3 optical = vec3(sigma) * extScale * dens;
      vec3 stepT = exp(-optical);
      vec3 vis = ((1.0 - stepT) / max(optical, vec3(1e-6))) * T;

      float lava = exp(-max(worldPos.y - 32.0, 0.0) / 38.0);
      vec3 ember = vec3(0.38, 0.12, 0.035);
      vec3 inCol = mix(atmos, ember, lava * 0.50 * NETHER_FOG_GLOW);

      scatter += vis * dens * inCol * sigma;
      T *= stepT;
   }

   T = clamp(T, vec3(0.0), vec3(1.0));
   vec3 lost = 1.0 - T;
   float sL = luma(scatter);
   vec3 fogCol = sL > 1e-5
      ? mix(atmos, scatter / sL * luma(atmos), 0.35)
      : atmos;
   scattering = lost * fogCol;
   transmittance = T;
}

vec3 netherBrightTap(vec2 uv) {
   vec3 s = texture2D(colortex0, uv).rgb;
   float l = luma(s);
   float w = smoothstep(0.70, 1.12, l);
   return s * w;
}

vec3 netherLavaBloom(vec2 uv) {
   vec2 px = vec2(1.0 / viewWidth, 1.0 / viewHeight);
   vec3 acc = netherBrightTap(uv);
   acc += netherBrightTap(uv + px * vec2( 4.0,  0.0));
   acc += netherBrightTap(uv + px * vec2(-4.0,  0.0));
   acc += netherBrightTap(uv + px * vec2( 0.0,  4.0));
   acc += netherBrightTap(uv + px * vec2( 0.0, -4.0));
   acc += netherBrightTap(uv + px * vec2( 3.2,  3.2));
   acc += netherBrightTap(uv + px * vec2(-3.2,  3.2));
   acc += netherBrightTap(uv + px * vec2( 3.2, -3.2));
   acc += netherBrightTap(uv + px * vec2(-3.2, -3.2));
   acc += netherBrightTap(uv + px * vec2( 8.0,  0.0)) * 0.45;
   acc += netherBrightTap(uv + px * vec2(-8.0,  0.0)) * 0.45;
   acc += netherBrightTap(uv + px * vec2( 0.0,  8.0)) * 0.45;
   acc += netherBrightTap(uv + px * vec2( 0.0, -8.0)) * 0.45;
   return acc * (NETHER_BLOOM * 0.055);
}

vec3 netherFogViewPos(vec2 uv, out bool sky) {
   float depth = texture2D(depthtex0, uv).x;
   sky = depth >= 1.0;

   #ifdef DISTANT_HORIZONS
      float dhDepth = texture2D(dhDepthTex0, uv).x;
      if (isDhLodSurface(depth, dhDepth)) {
         sky = false;
         return dhScreenToView(uv, dhDepth);
      }
      sky = sky && dhDepth >= 1.0;
   #endif

   if (sky) {
      vec3 dir = normalize(screen2view(uv, 0.999));
      return dir * netherFogFar();
   }

   return screen2view(uv, depth);
}

#endif
#endif
