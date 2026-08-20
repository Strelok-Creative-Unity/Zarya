#ifndef RF_SHADER_CLOUDS_GLSL
#define RF_SHADER_CLOUDS_GLSL


#ifndef NOISETEX_UNIFORM
#define NOISETEX_UNIFORM
uniform sampler2D noisetex;
#endif

#ifndef NOISETEX_MC_UNIFORM
#define NOISETEX_MC_UNIFORM
uniform sampler2D noisetex_mc;
#endif

#ifndef NOISETEX_UC_UNIFORM
#define NOISETEX_UC_UNIFORM
uniform sampler2D noisetex_uc;
#endif

#ifndef FRAME_TIME_COUNTER_UNIFORM
#define FRAME_TIME_COUNTER_UNIFORM
uniform float frameTimeCounter;
#endif

#ifndef RAIN_STRENGTH_UNIFORM
#define RAIN_STRENGTH_UNIFORM
uniform float rainStrength;
#endif

#ifndef WETNESS_UNIFORM
#define WETNESS_UNIFORM
uniform float wetness;
#endif

#ifndef RF_CLOUD_SAMPLE_ONLY
#ifndef EYE_BRIGHTNESS_SMOOTH_UNIFORM
#define EYE_BRIGHTNESS_SMOOTH_UNIFORM
uniform ivec2 eyeBrightnessSmooth;
#endif

#ifndef FRAME_COUNTER_UNIFORM
#define FRAME_COUNTER_UNIFORM
uniform int frameCounter;
#endif

#ifndef GET_SKY_COLOR
   #include "/common/getSkyColor.glsl"
#endif
#endif

float rfCloudAmount01(float amount) {
   return clamp((amount - 0.15) / 1.05, 0.0, 1.0);
}

#ifndef CLOUD_RAIN_AMOUNT
#define CLOUD_RAIN_AMOUNT 1.0
#endif

float rfCloudEffectiveAmount(float amount) {
   return amount * mix(1.0, CLOUD_RAIN_AMOUNT, clamp(rainStrength, 0.0, 1.0));
}

float rfCloudCut(float amount) {
   return mix(0.76, 0.28, rfCloudAmount01(amount));
}

float rfCloudSigma(float density) {
   return mix(0.85, 2.4, clamp((density - 0.4) / 1.2, 0.0, 1.0));
}

float rfCloudSpan(float thickness) {
   return clamp(thickness * 2.15, 36.0, 210.0);
}

float rfCloudPeriod(float scale) {
   return clamp(scale * 3.8, 170.0, 1050.0);
}

vec2 rfCloudDrift(float speed, float loopSec) {
   float spd = max(speed, 0.015);
   float loop = max(loopSec, 1.0);
   float phase = fract(frameTimeCounter / loop);
   float run = 0.55 * spd;
   float ang = 6.283185307 * phase;
   return vec2(sin(ang) * run, (1.0 - cos(ang)) * run * 0.31);
}

float rfCloudShape(sampler2D tex, vec2 uv, bool lod) {
   vec2 u0 = uv * 0.36 + vec2(0.14, -0.08);
   float low = texture2D(tex, u0).r;
   if (lod) {
      return low;
   }
   vec2 u1 = mat2(0.87, 0.50, -0.50, 0.87) * (uv * 0.70) + vec2(-0.09, 0.16);
   float mid = texture2D(tex, u1).r;
   float skirt = texture2D(tex, uv * 1.15 + vec2(0.33, -0.21)).r;
   return clamp(low * 0.58 + mid * 0.30 + skirt * 0.12, 0.0, 1.0);
}

float rfCloudDetail(sampler2D tex, vec2 uv) {
   float d0 = texture2D(tex, uv * 1.55 + vec2(0.07, 0.19)).r;
   float d1 = texture2D(tex, uv * 2.35 + vec2(-0.23, 0.05)).r;
   return clamp(d0 * 0.65 + d1 * 0.35, 0.0, 1.0);
}

