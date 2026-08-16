#include "/shader.h"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
#define RAIN_STRENGTH_UNIFORM

#ifndef EYE_BRIGHTNESS_SMOOTH_UNIFORM
#define EYE_BRIGHTNESS_SMOOTH_UNIFORM
uniform ivec2 eyeBrightnessSmooth;
#endif

#ifndef SUN_POSITION_UNIFORM
#define SUN_POSITION_UNIFORM
uniform vec3 sunPosition;
#endif

#ifdef AUTO_EXPOSURE
   const bool colortex2Clear = false;
   uniform float frameTime;
#endif

varying vec2 texUV;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/getColorGrade.glsl"
#include "/common/sharpen.glsl"

#ifdef FXAA
   #include "/common/fxaa.glsl"
#endif

#ifdef AUTO_EXPOSURE
   #include "/common/tonemap.glsl"
#endif

void main() {
   vec4 color = texture2D(colortex0, texUV);

   #ifdef FXAA
      color.rgb = rfFxaa(colortex0, texUV, color.rgb, float(SHARPEN_STRENGTH));
   #else
      color.rgb = rfSharpen(colortex0, texUV, color.rgb, float(SHARPEN_STRENGTH));
   #endif

   float exposureEv = 1.0;
   float exposureTarget = 1.0;
   #ifdef AUTO_EXPOSURE
      float prevEv = texture2D(colortex2, vec2(0.5 / viewWidth, 0.5 / viewHeight)).a;
      vec2 eye01 = vec2(eyeBrightnessSmooth) / 240.0;
      float sunUp = 0.0;
      #ifdef OVERWORLD
         sunUp = view2feet(sunPosition).y;
      #elif defined THE_NETHER
         sunUp = -1.0;
      #elif defined THE_END
         sunUp = -0.25;
      #endif
      float standL = standIllumination(eye01, sunUp, rainStrength);
      vec2 ae = autoExposure(standL, prevEv, max(frameTime, 1.0 / 60.0));
      exposureEv = ae.x;
      exposureTarget = ae.y;
      color.rgb *= exposureEv;
   #endif

   color.rgb = applyColorGrade(color.rgb);

   #ifdef AUTO_EXPOSURE
      color.rgb = applyLightBleed(color.rgb, exposureEv, exposureTarget);
   #endif

   /* DRAWBUFFERS:02 */
   gl_FragData[0] = color;
   gl_FragData[1] = vec4(color.rgb, exposureEv);
}
