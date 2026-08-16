#define GBUFFERS_SKYBASIC

#include "/shader.h"

uniform int isEyeInWater;

varying float fogMix;
varying float isVanillaStar;
varying vec4 color;

#ifdef IS_IRIS
uniform int renderStage;
#endif

#include "/common/math.glsl"
#include "/common/getFogMix.vsh"

void main() {
   gl_Position = ftransform();

   fogMix = getFogMix(vec3(9999999999.0));
   color = gl_Color;

   #ifdef IS_IRIS
      isVanillaStar = float(renderStage == MC_RENDER_STAGE_STARS);
   #else
      isVanillaStar = float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0 && gl_Color.r < 0.51);
   #endif
}
