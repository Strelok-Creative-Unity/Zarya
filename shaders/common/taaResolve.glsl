#ifndef RF_TAA_RESOLVE_GLSL
#define RF_TAA_RESOLVE_GLSL

#include "/common/taaReproject.glsl"


vec3 rfTaaRgbToYcocg(vec3 c) {
   return vec3(
      c.r * 0.25 + c.g * 0.50 + c.b * 0.25,
      c.r * 0.50 - c.b * 0.50,
      -c.r * 0.25 + c.g * 0.50 - c.b * 0.25
   );
}

vec3 rfTaaYcocgToRgb(vec3 c) {
   float n = c.x - c.z;
   return vec3(n + c.y, c.x + c.z, n - c.y);
}

vec3 rfTaaClipAabb(vec3 q, vec3 aabbMin, vec3 aabbMax) {
   vec3 center = 0.5 * (aabbMin + aabbMax);
   vec3 extent = 0.5 * (aabbMax - aabbMin) + 1.0e-8;
   vec3 v = q - center;
   vec3 unit = v / extent;
   float maxUnit = max(max(abs(unit.x), abs(unit.y)), abs(unit.z));
   if (maxUnit > 1.0) {
      return center + v / maxUnit;
   }
   return q;
}

vec3 rfTaaHistorySample(sampler2D tex, vec2 uv, vec2 res) {
   vec2 pos = uv * res - 0.5;
   vec2 i = floor(pos);
   vec2 f = pos - i;
   vec2 f2 = f * f;
   vec2 f3 = f2 * f;

   vec2 w0 = -0.5 * f3 + f2 - 0.5 * f;
   vec2 w1 =  1.5 * f3 - 2.5 * f2 + 1.0;
   vec2 w2 = -1.5 * f3 + 2.0 * f2 + 0.5 * f;
   vec2 w3 =  0.5 * f3 - 0.5 * f2;

   vec2 w12 = w1 + w2;
   vec2 tc12 = (i + 0.5 + w2 / w12) / res;
   vec2 tc0  = (i - 0.5) / res;
   vec2 tc3  = (i + 2.5) / res;

   vec3 s =
        texture2D(tex, vec2(tc12.x, tc0.y )).rgb * (w12.x *  w0.y) +
        texture2D(tex, vec2(tc0.x,  tc12.y)).rgb * ( w0.x * w12.y) +
        texture2D(tex, vec2(tc12.x, tc12.y)).rgb * (w12.x * w12.y) +
        texture2D(tex, vec2(tc3.x,  tc12.y)).rgb * ( w3.x * w12.y) +
        texture2D(tex, vec2(tc12.x, tc3.y )).rgb * (w12.x *  w3.y);
   float w = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
   return s / max(w, 1.0e-5);
}

void rfTaaClosestDepth(vec2 uv, vec2 texel, out float depth, out bool useDh, out vec2 closestUv) {
   vec2 tap[5];
   tap[0] = vec2(0.0);
   tap[1] = vec2(-2.0, -2.0);
   tap[2] = vec2( 2.0, -2.0);
   tap[3] = vec2(-2.0,  2.0);
   tap[4] = vec2( 2.0,  2.0);

   depth = 1.0;
   closestUv = uv;
   for (int i = 0; i < 5; i++) {
      vec2 p = uv + tap[i] * texel;
      float d = texture2D(depthtex0, p).x;
      if (d < depth) {
         depth = d;
         closestUv = p;
      }
   }

   useDh = false;
   #ifdef DISTANT_HORIZONS
      float dhBest = 1.0;
      vec2 dhUv = uv;
      for (int j = 0; j < 5; j++) {
         vec2 p = uv + tap[j] * texel;
         float d = texture2D(dhDepthTex0, p).x;
         if (d < dhBest) {
            dhBest = d;
            dhUv = p;
         }
      }
      if (isDhLodSurface(depth, dhBest)) {
         depth = dhBest;
         closestUv = dhUv;
         useDh = true;
      }
   #endif
}

vec3 rfTaaClipNeighborhood(vec3 current, vec3 history, vec2 uv, vec2 texel) {
   vec3 y = rfTaaRgbToYcocg(current);
   vec3 yMin = y;
   vec3 yMax = y;
   vec3 yAvg = y;

   vec2 o[8];
   o[0] = vec2( 0.0, -1.0);
   o[1] = vec2(-1.0,  0.0);
   o[2] = vec2( 1.0,  0.0);
   o[3] = vec2( 0.0,  1.0);
   o[4] = vec2(-1.0, -1.0);
   o[5] = vec2( 1.0, -1.0);
   o[6] = vec2(-1.0,  1.0);
   o[7] = vec2( 1.0,  1.0);

   for (int i = 0; i < 8; i++) {
      vec3 n = rfTaaRgbToYcocg(texture2D(colortex0, uv + o[i] * texel).rgb);
      yMin = min(yMin, n);
      yMax = max(yMax, n);
      yAvg += n;
   }
   yAvg /= 9.0;

   yMin = mix(yAvg, yMin, 0.75);
   yMax = mix(yAvg, yMax, 0.75);

   vec3 clipped = rfTaaClipAabb(rfTaaRgbToYcocg(history), yMin, yMax);
   return rfTaaYcocgToRgb(clipped);
}

vec3 rfTaaResolveScene(vec3 current, vec2 uv) {
   float strength = clamp(float(TAA_STRENGTH), 0.0, 1.0);
   if (strength < 0.001) {
      return current;
   }

   vec2 res = vec2(viewWidth, viewHeight);
   vec2 texel = 1.0 / res;

   float depth;
   bool useDh;
   vec2 closestUv;
   rfTaaClosestDepth(uv, texel, depth, useDh, closestUv);

   vec2 prevUv = rfTaaReproject(closestUv, depth, useDh);
   bool inScreen = prevUv.x > 0.002 && prevUv.x < 0.998
                && prevUv.y > 0.002 && prevUv.y < 0.998;
   if (!inScreen) {
      return current;
   }

   vec3 history = rfTaaHistorySample(colortex4, prevUv, res);
   if (any(lessThan(history, vec3(-0.05))) || any(greaterThan(history, vec3(48.0)))) {
      return current;
   }

   history = rfTaaClipNeighborhood(current, history, uv, texel);

   vec2 velocity = (uv - prevUv) * res;
   float speed = length(velocity);

   float blend = mix(0.76, 0.93, 1.0 - smoothstep(0.0, 6.0, speed));
   blend *= mix(1.0, 0.28, smoothstep(6.0, 40.0, speed));

   if (!useDh && depth < 0.56) {
      blend *= 0.12;
   }

   blend *= strength;
   blend = clamp(blend, 0.0, 0.94);

   vec3 curT = current / (current + vec3(1.0));
   vec3 histT = history / (history + vec3(1.0));
   vec3 mixed = mix(curT, histT, blend);
   return mixed / max(vec3(1.0) - mixed, vec3(1.0e-4));
}

#endif
