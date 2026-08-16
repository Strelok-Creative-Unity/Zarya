#include "/shader.h"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform int isEyeInWater;

#ifndef RAIN_STRENGTH_UNIFORM
#define RAIN_STRENGTH_UNIFORM
uniform float rainStrength;
#endif

#ifdef OVERWORLD
   uniform vec3 shadowLightPosition;
   uniform mat4 shadowModelView;
   uniform mat4 shadowProjection;
   uniform sampler2D shadowtex1;
#endif

varying vec2 texUV;
#ifdef OVERWORLD
   varying vec3 lightColor;
#endif

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/dh.glsl"

#if defined OVERWORLD && defined ENABLE_SHADOWS && defined VL
   #include "/common/getShadowDistortion.glsl"
#endif

#if defined VL && defined OVERWORLD && defined ENABLE_SHADOWS
   #include "/common/volumetrics.glsl"
#endif

void main() {
   vec4 color = texture2D(colortex0, texUV);

   if (isEyeInWater == 0) {
      #if defined VL && defined OVERWORLD && defined ENABLE_SHADOWS
      {
         float depth = texture2D(depthtex0, texUV).x;
         vec3 viewPos;

         #ifdef DISTANT_HORIZONS
            float dhDepth = texture2D(dhDepthTex0, texUV).x;
            if (isDhLodSurface(depth, dhDepth)) {
               viewPos = dhScreenToView(texUV, dhDepth);
            } else
         #endif
         {
            if (depth >= 1.0) {
               viewPos = screen2view(texUV, 0.999);
               viewPos = normalize(viewPos) * min(far * 0.85, 220.0);
            } else {
               viewPos = screen2view(texUV, depth);
            }
         }

         color.rgb += computeVolumetrics(viewPos, lightColor);
      }
      #endif
   }

   /* DRAWBUFFERS:0 */
   gl_FragData[0] = color;
}
