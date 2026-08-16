#define GBUFFERS_SKYTEXTURED

#include "/shader.h"

uniform sampler2D gtexture;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

#if defined VANILLA_LIKE_SUN || defined VANILLA_LIKE_MOON
   uniform sampler2D suntex;
   uniform sampler2D moontex;
#endif

#ifdef IS_IRIS
   uniform int renderStage;
#endif

#ifndef MC_RENDER_STAGE_SUN
   #define MC_RENDER_STAGE_SUN 1
#endif
#ifndef MC_RENDER_STAGE_MOON
   #define MC_RENDER_STAGE_MOON 3
#endif
#ifndef MC_RENDER_STAGE_CUSTOM_SKY
   #define MC_RENDER_STAGE_CUSTOM_SKY 4
#endif

varying vec2 texUV;
varying vec3 viewPos;
varying vec4 color;

#include "/common/math.glsl"
#include "/common/transformations.glsl"

void main() {
   #ifdef IS_IRIS
      if (renderStage == MC_RENDER_STAGE_CUSTOM_SKY) {
         gl_FragData[0] = texture2D(gtexture, texUV) * color;
         return;
      }
   #endif

   vec3 viewDir = normalize(viewPos);

   bool isSun = dot(viewDir, normalize(sunPosition)) > 0.0;
   #ifdef IS_IRIS
      if (renderStage == MC_RENDER_STAGE_SUN) {
         isSun = true;
      }
   #endif

   if (isSun) {
      #ifdef VANILLA_LIKE_SUN
         vec4 albedo = texture2D(suntex, texUV) * color;
         if (albedo.a < 0.1) {
            discard;
         }
         float sunUp = dot(normalize(sunPosition), gbufferModelView[1].xyz);
         float sunset = exp(-sunUp * sunUp * 22.0) * smoothstep(-0.32, 0.02, sunUp);
         albedo.rgb *= mix(vec3(1.0), vec3(1.0, 0.72, 0.35), clamp(sunset * 0.55, 0.0, 1.0));
         gl_FragData[0] = albedo;
      #else
         discard;
      #endif
      return;
   }

   #ifdef VANILLA_LIKE_MOON
      vec4 albedo = texture2D(moontex, texUV) * color;
      if (albedo.a < 0.1) {
         discard;
      }
      albedo.rgb *= 0.82;
      gl_FragData[0] = albedo;
   #else
      vec4 albedo = texture2D(gtexture, texUV) * color;
      float VoM = clamp(dot(viewDir, normalize(moonPosition)), -1.0, 1.0);
      float ang = acos(VoM);
      float disc = 1.0 - smoothstep(0.026, 0.040, ang);
      if (disc < 0.01) {
         discard;
      }
      float lum = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
      albedo.a *= disc * smoothstep(0.015, 0.10, lum);
      if (albedo.a < 0.02) {
         discard;
      }
      albedo.rgb *= 0.88;
      albedo.rgb += vec3(0.025, 0.032, 0.05) * albedo.a;
      gl_FragData[0] = albedo;
   #endif
}
