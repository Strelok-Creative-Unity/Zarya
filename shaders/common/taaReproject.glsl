#ifndef RF_TAA_REPROJECT_GLSL
#define RF_TAA_REPROJECT_GLSL

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

vec2 rfTaaReproject(vec2 uv, float depth, bool useDh, bool useVx) {
   vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
   vec4 viewPos;
   #ifdef DISTANT_HORIZONS
      if (useDh) {
         viewPos = dhProjectionInverse * vec4(ndc, 1.0);
      } else
   #endif
   #ifdef VOXY
      if (useVx) {
         viewPos = vxProjInv * vec4(ndc, 1.0);
      } else
   #endif
   {
      viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
   }
   viewPos /= viewPos.w;

   vec4 feetPos;
   #ifdef VOXY
      if (useVx) {
         feetPos = vxModelViewInv * viewPos;
      } else
   #endif
   {
      feetPos = gbufferModelViewInverse * viewPos;
   }
   float moveCam = float(depth < 0.9995 || useDh || useVx);
   feetPos.xyz += (cameraPosition - previousCameraPosition) * moveCam;

   vec4 prevView;
   #ifdef VOXY
      if (useVx) {
         prevView = vxModelViewPrev * feetPos;
      } else
   #endif
   {
      prevView = gbufferPreviousModelView * feetPos;
   }
   vec4 prevClip;
   #ifdef DISTANT_HORIZONS
      if (useDh) {
         prevClip = dhPreviousProjection * prevView;
      } else
   #endif
   #ifdef VOXY
      if (useVx) {
         prevClip = vxProjPrev * prevView;
      } else
   #endif
   {
      prevClip = gbufferPreviousProjection * prevView;
   }

   return prevClip.xy / max(prevClip.w, 1.0e-4) * 0.5 + 0.5;
}

#endif
