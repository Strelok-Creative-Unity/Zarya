#ifndef GET_COLOR_GRADE
#define GET_COLOR_GRADE

vec3 applyColorGrade(vec3 color) {
   float l = luma(color);

   float warmth = clamp((color.r - color.b) * 2.0, 0.0, 1.0);
   float blockGlow = smoothstep(0.16, 0.55, l) * warmth;
   float highlight = max(smoothstep(0.58, 0.96, l), blockGlow);
   float exposure = mix(STYLE_EXPOSURE, mix(STYLE_EXPOSURE, 1.0, 0.35), highlight);
   color *= exposure;

   l = luma(color);
   color = mix(vec3(l), color, STYLE_SATURATION);

   float chroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
   color = mix(vec3(luma(color)), color, 1.0 + 0.14 * (1.0 - clamp(chroma * 2.4, 0.0, 1.0)));

   color = (color - 0.44) * STYLE_CONTRAST + 0.44;

   l = luma(color);
   float split = smoothstep(0.06, 0.50, l);
   color *= mix(vec3(0.94, 0.96, 1.05), vec3(1.03, 1.00, 0.96), split);

   #if defined THE_NETHER && defined NETHER_COLOR_GRADING
      l = luma(color);
      float midLift = mix(0.96, 0.86, smoothstep(0.38, 0.94, l));
      color *= midLift;
      float splitN = smoothstep(0.08, 0.55, luma(color));
      color *= mix(vec3(0.90, 0.86, 0.88), vec3(1.0), splitN);
      float shoulder = max(luma(color) - 0.68, 0.0);
      color *= 1.0 / (1.0 + shoulder * 1.85);
   #endif

   return max(color, vec3(0.0));
}

#endif
