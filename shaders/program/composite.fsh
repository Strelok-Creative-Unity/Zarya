#include "/shader.h"

uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

varying vec2 texUV;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/dh.glsl"
#ifdef VOXY
   #include "/common/voxy.glsl"
#endif
#include "/common/ssao.glsl"

void main() {
   vec4 color = texture2D(colortex0, texUV);

   #ifdef SSAO
      float depth = texture2D(depthtex0, texUV).x;
      bool sky = depth >= 1.0;
      #ifdef DISTANT_HORIZONS
         float dhDepth = texture2D(dhDepthTex0, texUV).x;
         sky = sky && dhDepth >= 1.0;
      #endif
      #ifdef VOXY
         float vxDepth = vxSampleClosestDepth(texUV);
         sky = sky && !isVxDepthValid(vxDepth);
      #endif

      if (!sky) {
         bool useLod = false;
         vec3 viewPos = sampleViewPos(texUV, false);
         #ifdef DISTANT_HORIZONS
            if (depth >= 1.0 && dhDepth < 1.0) {
               useLod = true;
               viewPos = dhScreenToView(texUV, dhDepth);
            }
         #endif
         #ifdef VOXY
            if (isVxLodSurface(depth, vxDepth)) {
               useLod = true;
               viewPos = vxScreenToView(texUV, vxDepth);
            }
         #endif

         vec3 prenormal = screen2ndc(texture2D(colortex6, texUV).xyz);
         vec3 viewN = squaredLength(prenormal) > 0.01
            ? normalize(mat3(gbufferModelView) * prenormal)
            : -normalize(viewPos);
         #if defined VOXY && !defined DISTANT_HORIZONS
            if (useLod && squaredLength(prenormal) > 0.01) {
               viewN = normalize(mat3(vxModelView) * prenormal);
            }
         #endif

         float ao = computeSSAO(texUV, viewPos, viewN, useLod);
         color.rgb *= ao;
      }
   #endif

   /* DRAWBUFFERS:0 */
   gl_FragData[0] = color;
}
