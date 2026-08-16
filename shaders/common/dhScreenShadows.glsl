#ifndef DH_SCREEN_SHADOWS_GLSL
#define DH_SCREEN_SHADOWS_GLSL


#ifndef DH_DEPTH_SHADOW_STEPS
   #define DH_DEPTH_SHADOW_STEPS 10
#endif

float dhContactShadow(vec3 viewPos, vec3 viewNormal) {
   vec3 rayDir = normalize(shadowLightPosition);
   float NoL = dot(viewNormal, rayDir);
   if (NoL < 0.0) {
      return mix(0.38, 0.18, clamp(-NoL * 2.0, 0.0, 1.0));
   }

   vec3 origin = viewPos + viewNormal * 0.18 + rayDir * 0.12;
   vec3 farPoint = origin + rayDir * mix(18.0, 52.0, clamp(length(viewPos) / 220.0, 0.0, 1.0));

   vec3 s0 = view2screen(origin);
   vec3 s1 = view2screen(farPoint);
   vec3 delta = s1 - s0;
   float span = length(delta.xy);
   if (span < 1.0e-5) {
      return 1.0;
   }

   int steps = int(DH_DEPTH_SHADOW_STEPS);
   steps = clamp(steps, 4, 24);
   float dither = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
   vec3 stepNdc = delta / float(steps);
   vec3 p = s0 + stepNdc * (0.45 + dither * 0.28);
   float occ = 0.0;

   for (int i = 0; i < 24; i++) {
      if (i >= steps) {
         break;
      }

      if (p.x > 0.001 && p.x < 0.999 && p.y > 0.001 && p.y < 0.999 && p.z > 0.0 && p.z < 1.0) {
         vec3 rayView = screen2view(p.xy, p.z);
         float rayLen = length(rayView);
         float t = float(i) / float(max(steps - 1, 1));
         float minDelta = 0.28 + 0.55 * t;
         float maxDelta = 3.2 + 9.0 * t;
         float range = max(maxDelta - minDelta, 0.08);

         float sceneZ = texture2D(depthtex1, p.xy).x;
         if (sceneZ > 0.0 && sceneZ < 1.0) {
            float hit = rayLen - length(screen2view(p.xy, sceneZ));
            if (hit > minDelta && hit < maxDelta) {
               occ = max(occ, 1.0 - abs(hit - mix(minDelta, maxDelta, 0.4)) / range);
            }
         }

         #ifdef DISTANT_HORIZONS
            vec3 dhUv = dhViewToScreen(rayView);
            if (dhUv.x > 0.001 && dhUv.x < 0.999 && dhUv.y > 0.001 && dhUv.y < 0.999) {
               float dhZ = texture2D(dhDepthTex1, dhUv.xy).x;
               if (dhZ > 0.0 && dhZ < 1.0) {
                  float hitDh = rayLen - length(dhScreenToView(dhUv.xy, dhZ));
                  float maxDh = 6.0 + 16.0 * t;
                  float rangeDh = max(maxDh - minDelta * 1.3, 0.12);
                  if (hitDh > minDelta * 1.3 && hitDh < maxDh) {
                     occ = max(occ, 1.0 - abs(hitDh - mix(minDelta * 1.3, maxDh, 0.4)) / rangeDh);
                  }
               }
            }
         #endif
      }

      if (p.x < -0.02 || p.x > 1.02 || p.y < -0.02 || p.y > 1.02) {
         break;
      }

      p += stepNdc;
   }

   return 1.0 - occ;
}

float dhScreenAo(vec2 uv, vec3 viewPos, vec3 viewNormal, bool useDh) {
   vec2 pixel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
   float dither = random(gl_FragCoord.xy + vec2(13.7, 5.1));
   float occ = 0.0;
   float dist = length(viewPos);
   float radius = mix(6.5, 18.0, clamp(dist / 360.0, 0.0, 1.0));
   float falloffDist = mix(3.5, 16.0, clamp(dist / 280.0, 0.0, 1.0));

   for (int i = 0; i < 8; i++) {
      float a = (float(i) + dither) * 2.399963;
      float r = sqrt((float(i) + 0.35) / 8.0);
      vec2 suv = clamp(uv + vec2(cos(a), sin(a)) * pixel * radius * r, pixel, vec2(1.0) - pixel);

      float sd;
      bool sDh;
      sampleSceneDepth(suv, sd, sDh);
      if (sd >= 1.0 && !sDh) {
         continue;
      }

      vec3 sp = reflectionScreenToView(suv, sd, sDh);
      vec3 dir = sp - viewPos;
      float len = length(dir);
      if (len < 0.10) {
         continue;
      }

      float nd = max(dot(viewNormal, dir / len), 0.0);
      occ += nd * (1.0 - clamp(len / falloffDist, 0.0, 1.0));
   }

   return mix(1.0, 1.0 - occ * 0.11, 0.52);
}

#endif
