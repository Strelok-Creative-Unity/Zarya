#include "/shader.h"

#ifndef DH_WATER
attribute vec4 mc_Entity;
#endif

#ifndef FRAME_TIME_COUNTER_UNIFORM
#define FRAME_TIME_COUNTER_UNIFORM
uniform float frameTimeCounter;
#endif
uniform float rainStrength;
#define RAIN_STRENGTH_UNIFORM
uniform float screenBrightness;
uniform int isEyeInWater;
uniform int worldTime;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
#define SUN_POSITION_UNIFORM

varying float fogMix;
varying float reflectivity;
varying float waterTexStrength;
varying vec2 lightUV;
varying vec2 texUV;
varying vec3 feetPos;
varying vec3 gradientFogColor;
varying vec3 normal;
varying vec4 ambient;
varying vec4 color;

#ifdef VOXY
   varying float vanillaMix;
#endif

#ifdef DH_WATER
   varying float dhIsWater;
#endif

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/getFogMix.vsh"
#include "/common/getFogColor.vsh"
#include "/common/getAmbientColor.glsl"
#include "/common/getViewPosition.vsh"
#include "/common/getWaterTextureStrength.vsh"

#ifdef DH_WATER
   #define GET_DH_LIGHTMAP_UV
   #include "/common/dh_lightmap.glsl"

   uniform mat4 dhProjection;
#endif

void main() {
   #ifdef DH_WATER
      #ifndef DH_BLOCK_WATER
         #define DH_BLOCK_WATER 8
      #endif

      vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
      vec3 localPos = position.xyz;

      dhIsWater = 1.0;

      vec3 viewPos = (gbufferModelView * vec4(localPos, 1.0)).xyz;
      gl_Position = dhProjection * vec4(viewPos, 1.0);
      feetPos = localPos;
   #else
      gl_Position = ftransform();
   #endif

   float sunHeight = view2feet(sunPosition).y;

   color        = gl_Color;
   texUV        = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;

   #ifdef DH_WATER
      lightUV = getDhLightMapUV();
   #else
      lightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
   #endif

   normal       = gl_Normal;

   #if defined DH_WATER && !defined THE_END
      ambient = getDhAmbientColor(lightUV.t, sunHeight);
   #else
      ambient = getAmbientColor(lightUV.t, sunHeight);
   #endif

   reflectivity = GLASS_REFLECTIVITY;

   #ifdef GENERATED_SPECULAR
      reflectivity = max(reflectivity, 0.88);
   #endif

   #ifndef DH_WATER
      feetPos = view2feet(getViewPosition());
   #endif

   fogMix = getFogMix(feetPos);
   gradientFogColor = getFogColor(fogMix, feetPos);

   waterTexStrength = 1.0;

   float vertexAlpha = color.a;

   #ifndef DH_WATER
      if (mc_Entity.x != 10008.0) {
         ambient.rgb *= vertexAlpha;
      }
   #endif
   color.a = 1.0;

   #ifdef VOXY
      vanillaMix = calcFogMix(feetPos, 0.3, far);
   #endif

   #ifdef DH_WATER
      #ifndef THE_END
         ambient = getDhAmbientColor(AMBIENT_UV.t, sunHeight);
      #else
         ambient = getAmbientColor(AMBIENT_UV.t, sunHeight);
      #endif
      reflectivity = WATER_REFLECTIVITY;
      waterTexStrength = WATER_GLINT_CUTOFF;
   #else
      if (mc_Entity.x == 10008.0) {
         reflectivity = WATER_REFLECTIVITY;
         waterTexStrength = 1.0;
      }
   #endif

   normal = ndc2screen(normal);
}