#include "/shader.h"

uniform sampler2D colortex0;

varying vec2 texUV;

void main() {
   /* DRAWBUFFERS:8 */
   /* RENDERTARGETS: 8 */
   gl_FragData[0] = texture2D(colortex0, texUV);
}
