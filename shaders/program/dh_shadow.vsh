#include "/shader.h"

varying float overdrawKeep;
flat varying float isWater;

#include "/common/math.glsl"
#include "/common/getShadowDistortion.glsl"

uniform float far;
uniform mat4 shadowModelViewInverse;

#ifndef DH_BLOCK_WATER
   #define DH_BLOCK_WATER 8
#endif

void main() {
   gl_Position = ftransform();
   gl_Position.xyz = getShadowDistortion(gl_Position.xyz);

   vec3 shadowView = (gl_ModelViewMatrix * gl_Vertex).xyz;
   vec3 feetPos = (shadowModelViewInverse * vec4(shadowView, 1.0)).xyz;
   float dist = mix(length(feetPos), length(feetPos.xz), 0.38);
   float bandEnd = max(far * 0.94 - DH_SEAM_MARGIN, 12.0);
   float bandStart = max(bandEnd - max(DH_SEAM_WIDTH, 6.0), 0.0);

   overdrawKeep = smoothe(rescale(dist, bandStart, bandEnd));
   isWater = float(dhMaterialId == DH_BLOCK_WATER);
}
