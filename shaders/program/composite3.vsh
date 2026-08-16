#include "/shader.h"

#ifndef RAIN_STRENGTH_UNIFORM
#define RAIN_STRENGTH_UNIFORM
uniform float rainStrength;
#endif

#ifndef SUN_POSITION_UNIFORM
#define SUN_POSITION_UNIFORM
uniform vec3 sunPosition;
#endif

varying vec2 texUV;
#ifdef OVERWORLD
   varying vec3 lightColor;
#endif

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/getLightColor.vsh"

void main() {
   gl_Position = ftransform();
   texUV = gl_MultiTexCoord0.st;

   #ifdef OVERWORLD
      float sunHeight = view2feet(sunPosition).y;
      lightColor = getLightColor(sunHeight, 1.0);
   #endif
}
