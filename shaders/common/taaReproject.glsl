#ifndef RF_TAA_REPROJECT_GLSL
#define RF_TAA_REPROJECT_GLSL

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

vec2 rfTaaReproject(vec2 uv, float depth, bool useDh) {
   vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
   vec4 viewPos;
   #ifdef DISTANT_HORIZONS
      if (useDh) {
         viewPos = dhProjectionInverse * vec4(ndc, 1.0);
      } else {
         viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
      }
   #else
      viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
   #endif
   viewPos /= viewPos.w;

   vec4 feetPos = gbufferModelViewInverse * viewPos;
   float moveCam = float(depth < 0.9995 || useDh);
   feetPos.xyz += (cameraPosition - previousCameraPosition) * moveCam;

   vec4 prevView = gbufferPreviousModelView * feetPos;
   vec4 prevClip;
   #ifdef DISTANT_HORIZONS
      if (useDh) {
         prevClip = dhPreviousProjection * prevView;
      } else {
         prevClip = gbufferPreviousProjection * prevView;
      }
   #else
      prevClip = gbufferPreviousProjection * prevView;
   #endif

   return prevClip.xy / max(prevClip.w, 1.0e-4) * 0.5 + 0.5;
}

#endif