float rfCloudDensity(
   sampler2D tex,
   vec2 worldXz,
   vec2 drift,
   float h,
   float cut,
   float sigma,
   float period,
   float amount,
   float detail,
   bool lod
) {
   vec2 uv = worldXz / period + drift;
   float shape = rfCloudShape(tex, uv, lod);
   float det = lod ? 0.5 : rfCloudDetail(tex, uv);
   float skirt = smoothstep(0.15, 0.55, shape) * (1.0 - smoothstep(0.55, 0.88, shape));
   float field = shape + (det - 0.5) * (0.16 * detail) * (0.35 + 0.65 * skirt);
   field = clamp(field, 0.0, 1.0);

   float peak = mix(0.30, 0.50, clamp(shape, 0.0, 1.0));
   float below = max(peak, 0.18);
   float above = max(1.0 - peak, 0.22);
   float dh = h < peak ? (peak - h) / below : (h - peak) / above;
   dh = clamp(dh, 0.0, 1.0);
   float env = 1.0 - dh * dh;
   env *= 1.0 - smoothstep(0.72, 1.0, h);
   env *= smoothstep(0.0, 0.12, h);

   float amt = rfCloudAmount01(amount);
   float edgeLo = mix(0.18, 0.28, amt);
   float edgeHi = mix(0.28, 0.48, amt);
   float lift = mix(-0.03, 0.05, amt);
   float fieldAdj = clamp(field + lift, 0.0, 1.0);

   float dens = smoothstep(cut - edgeLo, cut + edgeHi, fieldAdj);
   float soft = pow(max(dens, 0.0), 0.78);
   float body = dens * dens * (3.0 - 2.0 * dens);
   dens = mix(soft, body, 0.55);
   dens *= env;
   dens *= sigma * 1.15;
   dens *= mix(1.0 - 0.18 * wetness, 1.0, clamp(rainStrength, 0.0, 1.0));
   return clamp(dens, 0.0, 1.0);
}

float rfCloudAt(
   sampler2D tex,
   vec3 worldPos,
   vec2 drift,
   float height,
   float thickness,
   float scale,
   float amount,
   float density,
   float detail,
   bool lod
) {
   float bottom = height;
   float span = rfCloudSpan(thickness);
   float top = bottom + span;
   if (worldPos.y < bottom || worldPos.y > top) {
      return 0.0;
   }
   float h = clamp((worldPos.y - bottom) / max(span, 1.0), 0.0, 1.0);
   return rfCloudDensity(
      tex, worldPos.xz, drift, h,
      rfCloudCut(amount), rfCloudSigma(density), rfCloudPeriod(scale),
      amount, detail, lod
   );
}

float rfCloudShadowLayer(
   sampler2D tex,
   vec3 worldPos,
   vec3 worldLightDir,
   float height,
   float thickness,
   float scale,
   float amount,
   float density,
   float detail,
   float speed,
   float loopSec
) {
   float bottom = height;
   float top = bottom + rfCloudSpan(thickness);
   if (worldPos.y >= top) {
      return 1.0;
   }
   vec3 L = worldLightDir;
   if (abs(L.y) < 0.02) {
      return 1.0;
   }
   float tA = (bottom - worldPos.y) / L.y;
   float tB = (top - worldPos.y) / L.y;
   float enter = max(min(tA, tB), 0.0);
   float leave = max(tA, tB);
   if (leave < 0.0) {
      return 1.0;
   }
   vec2 drift = rfCloudDrift(speed, loopSec);
   vec3 q0 = worldPos + L * mix(enter, leave, 0.32);
   vec3 q1 = worldPos + L * mix(enter, leave, 0.74);
   float od = rfCloudAt(tex, q0, drift, height, thickness, scale, amount, density, detail, true) * 0.58
            + rfCloudAt(tex, q1, drift, height, thickness, scale, amount, density, detail, true) * 0.42;
   return mix(0.22, 1.0, clamp(exp(-4.0 * od), 0.0, 1.0));
}

