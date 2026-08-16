#define GBUFFERS_SKYBASIC

#include "/shader.h"

uniform float viewHeight;
uniform float viewWidth;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform float rainStrength;
#define RAIN_STRENGTH_UNIFORM

varying float fogMix;
varying float isVanillaStar;
varying vec4 color;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/getSkyColor.glsl"
#include "/common/getWaterFog.glsl"

void main() {
	if (isVanillaStar > 0.5) {
		#ifdef SHADER_STARS
			discard;
		#else
			gl_FragData[0] = color;
			return;
		#endif
	}

	vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
	vec3 viewDir = normalize(screen2view(uv, 1.0));
	vec3 sky = getSkyColor(viewDir);

	float cave = 1.0 - smoothstep(16.0, 120.0, float(eyeBrightnessSmooth.y));
	sky = mix(sky, sky * 0.08, cave);

	if (isEyeInWater == 1) {
		float skyLight = float(eyeBrightnessSmooth.y) / 240.0;
		vec3 waterFog = getUnderwaterFogColor(skyLight);
		float up = max(dot(viewDir, gbufferModelView[1].xyz), 0.0);
		sky = mix(waterFog * 0.55, mix(waterFog, sky * 0.35, up * up), 0.65 + 0.35 * up);
	}

	sky += (random(gl_FragCoord.xy) - 0.5) / 255.0;
	sky = mix(sky, fogColor, fogMix);

	gl_FragData[0] = vec4(sky, 1.0);
}
