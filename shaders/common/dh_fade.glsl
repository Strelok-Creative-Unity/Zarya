#ifndef DH_FADE_GLSL
#define DH_FADE_GLSL

#ifndef DH_SEAM_MARGIN
   #define DH_SEAM_MARGIN 28.0
#endif
#ifndef DH_SEAM_WIDTH
   #define DH_SEAM_WIDTH 36.0
#endif

float dhViewerDistance(vec3 pos) {
   float horiz = length(pos.xz);
   float eucl = length(pos);
   return mix(eucl, horiz, 0.38);
}

// MIT ref: David Hoskins — Hash without Sine (hash12)
// Source: https://www.shadertoy.com/view/4djSRW
// License text: THIRD_PARTY_NOTICES.md
float dhSeamNoise(vec2 p) {
   vec3 m = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
   m += dot(m, m.yzx + 33.33);
   return fract((m.x + m.y) * m.z);
}

float getDhLodReveal(vec3 feetPos) {
   float dist = dhViewerDistance(feetPos);
   float bandEnd = max(far * 0.94 - DH_SEAM_MARGIN, 12.0);
   float bandStart = max(bandEnd - max(DH_SEAM_WIDTH, 6.0), 0.0);
   return smoothe(rescale(dist, bandStart, bandEnd));
}

bool discardHiddenLod(vec3 feetPos) {
   float reveal = getDhLodReveal(feetPos);
   #ifdef DH_SEAM_DITHER
      return reveal < dhSeamNoise(gl_FragCoord.xy);
   #else
      return reveal < 0.5;
   #endif
}

float getWaterLodMix(vec3 feetPos) {
   float d = mix(length(feetPos), length(feetPos.xz), 0.25);
   return smoothe(rescale(d, far * 0.58, far * 0.86));
}

#endif
