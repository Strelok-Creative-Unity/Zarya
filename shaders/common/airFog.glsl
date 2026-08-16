#ifndef AIR_FOG_GLSL
#define AIR_FOG_GLSL


#if defined AIR_FOG && defined OVERWORLD

#ifndef AIR_FOG_STRENGTH
   #define AIR_FOG_STRENGTH 1.0
#endif
#ifndef AIR_FOG_DENSITY
   #define AIR_FOG_DENSITY 1.0
#endif
#ifndef AIR_FOG_MIE
   #define AIR_FOG_MIE 1.0
#endif
#ifndef AIR_FOG_HEIGHT
   #define AIR_FOG_HEIGHT 32.0
#endif
#ifndef AIR_FOG_SAMPLES
   #define AIR_FOG_SAMPLES 12
#endif
#ifndef AIR_FOG_RAIN
   #define AIR_FOG_RAIN 1.0
#endif

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

#ifndef EYE_BRIGHTNESS_SMOOTH_UNIFORM
#define EYE_BRIGHTNESS_SMOOTH_UNIFORM
uniform ivec2 eyeBrightnessSmooth;
#endif

#ifdef AIR_FOG_NOISE
   #ifndef NOISETEX_UNIFORM
   #define NOISETEX_UNIFORM
   uniform sampler2D noisetex;
   #endif
   #ifndef FRAME_TIME_COUNTER_UNIFORM
   #define FRAME_TIME_COUNTER_UNIFORM
   uniform float frameTimeCounter;
   #endif
#endif

const float TMP_FOG_SEA = 63.0;
const float TMP_FOG_VOL_BOTTOM = 16.0;
const float TMP_FOG_VOL_TOP = 428.0;

float tmpFogHG(float cosT, float g) {
   return henyeyGreenstein(cosT, g);
}

float airFogFar() {
   #ifdef DISTANT_HORIZONS
      return max(far, max(dhFarPlane, float(dhRenderDistance)));
   #else
      return far;
   #endif
}

// MIT ref: David Hoskins — Hash without Sine (hash12)
// Source: https://www.shadertoy.com/view/4djSRW
// License text: THIRD_PARTY_NOTICES.md
float airFogDither(vec2 p) {
   vec3 m = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
   m += dot(m, m.yzx + 33.33);
   return fract((m.x + m.y) * m.z);
}

vec2 airFogDensity(vec3 worldPos) {
   float H = max(AIR_FOG_HEIGHT, 4.0);
   float y = worldPos.y - TMP_FOG_SEA;

   float rlh = exp(-max(y - H * 0.42, 0.0) / (H * 1.18));
   float mie = exp(-max(y + H * 0.12, 0.0) / (H * 0.44));

   float below = smoothstep(TMP_FOG_VOL_BOTTOM - 6.0, TMP_FOG_VOL_BOTTOM + 20.0, worldPos.y);
   float above = 1.0 - smoothstep(TMP_FOG_VOL_TOP - 70.0, TMP_FOG_VOL_TOP, worldPos.y);
   float gate = below * above;
   rlh *= gate;
   mie *= gate * gate;

   #ifdef AIR_FOG_NOISE
      vec2 drift = vec2(0.37, -0.22) * frameTimeCounter * 0.00051;
      float n0 = texture2D(noisetex, worldPos.xz * 0.00073 + drift).r;
      float n1 = texture2D(noisetex, worldPos.xz * 0.00215 - drift * 1.65).b;
      mie *= 0.40 + 1.55 * n0 * n1;
   #endif

   return vec2(rlh, mie) * AIR_FOG_STRENGTH;
}

#if defined ENABLE_SHADOWS
#include "/common/shadowVis.glsl"
#endif

bool airFogVolumeRange(float camY, vec3 dir, float rayLen, out float t0, out float t1) {
   const float y0 = TMP_FOG_VOL_BOTTOM;
   const float y1 = TMP_FOG_VOL_TOP;

   if (abs(dir.y) < 1e-4) {
      if (camY < y0 || camY > y1) {
         return false;
      }
      t0 = 0.0;
      t1 = rayLen;
      return rayLen > 0.0;
   }

   float tBottom = (y0 - camY) / dir.y;
   float tTop = (y1 - camY) / dir.y;
   float tEnter = min(tBottom, tTop);
   float tExit = max(tBottom, tTop);

   if (camY >= y0 && camY <= y1) {
      t0 = 0.0;
      t1 = min(tExit, rayLen);
      return t1 > 1e-3;
   }

   t0 = max(tEnter, 0.0);
   t1 = min(tExit, rayLen);
   return t1 > t0 + 1e-3;
}