float rfCloudShadow(vec3 worldPos, vec3 worldLightDir) {
   vec3 L = normalize(worldLightDir);
   float topUC = CLOUD_UC_HEIGHT + rfCloudSpan(CLOUD_UC_THICKNESS);
   if (worldPos.y >= topUC) {
      return 1.0;
   }

   float sh = 1.0;
   sh *= rfCloudShadowLayer(
      noisetex, worldPos, L,
      CLOUD_LC_HEIGHT, CLOUD_LC_THICKNESS, CLOUD_LC_SCALE,
      rfCloudEffectiveAmount(CLOUD_LC_AMOUNT), CLOUD_LC_DENSITY, CLOUD_LC_DETAIL,
      CLOUD_LC_SPEED, CLOUD_LC_LOOP_SECONDS
   );
   if (sh < 0.24) {
      return sh;
   }
   sh *= rfCloudShadowLayer(
      noisetex_mc, worldPos, L,
      CLOUD_MC_HEIGHT, CLOUD_MC_THICKNESS, CLOUD_MC_SCALE,
      rfCloudEffectiveAmount(CLOUD_MC_AMOUNT), CLOUD_MC_DENSITY, CLOUD_MC_DETAIL,
      CLOUD_MC_SPEED, CLOUD_MC_LOOP_SECONDS
   );
   if (sh < 0.24) {
      return sh;
   }
   sh *= rfCloudShadowLayer(
      noisetex_uc, worldPos, L,
      CLOUD_UC_HEIGHT, CLOUD_UC_THICKNESS, CLOUD_UC_SCALE,
      rfCloudEffectiveAmount(CLOUD_UC_AMOUNT), CLOUD_UC_DENSITY, CLOUD_UC_DETAIL,
      CLOUD_UC_SPEED, CLOUD_UC_LOOP_SECONDS
   );
   return sh;
}

#ifndef RF_CLOUD_SAMPLE_ONLY
vec4 rfCloudSkyHintLayer(
   sampler2D tex,
   vec3 viewDir,
   vec3 lightColor,
   float height,
   float thickness,
   float scale,
   float amount,
   float density,
   float detail,
   float speed,
   float loopSec,
   float opacity
) {
   vec3 rd = normalize(view2eye(viewDir));
   if (rd.y < 0.05) {
      return vec4(0.0);
   }
   float bottom = height;
   float span = rfCloudSpan(thickness);
   float t = ((bottom + span * 0.35) - cameraPosition.y) / rd.y;
   if (t < 40.0) {
      return vec4(0.0);
   }
   float n = rfCloudAt(
      tex, cameraPosition + rd * t, rfCloudDrift(speed, loopSec),
      height, thickness, scale, amount, density, detail, true
   );
   if (n < 0.02) {
      return vec4(0.0);
   }
   return vec4(mix(lightColor * 0.6, lightColor, 0.55), clamp(n * opacity * 0.8, 0.0, 0.85));
}

vec4 rfCloudSkyHint(vec3 viewDir, vec3 lightColor) {
   vec4 a = rfCloudSkyHintLayer(
      noisetex_uc, viewDir, lightColor,
      CLOUD_UC_HEIGHT, CLOUD_UC_THICKNESS, CLOUD_UC_SCALE,
      rfCloudEffectiveAmount(CLOUD_UC_AMOUNT), CLOUD_UC_DENSITY, CLOUD_UC_DETAIL,
      CLOUD_UC_SPEED, CLOUD_UC_LOOP_SECONDS, CLOUD_UC_OPACITY
   );
   vec4 b = rfCloudSkyHintLayer(
      noisetex_mc, viewDir, lightColor,
      CLOUD_MC_HEIGHT, CLOUD_MC_THICKNESS, CLOUD_MC_SCALE,
      rfCloudEffectiveAmount(CLOUD_MC_AMOUNT), CLOUD_MC_DENSITY, CLOUD_MC_DETAIL,
      CLOUD_MC_SPEED, CLOUD_MC_LOOP_SECONDS, CLOUD_MC_OPACITY
   );
   vec4 c = rfCloudSkyHintLayer(
      noisetex, viewDir, lightColor,
      CLOUD_LC_HEIGHT, CLOUD_LC_THICKNESS, CLOUD_LC_SCALE,
      rfCloudEffectiveAmount(CLOUD_LC_AMOUNT), CLOUD_LC_DENSITY, CLOUD_LC_DETAIL,
      CLOUD_LC_SPEED, CLOUD_LC_LOOP_SECONDS, CLOUD_LC_OPACITY
   );
   float a1 = b.a + a.a * (1.0 - b.a);
   vec3 rgb1 = a1 > 1.0e-4 ? (b.rgb * b.a + a.rgb * a.a * (1.0 - b.a)) / a1 : vec3(0.0);
   float a2 = c.a + a1 * (1.0 - c.a);
   vec3 rgb2 = a2 > 1.0e-4 ? (c.rgb * c.a + rgb1 * a1 * (1.0 - c.a)) / a2 : vec3(0.0);
   return vec4(rgb2, a2);
}

