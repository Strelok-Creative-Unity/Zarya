#define GBUFFERS_CLOUDS

#include "/shader.h"

uniform sampler2D gtexture;
uniform vec3 fogColor;
#define FOG_COLOR_UNIFORM
uniform vec3 sunPosition;
#define SUN_POSITION_UNIFORM
uniform vec3 moonPosition;
#define MOON_POSITION_UNIFORM

varying float fogMix;
varying float sunClosenessToHorizon;
varying vec2 texUV;
varying vec3 normalizedViewPos;
varying vec4 color;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/getSkyColor.glsl"

void main() {
   vec4 albedo = texture2D(gtexture, texUV) * color;
   float angleToLight = max(dot(normalizedViewPos, normalize(sunPosition)),
                            dot(normalizedViewPos, normalize(moonPosition)));
   float sunset = getSunsetFactor() * SUNSET_INTENSITY;
   vec3 atmos = getHorizonFogColor();

   albedo.a = mix(albedo.a, 0, fogMix);
   albedo.rgb = mix(albedo.rgb, atmos, mix(0.55, 0.72, clamp(sunset, 0.0, 1.0)));
   albedo.rgb = mix(albedo.rgb, vec3(1.0, 0.45, 0.18),
                    pow(max(dot(normalizedViewPos, normalize(sunPosition)), 0.0), 4.0)
                    * sunset * 0.4);
   albedo.a *= 1.0 - rescale(angleToLight, 0.96, 1.0) * sunClosenessToHorizon;

   /* DRAWBUFFERS:06 */
   gl_FragData[0] = albedo;
   gl_FragData[1] = vec4(vec3(0.0), 1.0);
}