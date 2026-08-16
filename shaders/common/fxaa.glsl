#ifndef RF_FXAA_GLSL
#define RF_FXAA_GLSL

// MIT ref: Simon Rodriguez — FXAA 3.11 compact
// Source: https://github.com/kosua20/Rendu/blob/master/resources/common/shaders/screens/fxaa.frag
// BSD ref: NVIDIA FXAA 3.11 (Timothy Lottes)
// License text: THIRD_PARTY_NOTICES.md

float rfFxaaLuma(vec3 c) {
   return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 rfFxaa(sampler2D tex, vec2 uv, vec3 color, float sharpenAmount) {
   vec2 texel = 1.0 / vec2(viewWidth, viewHeight);

   vec3 rgbN = texture2D(tex, uv + vec2( 0.0, -1.0) * texel).rgb;
   vec3 rgbS = texture2D(tex, uv + vec2( 0.0,  1.0) * texel).rgb;
   vec3 rgbW = texture2D(tex, uv + vec2(-1.0,  0.0) * texel).rgb;
   vec3 rgbE = texture2D(tex, uv + vec2( 1.0,  0.0) * texel).rgb;

   float lumaM = rfFxaaLuma(color);
   float lumaN = rfFxaaLuma(rgbN);
   float lumaS = rfFxaaLuma(rgbS);
   float lumaW = rfFxaaLuma(rgbW);
   float lumaE = rfFxaaLuma(rgbE);

   float lumaMin = min(lumaM, min(min(lumaN, lumaS), min(lumaW, lumaE)));
   float lumaMax = max(lumaM, max(max(lumaN, lumaS), max(lumaW, lumaE)));
   float range = lumaMax - lumaMin;
   if (range < max(0.0312, lumaMax * 0.125)) {
      return rfSharpenFromNeighbors(color, rgbN, rgbS, rgbW, rgbE, sharpenAmount);
   }

   float lumaNw = rfFxaaLuma(texture2D(tex, uv + vec2(-1.0, -1.0) * texel).rgb);
   float lumaNe = rfFxaaLuma(texture2D(tex, uv + vec2( 1.0, -1.0) * texel).rgb);
   float lumaSw = rfFxaaLuma(texture2D(tex, uv + vec2(-1.0,  1.0) * texel).rgb);
   float lumaSe = rfFxaaLuma(texture2D(tex, uv + vec2( 1.0,  1.0) * texel).rgb);

   float lumaNs = lumaN + lumaS;
   float lumaWe = lumaW + lumaE;
   float edgeHorz = abs(-2.0 * lumaW + lumaNw + lumaSw)
                  + abs(-2.0 * lumaM + lumaNs) * 2.0
                  + abs(-2.0 * lumaE + lumaNe + lumaSe);
   float edgeVert = abs(-2.0 * lumaN + lumaNw + lumaNe)
                  + abs(-2.0 * lumaM + lumaWe) * 2.0
                  + abs(-2.0 * lumaS + lumaSw + lumaSe);
   bool horz = edgeHorz >= edgeVert;

   float luma1 = horz ? lumaN : lumaW;
   float luma2 = horz ? lumaS : lumaE;
   float grad1 = luma1 - lumaM;
   float grad2 = luma2 - lumaM;
   bool steep1 = abs(grad1) >= abs(grad2);
   float gradient = 0.25 * max(abs(grad1), abs(grad2));

   float stepLen = horz ? texel.y : texel.x;
   float lumaLocal = steep1 ? 0.5 * (luma1 + lumaM) : 0.5 * (luma2 + lumaM);
   if (steep1) {
      stepLen = -stepLen;
   }

   vec2 edgeUv = uv;
   if (horz) {
      edgeUv.y += stepLen * 0.5;
   } else {
      edgeUv.x += stepLen * 0.5;
   }

   vec2 offset = horz ? vec2(texel.x, 0.0) : vec2(0.0, texel.y);
   vec2 posN = edgeUv - offset;
   vec2 posP = edgeUv + offset;
   float lumaEndN = rfFxaaLuma(texture2D(tex, posN).rgb) - lumaLocal;
   float lumaEndP = rfFxaaLuma(texture2D(tex, posP).rgb) - lumaLocal;
   bool doneN = abs(lumaEndN) >= gradient;
   bool doneP = abs(lumaEndP) >= gradient;

   if (!doneN) posN -= offset;
   if (!doneP) posP += offset;

   float q[8];
   q[0] = 1.5; q[1] = 2.0; q[2] = 2.0; q[3] = 2.0;
   q[4] = 2.0; q[5] = 4.0; q[6] = 8.0; q[7] = 8.0;

   for (int i = 0; i < 8; i++) {
      if (!doneN) {
         lumaEndN = rfFxaaLuma(texture2D(tex, posN).rgb) - lumaLocal;
         doneN = abs(lumaEndN) >= gradient;
         if (!doneN) posN -= offset * q[i];
      }
      if (!doneP) {
         lumaEndP = rfFxaaLuma(texture2D(tex, posP).rgb) - lumaLocal;
         doneP = abs(lumaEndP) >= gradient;
         if (!doneP) posP += offset * q[i];
      }
      if (doneN && doneP) {
         break;
      }
   }

   float distN = horz ? (uv.x - posN.x) : (uv.y - posN.y);
   float distP = horz ? (posP.x - uv.x) : (posP.y - uv.y);
   bool closerN = distN < distP;
   float dist = min(distN, distP);
   float span = distN + distP;
   float pixelOffset = -dist / max(span, 1.0e-5) + 0.5;

   bool lumaMLess = lumaM < lumaLocal;
   bool goodSpan = (closerN ? lumaEndN : lumaEndP) < 0.0 != lumaMLess;
   float edgeBlend = goodSpan ? pixelOffset : 0.0;

   float lumaAvg = (2.0 * (lumaNs + lumaWe) + lumaNw + lumaNe + lumaSw + lumaSe) / 12.0;
   float sub = clamp(abs(lumaAvg - lumaM) / max(range, 1.0e-5), 0.0, 1.0);
   float subSq = sub * sub;
   float subBlend = subSq * subSq * 0.75;

   float finalBlend = max(edgeBlend, subBlend);
   vec2 finalUv = uv;
   if (horz) {
      finalUv.y += finalBlend * stepLen;
   } else {
      finalUv.x += finalBlend * stepLen;
   }
   vec3 aa = texture2D(tex, finalUv).rgb;
   return rfSharpenFromNeighbors(aa, rgbN, rgbS, rgbW, rgbE, sharpenAmount);
}

#endif