#ifdef RF_CLOUD_DRAW
float rfCloudLayerDensAt(
   sampler2D tex,
   vec3 pos,
   vec2 drift,
   float height,
   float thickness,
   float scale,
   float amount,
   float density,
   float detail,
   float fadeStart,
   float fadeEnd,
   bool lod
) {
   float bottom = height;
   float span = rfCloudSpan(thickness);
   float top = bottom + span;
   if (pos.y < bottom - 4.0 || pos.y > top + 4.0) {
      return 0.0;
   }
   float softY = max(span * 0.10, 4.0);
   float inside = smoothstep(bottom - softY * 0.15, bottom + softY, pos.y)
                * smoothstep(top + softY * 0.15, top - softY, pos.y);
   if (inside < 0.001) {
      return 0.0;
   }
   float h = clamp((pos.y - bottom) / max(span, 1.0), 0.0, 1.0);
   float dens = rfCloudDensity(
      tex, pos.xz, drift, h,
      rfCloudCut(amount), rfCloudSigma(density), rfCloudPeriod(scale),
      amount, detail, lod
   );
   float xz = length(pos.xz - cameraPosition.xz);
   dens *= inside * (1.0 - smoothstep(fadeEnd - max(fadeStart * 0.35, 24.0), fadeEnd, xz));
   return dens;
}

vec4 rfCloudOverStraight(vec4 front, vec4 back) {
   float outA = front.a + back.a * (1.0 - front.a);
   if (outA < 1.0e-4) {
      return vec4(0.0);
   }
   vec3 outRgb = (front.rgb * front.a + back.rgb * back.a * (1.0 - front.a)) / outA;
   return vec4(outRgb, outA);
}

