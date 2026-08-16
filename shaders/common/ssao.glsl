#ifndef SSAO_GLSL
#define SSAO_GLSL

vec3 sampleViewPos(vec2 uv) {
   float d = texture2D(depthtex0, uv).x;
   #ifdef DISTANT_HORIZONS
      float dh = texture2D(dhDepthTex0, uv).x;
      if (d >= 1.0 && dh < 1.0) {
         return dhScreenToView(uv, dh);
      }
   #endif
   return screen2view(uv, d);
}

float computeSSAO(vec2 uv, vec3 viewPos, vec3 viewNormal) {
   float dist = length(viewPos);
   if (dist > 120.0) {
      return 1.0;
   }

   float radius = AO_RADIUS * mix(0.70, 1.05, clamp(dist / 48.0, 0.0, 1.0));
   float dither = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
   float occ = 0.0;
   float weight = 0.0;
   vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
   vec2 uvMin = texel * 0.5;
   vec2 uvMax = vec2(1.0) - texel * 0.5;

   for (int i = 0; i < AO_SAMPLES; i++) {

      #if AO_MODE == 0
         float a = (float(i) + dither) * 2.399963;
         float r = sqrt((float(i) + 0.5) / float(AO_SAMPLES));
         vec3 dir = normalize(viewNormal + vec3(cos(a), sin(a), 0.35) * r);
      #else
         float a = (float(i) + dither) * 2.399963;
         float r = (float(i) + 0.5) / float(AO_SAMPLES);
         vec3 tangent = normalize(cross(viewNormal, vec3(0.0, 1.0, 0.04 + fract(dither + float(i) * 0.17))));
         vec3 bitangent = cross(viewNormal, tangent);
         vec3 dir = normalize(tangent * cos(a) + bitangent * sin(a) + viewNormal * (0.55 + 0.45 * r));
         r = sqrt(r);
      #endif

      vec3 samplePos = viewPos + dir * (radius * (0.35 + 0.65 * r));
      vec3 sampleScreen = view2screen(samplePos);
      vec2 suv = clamp(sampleScreen.xy, uvMin, uvMax);
      float offX = max(-sampleScreen.x, sampleScreen.x - 1.0);
      float offY = max(-sampleScreen.y, sampleScreen.y - 1.0);
      float offscreen = max(offX, offY);
      float edgeW = 1.0 - smoothstep(0.0, 0.06, max(offscreen, 0.0));
      if (edgeW < 0.02) {
         continue;
      }

      vec3 scenePos = sampleViewPos(suv);
      vec3 v = scenePos - viewPos;
      float vLen = length(v);
      if (vLen < 0.02) {
         continue;
      }

      float nd = max(dot(viewNormal, v / vLen), 0.0);
      float atten = 1.0 - clamp(vLen / (radius * 2.8), 0.0, 1.0);
      #if AO_MODE == 1
         nd = nd * sqrt(nd);
      #endif
      float w = atten * edgeW;
      occ += nd * w;
      weight += w;
   }

   float ao = 1.0;
   if (weight > 1.0e-3) {
      ao = 1.0 - clamp((occ / weight) * AO_STRENGTH, 0.0, 0.92);
   }
   return mix(1.0, ao, clamp(1.0 - dist / 96.0, 0.0, 1.0));
}

#endif
