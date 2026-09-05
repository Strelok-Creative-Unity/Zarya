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

#ifndef FRAME_TIME_COUNTER_UNIFORM
#define FRAME_TIME_COUNTER_UNIFORM
uniform float frameTimeCounter;
#endif

#ifndef EYE_BRIGHTNESS_SMOOTH_UNIFORM
#define EYE_BRIGHTNESS_SMOOTH_UNIFORM
uniform ivec2 eyeBrightnessSmooth;
#endif

#ifndef SUN_POSITION_UNIFORM
#define SUN_POSITION_UNIFORM
uniform vec3 sunPosition;
#endif

#if defined OVERWORLD && defined SHADER_CLOUDS && defined TAA
   #ifndef FRAME_COUNTER_UNIFORM
   #define FRAME_COUNTER_UNIFORM
   uniform int frameCounter;
   #endif
#endif

#ifdef OVERWORLD
   uniform vec3 shadowLightPosition;
   varying vec3 lightColor;
#endif

varying vec2 texUV;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/dh.glsl"
#ifdef VOXY
   #include "/common/voxy.glsl"
#endif

#if defined AIR_FOG && defined OVERWORLD && defined ENABLE_SHADOWS
   uniform mat4 shadowModelView;
   uniform mat4 shadowProjection;
   #include "/common/getShadowDistortion.glsl"
#endif

#if defined AIR_FOG && defined OVERWORLD
   #include "/common/airFog.glsl"
#endif

#if defined NETHER_FOG && defined THE_NETHER
   #include "/common/netherFog.glsl"
#endif

#if defined END_FOG && defined THE_END
   #include "/common/endFog.glsl"
#endif

#if defined OVERWORLD && defined SHADER_CLOUDS
   #define RF_CLOUD_DRAW
   #include "/common/shaderClouds.glsl"
#endif

void main() {
   vec4 color = texture2D(colortex0, texUV);

   if (isEyeInWater == 0) {
      #if defined OVERWORLD && defined SHADER_CLOUDS
      {
         float cloudDepth = texture2D(depthtex0, texUV).x;
         float cloudDepth1 = texture2D(depthtex1, texUV).x;
         vec3 cloudDir = normalize(screen2view(texUV, 0.999));
         float cloudMaxDist = max(max(CLOUD_LC_DISTANCE, CLOUD_MC_DISTANCE), CLOUD_UC_DISTANCE);
         bool cloudSky = cloudDepth >= 1.0;
         bool gotLod = false;

         #ifdef DISTANT_HORIZONS
            float cloudDhDepth = texture2D(dhDepthTex0, texUV).x;
            if (isDhLodVisible(cloudDepth, cloudDepth1, cloudDhDepth)) {
               float dhLen = length(dhScreenToView(texUV, cloudDhDepth));
               if (dhLen > 64.0 && dhLen < cloudMaxDist) {
                  cloudMaxDist = dhLen;
               }
               cloudSky = false;
               gotLod = true;
            }
         #endif

         #ifdef VOXY
            float cloudVxDepth = vxSampleClosestDepth(texUV);
            if (!gotLod && isVxLodVisible(cloudDepth, cloudDepth1, cloudVxDepth)) {
               float vxLen = length(vxScreenToVanillaView(texUV, cloudVxDepth));
               if (vxLen > 64.0 && vxLen < cloudMaxDist) {
                  cloudMaxDist = vxLen;
               }
               cloudSky = false;
               gotLod = true;
            }
         #endif

         if (!gotLod) {
            if (cloudDepth1 >= 1.0) {
               cloudSky = true;
            } else {
               cloudSky = false;
               cloudMaxDist = min(length(screen2view(texUV, cloudDepth1)), cloudMaxDist);
            }
         }

         vec3 cloudViewPos = cloudDir * cloudMaxDist;
         vec4 clouds = rfDrawClouds(cloudViewPos, cloudSky, lightColor);
         color.rgb = mix(color.rgb, clouds.rgb, clouds.a);
      }
      #endif

      #if defined AIR_FOG && defined OVERWORLD
      {
         bool fogSky;
         vec3 fogViewPos = airFogViewPos(texUV, fogSky);
         vec3 fogScatter;
         vec3 fogT;
         computeAirFog(fogViewPos, fogSky, lightColor, fogScatter, fogT);
         color.rgb = color.rgb * fogT + fogScatter;
      }
      #endif

      #if defined NETHER_FOG && defined THE_NETHER
      {
         color.rgb += netherLavaBloom(texUV);

         bool fogSky;
         vec3 fogViewPos = netherFogViewPos(texUV, fogSky);
         vec3 fogScatter;
         vec3 fogT;
         computeNetherFog(fogViewPos, fogSky, fogScatter, fogT);
         color.rgb = color.rgb * fogT + fogScatter;
      }
      #endif

      #if defined END_FOG && defined THE_END
      {
         bool fogSky;
         vec3 fogViewPos = endFogViewPos(texUV, fogSky);
         vec3 fogScatter;
         vec3 fogT;
         computeEndFog(fogViewPos, fogSky, fogScatter, fogT);
         color.rgb = color.rgb * fogT + fogScatter;
      }
      #endif
   }

   /* DRAWBUFFERS:0 */
   gl_FragData[0] = color;
}