vec4 rfMarchCloudLayer(
   sampler2D tex,
   vec3 rd,
   bool sky,
   float sceneLen,
   float cap,
   float dither,
   vec3 lightColor,
   vec3 atmosphere,
   vec3 lightOff,
   float phase,
   float sunVis,
   float sunVisSqrt,
   float nightVis,
   float fadeNear,
   float fadeFar,
   float height,
   float thickness,
   float scale,
   float amount,
   float density,
   float detail,
   float speed,
   float loopSec,
   float opacity,
   int sampleCount
) {
   vec4 vc = vec4(0.0);
   if (abs(rd.y) < 1.0e-4) {
      return vc;
   }
   float span = rfCloudSpan(thickness);
   float bottom = height;
   float top = bottom + span;

   float tA = (bottom - cameraPosition.y) / rd.y;
   float tB = (top - cameraPosition.y) / rd.y;
   float t0 = max(min(tA, tB), 0.0);
   float t1 = min(max(tA, tB), cap);
   if (t1 <= t0) {
      return vc;
   }
   if (!sky) {
      t1 = min(t1, sceneLen);
      if (t1 <= t0) {
         return vc;
      }
   }

   int n = int(clamp(float(sampleCount), 6.0, 48.0));
   float pathLen = max(t1 - t0, 1.0);
   float stepLen = pathLen / float(n);
   vec2 drift = rfCloudDrift(speed, loopSec);
   vec3 stepV = rd * stepLen;
   vec3 pos = cameraPosition + rd * t0 + stepV * dither;
   float travelled = t0 + stepLen * dither;

   float alpha = 0.0;
   float litDirect = 0.0;
   float litAmbient = 0.0;
   float distMul = 1.0;
   float densDistSum = 0.0;
   float densDistW = 0.0;

   for (int i = 0; i < 48; i++) {
      if (i >= n || alpha > 0.99 || travelled > cap) {
         break;
      }
      if (!sky && sceneLen < travelled) {
         break;
      }

      bool lod = travelled > 520.0;
      float dens = rfCloudLayerDensAt(
         tex, pos, drift,
         height, thickness, scale,
         amount, density, detail,
         fadeNear, fadeFar, lod
      );

      if (dens > 0.0001) {
         float dL = rfCloudLayerDensAt(
            tex, pos + lightOff, drift,
            height, thickness, scale,
            amount, density, detail,
            fadeNear, fadeFar, true
         );
         float h = clamp((pos.y - height) / max(span, 1.0), 0.0, 1.0);
         float sigma = mix(2.4, 3.8, 1.0 - sunVis);
         float beer = exp(-dL * sigma);
         float silver = mix(0.82, 1.28, phase);
         float direct = clamp(beer * silver, 0.0, 1.35);
         float ambient = mix(0.42, 1.08, smoothstep(0.08, 0.78, h));
         ambient *= mix(0.9, 1.12, beer);

         float remain = 1.0 - alpha;
         float w = dens * remain;
         float wNorm = w / max(dens + remain * 0.35, 1.0e-3);
         litDirect = mix(litDirect, direct, clamp(wNorm, 0.0, 1.0));
         litAmbient = mix(litAmbient, ambient, clamp(wNorm * 0.85, 0.0, 1.0));

         densDistSum += length(pos - cameraPosition) * dens;
         densDistW += dens;

         float xz = length(pos.xz - cameraPosition.xz);
         float edge = 1.0 - smoothstep(fadeNear, fadeFar, xz);
         distMul *= mix(1.0, max(edge, 0.5), dens * remain * 0.28);

         float aGain = mix(0.26, 0.58, smoothstep(0.10, 0.50, dens));
         alpha = clamp(alpha + dens * aGain * remain, 0.0, 1.0);
      }

      pos += stepV;
      travelled += stepLen;
   }

   float alphaFar = alpha * distMul;
   if (alphaFar < 0.004) {
      return vc;
   }

   vec3 dayAlbedo = vec3(1.06, 1.09, 1.16);
   vec3 nightAlbedo = mix(atmosphere * 1.35 + vec3(0.012), vec3(0.38, 0.44, 0.58), 0.42);
   vec3 albedo = mix(nightAlbedo, dayAlbedo, sunVisSqrt);
   float shade = mix(0.58, 0.76, nightVis) + mix(0.0, 0.48, sunVis) * clamp(litDirect, 0.0, 1.0);
   float lift = mix(0.72, 0.86, nightVis) + mix(0.0, 0.28, sunVis) * clamp(litAmbient, 0.0, 1.0);
   vec3 col = albedo * lightColor * shade * lift;
   col *= mix(0.82, 0.90, sunVis) + phase * mix(0.14, 0.22, sunVis);
   col = mix(col, dayAlbedo * 1.05, 0.28 * sunVisSqrt);
   float atmMix = mix(0.42, 0.10, sunVis) * (1.0 - clamp(litDirect, 0.0, 1.0));
   col = mix(col, atmosphere, atmMix);

   float rain = clamp(rainStrength, 0.0, 1.0);
   col *= mix(1.0, 0.56, rain);
   col = mix(vec3(luma(col)), col, mix(1.0, 0.68, rain));
   col = mix(col, mix(atmosphere, vec3(luma(atmosphere)), 0.20), rain * 0.26);

   float meanDist = densDistW > 1.0e-4 ? densDistSum / densDistW : travelled;
   float hazeStart = 180.0 * 16.0;
   float hazeEnd = 480.0 * 16.0;
   float haze = smoothstep(hazeStart, hazeEnd, meanDist);
   haze = haze * haze * (3.0 - 2.0 * haze);
   vec3 milk = mix(atmosphere, mix(vec3(0.94, 0.96, 1.0), atmosphere, 0.28), sunVisSqrt);
   col = mix(col, milk, haze * mix(0.52, 0.78, sunVis));
   float grey = dot(col, vec3(0.299, 0.587, 0.114));
   col = mix(col, vec3(grey), haze * mix(0.22, 0.40, sunVis));
   col = mix(col, vec3(1.0), haze * 0.12 * sunVis);
   alphaFar *= mix(1.0, 0.40, haze);

   float op = clamp(opacity * (1.0 - wetness * 0.22), 0.0, 1.0);
   vc = vec4(col, clamp(alphaFar * op, 0.0, 1.0));
   return vc;
}

