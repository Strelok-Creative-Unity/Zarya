#include "/shader.h"

uniform float near;
uniform float far;
uniform int isEyeInWater;
#ifndef EYE_BRIGHTNESS_SMOOTH_UNIFORM
#define EYE_BRIGHTNESS_SMOOTH_UNIFORM
uniform ivec2 eyeBrightnessSmooth;
#endif
uniform float rainStrength;
#define RAIN_STRENGTH_UNIFORM
#ifndef FRAME_TIME_COUNTER_UNIFORM
#define FRAME_TIME_COUNTER_UNIFORM
uniform float frameTimeCounter;
#endif
uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform float viewWidth;
uniform float viewHeight;

#ifndef SUN_POSITION_UNIFORM
#define SUN_POSITION_UNIFORM
uniform vec3 sunPosition;
#endif

#ifdef OVERWORLD
   uniform vec3 shadowLightPosition;
   varying vec3 lightColor;
#endif

varying vec2 texUV;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/dh.glsl"
#include "/common/getReflectionColor.fsh"
#include "/common/getWaterSurface.glsl"
#include "/common/getWaterFog.glsl"

#ifdef OVERWORLD
   #include "/common/getSkyColor.glsl"
#endif

#if defined OVERWORLD && defined SHADER_CLOUDS
   #include "/common/shaderClouds.glsl"
#endif

#if defined OVERWORLD && defined DISTANT_HORIZONS && (defined DH_DEPTH_SHADOWS || defined DH_AO)
   #include "/common/dhScreenShadows.glsl"
#endif

