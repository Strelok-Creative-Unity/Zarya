#include "/shader.h"

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

const bool colortex3Clear = false;
const bool colortex4Clear = false;

varying vec2 texUV;

#include "/common/math.glsl"
#include "/common/transformations.glsl"
#include "/common/dh.glsl"
#include "/common/taaResolve.glsl"

void main() {
   vec3 color = texture2D(colortex0, texUV).rgb;
   vec3 resolved = rfTaaResolveScene(color, texUV);

   /* DRAWBUFFERS:03 */
   gl_FragData[0] = vec4(resolved, 1.0);
   gl_FragData[1] = vec4(resolved, 1.0);
}
