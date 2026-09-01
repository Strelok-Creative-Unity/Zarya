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

#include "/common/lpvCommon.glsl"

#if LPV_DEBUG_BOUNDS && defined LPV_ACTIVE
   uniform sampler2D depthtex0;

   vec3 rfLpvDebugOverlay(vec3 color, vec2 uv) {
      float depth = texture2D(depthtex0, uv).x;

      vec3 center  = floor(cameraPosition);
      vec3 halfSiz = 0.5 * LPV_VOLUME_SIZEF;
      vec3 lo      = center - halfSiz;
      vec3 hi      = center + halfSiz;

      vec3 p;
      if (depth < 1.0) {
         p = screen2world(uv, depth);
      } else {
         vec4 ndc = vec4(screen2ndc(vec3(uv, 1.0)), 1.0);
         vec3 viewDir  = normalize(nvec3(gbufferProjectionInverse * ndc));
         vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewDir);
         vec3 origin   = cameraPosition;

         vec3 invD = 1.0 / worldDir;
         vec3 t0   = (lo - origin) * invD;
         vec3 t1   = (hi - origin) * invD;
         vec3 tmin = min(t0, t1);
         vec3 tmax = max(t0, t1);
         float tNear = max(max(tmin.x, tmin.y), tmin.z);
         float tFar  = min(min(tmax.x, tmax.y), tmax.z);

         if (tNear > tFar || tFar < 0.0) {
            return color;
         }
         p = origin + worldDir * max(tNear, 0.0);
      }

      vec3  q    = abs(p - center) - halfSiz;
      float maxQ = max(q.x, max(q.y, q.z));
      float sd   = length(max(q, vec3(0.0))) + min(maxQ, 0.0);

      vec3  inD      = max(halfSiz - abs(p - center), vec3(0.0));
      float edgeDist = min(max(inD.x, inD.y), min(max(inD.x, inD.z), max(inD.y, inD.z)));

      float lineW = max(0.08, distance(p, cameraPosition) * 0.012);

      float edge = 1.0 - smoothstep(0.0, lineW, edgeDist);
      float face = 1.0 - smoothstep(0.0, lineW, abs(sd));

      vec3 boxCol = vec3(0.25, 1.0, 0.55);
      color = mix(color, boxCol * 2.0, edge);
      color = mix(color, boxCol * 0.15, face * (1.0 - edge));
      return color;
   }
#endif

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

   #if LPV_DEBUG_BOUNDS && defined LPV_ACTIVE
      color.rgb = rfLpvDebugOverlay(color.rgb, texUV);
   #endif

   /* DRAWBUFFERS:02 */
   gl_FragData[0] = color;
   gl_FragData[1] = vec4(color.rgb, exposureEv);
}
