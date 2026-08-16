#define GBUFFERS_SKYTEXTURED

#include "/shader.h"

varying vec2 texUV;
varying vec3 viewPos;
varying vec4 color;

void main() {
   gl_Position = ftransform();
   texUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
   viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
   color = gl_Color;
}