void computeAirFog(vec3 viewPos, bool sky, vec3 sunCol, out vec3 scattering, out vec3 transmittance) {
   scattering = vec3(0.0);
   transmittance = vec3(1.0);

   float fogEnd = airFogFar();
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

   float t0, t1;
   if (!airFogVolumeRange(cameraPosition.y, worldDir, rayLen, t0, t1)) {
      return;
   }

   float marchLen = t1 - t0;

   float dither = airFogDither(gl_FragCoord.xy);
   float stepLen = marchLen / float(AIR_FOG_SAMPLES);

   float sunUp = dot(normalize(sunPosition), gbufferModelView[1].xyz);
   float sunVis = clamp((sunUp + 0.1) * 4.0, 0.0, 1.0);
   float dusk = exp(-sunUp * sunUp * 28.0) * smoothstep(-0.25, 0.08, sunUp);

   vec3 rlhCoeff = vec3(0.31, 0.67, 1.00) * (0.00055 * AIR_FOG_DENSITY);
   float mieBase = 0.0012 + 0.0055 * dusk + 0.0035 * (1.0 - sunVis);
   mieBase *= AIR_FOG_MIE;
   mieBase = mix(mieBase, mieBase + 0.022 * AIR_FOG_RAIN, rainStrength);
   vec3 mieScatter = vec3(mieBase * mix(0.90, 0.55, rainStrength));
   vec3 mieExtinct = vec3(mieBase);

   vec3 ambient = mix(max(fogColor, vec3(0.001)), max(skyColor, vec3(0.001)), 0.38);
   vec3 nightAmb = vec3(0.014, 0.024, 0.055);
   ambient = mix(nightAmb, ambient, sunVis);
   ambient = mix(ambient, mix(fogColor, vec3(luma(fogColor)), 0.25), rainStrength);

   vec3 lightDir = normalize(view2eye(shadowLightPosition));
   float LoV = dot(worldDir, lightDir);
   float miePhase = 0.7 * tmpFogHG(LoV, 0.5) + 0.3 * tmpFogHG(LoV, -0.2);
   float iso = 0.079577;

   vec3 sunRlh = vec3(0.0);
   vec3 sunMie = vec3(0.0);
   vec3 skyRlh = vec3(0.0);
   vec3 skyMie = vec3(0.0);
   vec3 T = vec3(1.0);

   for (int i = 0; i < AIR_FOG_SAMPLES; i++) {
      float t = t0 + (float(i) + 0.5 + (dither - 0.5) * 0.22) * stepLen;
      if (t >= t1) {
         continue;
      }

      vec3 worldPos = worldStart + worldDir * t;
      vec2 density = airFogDensity(worldPos) * stepLen;

      float sunLit = 1.0;
      #if defined ENABLE_SHADOWS
         sunLit = shadowVisibility(world2feet(worldPos));
      #endif

      vec3 optical = rlhCoeff * density.x + mieExtinct * density.y;
      vec3 stepT = exp(-optical);
      vec3 vis = ((1.0 - stepT) / max(optical, vec3(1e-6))) * T;

      float rlhSun = density.x * mix(0.55, 1.0, sunLit);
      float mieSun = density.y * sunLit;

      sunRlh += vis * rlhSun;
      sunMie += vis * mieSun;
      skyRlh += vis * density.x;
      skyMie += vis * density.y;
      T *= stepT;
   }

   sunRlh *= rlhCoeff;
   sunMie *= mieScatter;
   skyRlh *= rlhCoeff;
   skyMie *= mieScatter;

   scattering = sunCol * (sunRlh * iso + sunMie * miePhase) * (1.0 - rainStrength * 0.55);
   scattering += ambient * (skyRlh + skyMie) * iso * 2.0;

   float eveningGlow = 0.75 * clamp((exp(-sunUp * sunUp * 80.0) - 0.05) / 0.95, 0.0, 1.0);

   vec3 fogLit = ambient + sunCol * (0.16 + 0.62 * dusk + 0.22 * eveningGlow);
   fogLit *= mix(1.0, 0.58, rainStrength);
   fogLit = min(fogLit, vec3(1.05));

   float cave = smoothstep(0.10, 0.55, float(eyeBrightnessSmooth.y) / 240.0);
   scattering *= mix(0.28, 1.0, cave);
   T = mix(vec3(1.0), T, mix(0.35, 1.0, cave));
   fogLit *= mix(0.50, 1.0, cave);

   #ifdef DISTANT_HORIZONS
      float seam = smoothstep(far * 0.50, max(far * 2.1, 64.0), rayLen);
      T *= vec3(1.0 - 0.48 * seam);
   #endif

   T = clamp(T, vec3(0.0), vec3(1.0));
   vec3 lost = 1.0 - T;

   float sL = luma(scattering);
   float litL = max(luma(fogLit), 1e-4);
   vec3 tint = sL > 1e-5
      ? mix(fogLit / litL, scattering / sL, 0.35)
      : fogLit / litL;
   scattering = max(lost * tint * litL, vec3(0.0));
   transmittance = T;
}

vec3 airFogViewPos(vec2 uv, out bool sky) {
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
      return dir * airFogFar();
   }

   return screen2view(uv, depth);
}

#endif
#endif
