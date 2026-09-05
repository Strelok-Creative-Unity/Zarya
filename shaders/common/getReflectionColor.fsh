#define SSR_BINARY_Z_CUTOFF 16.0

float getReflectionVignette(vec2 uv) {
   uv.y = min(uv.y, 1.0 - uv.y);
   uv.x *= 1.0 - uv.x;
   uv.y *= uv.y;

   return 1.0 - pow(1.0 - uv.x, 50.0*uv.y);
}

vec3 reflectionScreenToView(vec2 uv, float depth, bool useLod) {
   #if defined VOXY && !defined DISTANT_HORIZONS
      return useLod ? vxScreenToView(uv, depth) : screen2view(uv, depth);
   #elif defined DISTANT_HORIZONS
      return useLod ? dhScreenToView(uv, depth) : screen2view(uv, depth);
   #else
      return screen2view(uv, depth);
   #endif
}

vec3 reflectionViewToScreen(vec3 view, bool useLod) {
   #if defined VOXY && !defined DISTANT_HORIZONS
      return useLod ? vxViewToScreen(view) : view2screen(view);
   #elif defined DISTANT_HORIZONS
      return useLod ? dhViewToScreen(view) : view2screen(view);
   #else
      return view2screen(view);
   #endif
}

void sampleSceneDepth(vec2 uv, out float depth, out bool useLod) {
   depth = texture2D(depthtex0, uv).x;
   useLod = false;

   #ifdef DISTANT_HORIZONS
      float dhDepth = texture2D(dhDepthTex0, uv).x;
      if (isDhLodSurface(depth, dhDepth)) {
         depth = dhDepth;
         useLod = true;
         return;
      }
   #endif

   #ifdef VOXY
      float vxDepth = vxSampleClosestDepth(uv);
      if (isVxLodSurface(depth, vxDepth)) {
         depth = vxDepth;
         useLod = true;
      }
   #endif
}

void sampleReflectionHit(vec2 uv, out float depth, out bool useLod) {
   depth = texture2D(depthtex0, uv).x;
   useLod = false;

   #ifdef DISTANT_HORIZONS
      if (depth >= 1.0) {
         float dhSolid = texture2D(dhDepthTex1, uv).x;
         if (dhSolid < 1.0) {
            depth = dhSolid;
            useLod = true;
            return;
         }
      }
   #endif

   #ifdef VOXY
      if (depth >= 1.0) {
         float vxSolid = vxSampleOpaqueDepth(uv);
         if (isVxDepthValid(vxSolid)) {
            depth = vxSolid;
            useLod = true;
         }
      }
   #endif
}

vec3 reflectionHitToOriginView(vec2 uv, float depth, bool hitIsLod, bool originIsLod) {
   vec3 hitNative = reflectionScreenToView(uv, depth, hitIsLod);

   #if defined VOXY && !defined DISTANT_HORIZONS
      if (hitIsLod == originIsLod) {
         return hitNative;
      }
      vec3 feet = hitIsLod ? vxViewToFeet(hitNative) : view2feet(hitNative);
      return originIsLod ? vxFeetToView(feet) : feet2view(feet);
   #else
      return hitNative;
   #endif
}

vec4 getReflectionColor(float depth, vec3 normal, vec3 viewPos, bool originIsLod, float roughness) {
   vec3 V = normalize(viewPos);
   vec3 R = normalize(reflect(V, normal));

   if (R.z >= -0.05) return vec4(0.0);

   float fresnel = 1.0 - dot(normal, -V);
   float grazingEpsilon = rescale(1.0 - abs(dot(R, normal)), 0.95, 1.0);
   float invR = 1.0 / abs(R.z);
   float sceneFar = far;
   #if defined VOXY && !defined DISTANT_HORIZONS
      if (originIsLod) {
         sceneFar = vxFarPlane();
      }
   #endif
   float invFar = 1.0 / (2.0 * sceneFar);
   float lengthR = 1.0;
   float originDist = length(viewPos);
   vec3 oldPos = viewPos;
   int maxSteps = int(mix(float(SSR_MAX_STEPS), 8.0, clamp(roughness * 1.15, 0.0, 1.0)));
   int binSteps = int(mix(float(SSR_BINARY_STEPS), 3.0, clamp(roughness, 0.0, 1.0)));

   for (int i = 0; i < SSR_MAX_STEPS; i++) {
      if (i >= maxSteps) {
         break;
      }
      vec3 curPos = viewPos + R * lengthR;
      vec2 curUV  = reflectionViewToScreen(curPos, originIsLod).st;

      if (curUV.s < 0.0 || curUV.s > 1.0 || curUV.t < 0.0 || curUV.t > 1.0)
         break;

      float sceneDepth;
      bool hitIsLod;
      sampleReflectionHit(curUV, sceneDepth, hitIsLod);

      if (sceneDepth >= 1.0) {
         oldPos = curPos;
         lengthR += max(SSR_STEP_SIZE, 1.0);
         continue;
      }

      vec3 hitView = reflectionHitToOriginView(curUV, sceneDepth, hitIsLod, originIsLod);
      float sceneZ = hitView.z;
      float distanceEpsilon = clamp(abs(sceneZ) * invFar, 0.0, 1.0);
      float epsilon = 1.0 + 0.1 * max(distanceEpsilon, grazingEpsilon);
      float diffZ = curPos.z - sceneZ * epsilon;

      if (diffZ < 0.0) {
         vec3 a = oldPos;
         vec3 b = curPos;

         if (diffZ > -SSR_BINARY_Z_CUTOFF) {
            for (int j = 0; j < SSR_BINARY_STEPS; j++) {
               if (j >= binSteps) {
                  break;
               }
               curPos = (a + b) * 0.5;
               curUV = reflectionViewToScreen(curPos, originIsLod).st;
               sampleReflectionHit(curUV, sceneDepth, hitIsLod);
               hitView = reflectionHitToOriginView(curUV, sceneDepth, hitIsLod, originIsLod);
               sceneZ = hitView.z;

               if (-curPos.z < -sceneZ) { a = curPos; }
               else                     { b = curPos; }
            }
         }

         float hitDist = length(hitView);
         if (hitDist + 3.0 < originDist || dot(hitView - viewPos, normal) <= 0.0) {
            return vec4(0.0);
         }

         return vec4(texture2D(colortex0, curUV).rgb,
                     getReflectionVignette(curUV) * fresnel);
      }

      oldPos = curPos;
      lengthR += max(SSR_STEP_SIZE * abs(diffZ) * invR, 1.0);
   }

   return vec4(0.0);
}
