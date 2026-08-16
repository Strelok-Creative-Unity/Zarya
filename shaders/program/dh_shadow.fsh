#include "/shader.h"

varying float overdrawKeep;
flat varying float isWater;

void main() {
   #ifndef DH_SHADOW_ENABLED
      discard;
   #endif

   if (isWater > 0.5 || overdrawKeep < 0.001) {
      discard;
   }

   gl_FragData[0] = vec4(1.0);
}
