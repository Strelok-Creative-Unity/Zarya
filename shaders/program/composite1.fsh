#include "/shader.h"

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
#ifndef DEPTHTEX1_UNIFORM
#define DEPTHTEX1_UNIFORM
uniform sampler2D depthtex1;
#endif
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
#endif

varying vec2 texUV;
#ifdef OVERWORLD
   varying vec3 lightColor;
#endif

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/dh.glsl"
#ifdef VOXY
   #include "/common/voxy.glsl"
#endif

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
         float depth1 = texture2D(depthtex1, texUV).x;
         vec3 viewPos;
         bool gotLod = false;

         #ifdef DISTANT_HORIZONS
            float dhDepth = texture2D(dhDepthTex0, texUV).x;
            if (isDhLodVisible(depth, depth1, dhDepth)) {
               viewPos = dhScreenToView(texUV, dhDepth);
               gotLod = true;
            }
         #endif
         #ifdef VOXY
            if (!gotLod) {
               float vxDepth = vxSampleClosestDepth(texUV);
               if (isVxLodVisible(depth, depth1, vxDepth)) {
                  viewPos = vxScreenToVanillaView(texUV, vxDepth);
                  gotLod = true;
               }
            }
         #endif
         if (!gotLod) {
            if (depth >= 1.0 || depth1 >= 1.0) {
               viewPos = screen2view(texUV, 0.999);
               viewPos = normalize(viewPos) * min(far * 0.85, 220.0);
            } else {
               viewPos = screen2view(texUV, depth1);
            }
         }

         color.rgb += computeVolumetrics(viewPos, lightColor);
      }
      #endif
   }

   /* DRAWBUFFERS:0 */
   gl_FragData[0] = color;
}
