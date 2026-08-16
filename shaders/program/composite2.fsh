#include "/shader.h"


uniform sampler2D colortex3;
varying vec2 texUV;

void main() {
   /* DRAWBUFFERS:4 */
   gl_FragData[0] = texture2D(colortex3, texUV);
}