void main() {
   vec4 color = texture2D(colortex0, texUV);

   vec4 matData = texture2D(colortex7, texUV);

   #ifdef GENERATED_SPECULAR
      float smoothness = matData.x;
      float metalness = matData.y;
      float roughness = 1.0 - smoothness;
   #else
      float smoothness = matData.x;
      float metalness = 0.0;
      float roughness = matData.y;
   #endif

   #ifdef GENERATED_SPECULAR
      bool doReflect = abs(matData.z - 0.5) < 0.01 && (
         (metalness > 0.45 && smoothness > 0.30) ||
         smoothness > 0.55
      );
   #else
      bool doReflect = smoothness > MIN_REFLECTIVITY && abs(matData.z - 0.5) < 0.01;
   #endif

   if (isEyeInWater == 1) {
      doReflect = false;
   }

   if (doReflect) {
      vec3 prenormal = screen2ndc(texture2D(colortex6, texUV).xyz);

      bool isWater = smoothness > 0.94 && metalness < 0.05;
      #ifndef GENERATED_SPECULAR
         isWater = smoothness > WATER_REFLECTIVITY - 0.05;
      #endif

      float depth;
      bool useDh;
      sampleSceneDepth(texUV, depth, useDh);

      vec3 normal  = eye2view(prenormal);
      vec3 viewPos = reflectionScreenToView(texUV, depth, useDh);

      vec3 viewDir = normalize(viewPos);
      float NoV = max(dot(normal, -viewDir), 0.0);
      float nv = clamp(1.0 - NoV, 0.0, 1.0);
      float fresnelTerm = nv * nv * nv * nv * nv;
      float waterFresnel = isWater ? mix(0.24, 1.0, fresnelTerm) : fresnelTerm;

      vec4 reflectionColor = getReflectionColor(depth, normal, viewPos, useDh, roughness);

      #ifdef OVERWORLD
         if (reflectionColor.a < 0.15) {
            vec3 reflected = reflect(viewDir, normal);
            float skyF = mix(isWater ? 0.22 : 0.08, 1.0, fresnelTerm);
            reflectionColor = vec4(getSkyColor(reflected), skyF);
            #ifdef SHADER_CLOUDS
               vec4 cloudHint = rfCloudSkyHint(reflected, lightColor);
               reflectionColor.rgb = mix(reflectionColor.rgb, cloudHint.rgb, cloudHint.a * 0.88);
            #endif
         }
      #endif

      #ifdef GENERATED_SPECULAR
         vec3 F0 = mix(vec3(0.04), vec3(0.95), metalness);
         vec3 fresnel = F0 + (max(vec3(smoothness), F0) - F0) * fresnelTerm;
         float amount = reflectionColor.a * smoothness * (0.12 * float(REFLECTIONS));
         float ipbrRefl = float(IPBR_REFLECTION_STRENGTH);
         if (metalness > 0.45) {
            color.rgb += reflectionColor.rgb * fresnel * amount * (1.25 * ipbrRefl);
         } else {
            color.rgb = mix(color.rgb, reflectionColor.rgb, clamp(amount * waterFresnel * (0.85 + 0.45 * ipbrRefl), 0.0, 0.90));
         }
      #else
         color.rgb = mix(
            color.rgb,
            reflectionColor.rgb,
            reflectionColor.a * smoothness * 0.1 * float(REFLECTIONS)
         );
      #endif

      #ifdef OVERWORLD
         float glintReflectivity = mix(smoothness, 1.0, metalness * 0.7);
         vec3 glint = getSunMoonGlint(viewPos, normal, roughness, glintReflectivity);
         #ifdef GENERATED_SPECULAR
            glint *= mix(1.0, 1.0 + 1.2 * float(IPBR_REFLECTION_STRENGTH), metalness);
         #else
            glint *= mix(1.0, 2.2, metalness);
         #endif
         color.rgb += glint;
      #endif
   }

   #ifdef WATER_FOG
      if (isEyeInWater == 1) {
         float depth;
         bool useDh;
         sampleSceneDepth(texUV, depth, useDh);
         vec3 viewPos = reflectionScreenToView(texUV, depth, useDh);
         if (depth >= 1.0 && !useDh) {
            viewPos = normalize(viewPos) * 48.0;
         }
         float skyLight = float(eyeBrightnessSmooth.y) / 240.0;

         vec3 feet = view2feet(viewPos);
         vec3 world = feet2world(feet);
         float soft = getWaterSoftFilm(world);
         vec3 viewUp = mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0);
         float lookUp = max(dot(normalize(viewPos), viewUp), 0.0);
         float nearSurface = exp(-length(viewPos) * 0.08);
         float glow = soft * skyLight * (0.18 + 0.55 * lookUp + 0.35 * nearSurface);
         color.rgb *= 1.0 + glow * 0.35;
         color.rgb += getWaterBaseTint() * glow * 0.12;

         color.rgb = applyUnderwaterFog(color.rgb, viewPos, skyLight);
      } else if (isEyeInWater == 2) {
         color.rgb = mix(color.rgb, vec3(0.85, 0.18, 0.04), 0.92);
      } else if (isEyeInWater == 3) {
         float depth;
         bool useDh;
         sampleSceneDepth(texUV, depth, useDh);
         float dist = length(reflectionScreenToView(texUV, depth, useDh));
         color.rgb = mix(color.rgb, vec3(0.72, 0.82, 0.92), clamp(dist * 0.08, 0.0, 0.95));
      }
   #endif

   #if defined OVERWORLD && defined DISTANT_HORIZONS && (defined DH_DEPTH_SHADOWS || defined DH_AO)
      if (isEyeInWater == 0) {
         float sceneDepth;
         bool useDh;
         sampleSceneDepth(texUV, sceneDepth, useDh);

         if (useDh || sceneDepth < 1.0) {
            vec3 viewPos = reflectionScreenToView(texUV, sceneDepth, useDh);
            vec3 prenormal = screen2ndc(texture2D(colortex6, texUV).xyz);
            vec3 viewN = squaredLength(prenormal) > 0.01
               ? normalize(mat3(gbufferModelView) * prenormal)
               : -normalize(viewPos);

            #ifdef DH_DEPTH_SHADOWS
               bool doContact = useDh || length(viewPos) > shadowDistance * 0.55;
               if (doContact) {
                  float lit = dhContactShadow(viewPos, viewN);
                  color.rgb *= mix(SHADOW_COLOR, vec3(1.0), lit);
               }
            #endif

            #ifdef DH_AO
               if (useDh) {
                  color.rgb *= dhScreenAo(texUV, viewPos, viewN, useDh);
               }
            #endif
         }
      }
   #endif

   /* DRAWBUFFERS:0 */
   gl_FragData[0] = color;
}