vec4 rfDrawClouds(vec3 viewPos, bool sky, vec3 lightColor) {
   vec4 vc = vec4(0.0);
   float cave = smoothstep(0.0, 0.85, float(eyeBrightnessSmooth.y) / 240.0);
   if (cave < 0.05) {
      return vc;
   }

   float sunVis = getSunVisibility();
   float sunVisSqrt = sqrt(sunVis);
   float nightVis = 1.0 - sunVis;

   float dither = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;
   #ifdef TAA
      dither = fract(dither + 1.61803398875 * mod(float(frameCounter), 3600.0));
   #endif
   dither = mix(dither, 0.5, pow(nightVis, 1.4) * 0.72);

   vec3 nView = normalize(viewPos);
   vec3 rd = normalize(view2eye(viewPos));
   float sceneLen = length(viewPos);

   float distanceIn = max(max(CLOUD_LC_DISTANCE, CLOUD_MC_DISTANCE), CLOUD_UC_DISTANCE);
   float cap = sky ? distanceIn * 32.0 : min(sceneLen, distanceIn * 32.0);

   vec3 Lview = normalize(shadowLightPosition);
   float dayLit = clamp(sunVis * 1.27, 0.0, 1.0);
   float VoL = clamp(dot(nView, Lview), -1.0, 1.0);
   float g = mix(0.35, 0.72, dayLit);
   float k = 1.5 * g - 0.5 * g * g * g;
   float phase = (1.0 - k * k) / max((1.0 - k * VoL) * (1.0 - k * VoL), 1.0e-3);
   phase = mix(0.55, 1.45, clamp(phase * 0.22, 0.0, 1.0));

   vec3 Lworld = normalize(view2eye(Lview));
   float probe = mix(18.0, 42.0, dayLit) / max(abs(Lworld.y) * 0.65 + 0.35, 0.2);
   vec3 lightOff = Lworld * probe;

   float fadeNear = max(distanceIn * 0.18, 120.0);
   float fadeFar  = max(distanceIn * 0.95, fadeNear + 64.0);
   vec3 atmosphere = getSkyColorNoStars(nView);

   float moonCover = 0.0;
   #ifdef OVERWORLD
      float moonLen = length(moonPosition);
      if (moonLen > 1.0e-4 && nightVis > 0.05) {
         float moonDot = max(dot(nView, moonPosition / moonLen), 0.0);
         moonCover = smoothstep(0.955, 0.995, moonDot) * nightVis;
         atmosphere = mix(atmosphere, atmosphere * vec3(0.50, 0.54, 0.68), moonCover * 0.85);
      }
   #endif

   vec4 far = rfMarchCloudLayer(
      noisetex_uc, rd, sky, sceneLen, cap, dither, lightColor, atmosphere,
      lightOff, phase, sunVis, sunVisSqrt, nightVis, fadeNear, fadeFar,
      CLOUD_UC_HEIGHT, CLOUD_UC_THICKNESS, CLOUD_UC_SCALE,
      rfCloudEffectiveAmount(CLOUD_UC_AMOUNT), CLOUD_UC_DENSITY, CLOUD_UC_DETAIL,
      CLOUD_UC_SPEED, CLOUD_UC_LOOP_SECONDS, CLOUD_UC_OPACITY, CLOUD_UC_SAMPLES
   );
   vec4 mid = rfMarchCloudLayer(
      noisetex_mc, rd, sky, sceneLen, cap, dither, lightColor, atmosphere,
      lightOff, phase, sunVis, sunVisSqrt, nightVis, fadeNear, fadeFar,
      CLOUD_MC_HEIGHT, CLOUD_MC_THICKNESS, CLOUD_MC_SCALE,
      rfCloudEffectiveAmount(CLOUD_MC_AMOUNT), CLOUD_MC_DENSITY, CLOUD_MC_DETAIL,
      CLOUD_MC_SPEED, CLOUD_MC_LOOP_SECONDS, CLOUD_MC_OPACITY, CLOUD_MC_SAMPLES
   );
   vec4 near = rfMarchCloudLayer(
      noisetex, rd, sky, sceneLen, cap, dither, lightColor, atmosphere,
      lightOff, phase, sunVis, sunVisSqrt, nightVis, fadeNear, fadeFar,
      CLOUD_LC_HEIGHT, CLOUD_LC_THICKNESS, CLOUD_LC_SCALE,
      rfCloudEffectiveAmount(CLOUD_LC_AMOUNT), CLOUD_LC_DENSITY, CLOUD_LC_DETAIL,
      CLOUD_LC_SPEED, CLOUD_LC_LOOP_SECONDS, CLOUD_LC_OPACITY, CLOUD_LC_SAMPLES
   );

   vc = rfCloudOverStraight(mid, far);
   vc = rfCloudOverStraight(near, vc);
   vc.a = clamp(vc.a * cave, 0.0, 1.0);
   if (moonCover > 0.001) {
      vc.a = mix(vc.a, min(1.0, vc.a * 1.30 + 0.22), moonCover);
      vc.rgb = mix(vc.rgb, vc.rgb * 0.78, moonCover * 0.45);
   }
   return vc;
}
#endif
#endif

#endif
