#ifndef RF_WATER_GBUFFER_REFLECTION_GLSL
#define RF_WATER_GBUFFER_REFLECTION_GLSL

#ifndef COLORTEX8_UNIFORM
#define COLORTEX8_UNIFORM
uniform sampler2D colortex8;
#endif

vec3 rfWaterPassReflection(vec3 viewPos, vec3 viewN, vec3 viewDir) {
   vec3 R = normalize(reflect(viewDir, viewN));
   vec3 sky = getSkyColor(R);

   vec3 pos = viewPos + viewN * 0.10;
   vec3 stepV = R * 0.75;
   for (int i = 0; i < 18; i++) {
      pos += stepV;
      stepV *= 1.42;
      vec2 uv = view2screen(pos).xy;
      if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
         break;
      }

      float hitZ = texture2D(depthtex1, uv).x;
      if (hitZ >= 1.0) {
         continue;
      }

      vec3 hitView = screen2view(uv, hitZ);
      float err = abs(hitView.z - pos.z);
      if (err < max(0.40, length(stepV) * 0.60) && length(hitView) > length(viewPos) + 0.45) {
         vec3 hitCol = texture2D(colortex8, uv).rgb;
         if (dot(hitCol, vec3(1.0)) > 0.004) {
            return hitCol;
         }
      }
   }
   return sky;
}

#endif
