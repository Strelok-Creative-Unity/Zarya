#ifndef RF_VOXY_GLSL
#define RF_VOXY_GLSL

#ifndef RF_VOXY_UNIFORMS
#define RF_VOXY_UNIFORMS
#ifndef VOXY_RANGE_UNIFORM
#define VOXY_RANGE_UNIFORM
uniform int vxRenderDistance;
#endif
uniform mat4 vxModelView;
uniform mat4 vxModelViewInv;
uniform mat4 vxModelViewPrev;
uniform mat4 vxProj;
uniform mat4 vxProjInv;
uniform mat4 vxProjPrev;
uniform sampler2D vxDepthTexOpaque;
uniform sampler2D vxDepthTexTrans;
#endif

float vxFarPlane() {
   return max(far, float(vxRenderDistance) * 16.0);
}

bool isVxDepthValid(float vxDepth) {
   return vxDepth > 1.0e-6 && vxDepth < 1.0;
}

bool isVxLodSurface(float mcDepth, float vxDepth) {
   return mcDepth >= 1.0 && isVxDepthValid(vxDepth);
}

bool isVxLodVisible(float depth0, float depth1, float vxDepth) {
   return isVxDepthValid(vxDepth) && (depth0 >= 1.0 || depth1 >= 1.0);
}

float vxSampleOpaqueDepth(vec2 uv) {
   float opaque = texture2D(vxDepthTexOpaque, uv).x;
   return isVxDepthValid(opaque) ? opaque : 1.0;
}

float vxSampleClosestDepth(vec2 uv) {
   float opaque = texture2D(vxDepthTexOpaque, uv).x;
   float trans  = texture2D(vxDepthTexTrans, uv).x;
   float best = 1.0;
   if (isVxDepthValid(opaque)) {
      best = opaque;
   }
   if (isVxDepthValid(trans)) {
      best = min(best, trans);
   }
   return best;
}

vec3 vxNdcToView(vec3 ndc) {
   return nvec3(vxProjInv * vec4(ndc, 1.0));
}

vec3 vxScreenToView(vec2 uv, float depth) {
   return vxNdcToView(screen2ndc(vec3(uv, depth)));
}

vec3 vxViewToNdc(vec3 view) {
   return nvec3(vxProj * vec4(view, 1.0));
}

vec3 vxViewToScreen(vec3 view) {
   return ndc2screen(vxViewToNdc(view));
}

vec3 vxViewToFeet(vec3 view) {
   return (vxModelViewInv * vec4(view, 1.0)).xyz;
}

vec3 vxFeetToView(vec3 feet) {
   return (vxModelView * vec4(feet, 1.0)).xyz;
}

vec3 vxToVanillaView(vec3 vxView) {
   return feet2view(vxViewToFeet(vxView));
}

vec3 vxVanillaToView(vec3 vanillaView) {
   return vxFeetToView(view2feet(vanillaView));
}

vec3 vxScreenToVanillaView(vec2 uv, float depth) {
   return vxToVanillaView(vxScreenToView(uv, depth));
}

bool vxFogSolidHit(vec2 uv, float depth0, float depth1, out vec3 vanillaView, out bool skyHit) {
   float opaque = vxSampleOpaqueDepth(uv);
   float closest = vxSampleClosestDepth(uv);
   bool solid = isVxDepthValid(opaque);
   bool anyLod = isVxDepthValid(closest);
   vanillaView = vec3(0.0);
   skyHit = false;

   if (depth0 >= 1.0 && solid) {
      vanillaView = vxScreenToVanillaView(uv, opaque);
      return true;
   }
   if (depth0 >= 1.0 && anyLod) {
      skyHit = true;
      return true;
   }
   if (depth1 >= 1.0 && solid) {
      vanillaView = vxScreenToVanillaView(uv, opaque);
      return true;
   }
   return false;
}

vec2 vxRemapLightMap(vec2 lightMap) {
   return clamp((lightMap - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, AMBIENT_UV.t));
}

#ifdef VOXY_PATCH
vec3 vxFaceNormalWorld(uint face) {
   vec3 n = vec3(
      float((face >> 1u) == 2u),
      float((face >> 1u) == 0u),
      float((face >> 1u) == 1u)
   );
   return n * (float(int(face) & 1) * 2.0 - 1.0);
}

vec3 vxAlbedoBumpNormal(vec3 albedo, vec3 worldNormal, vec3 feetPos) {
   #ifndef GENERATED_NORMALS
      return worldNormal;
   #else
      float dist = length(feetPos);
      float fade = 1.0 - smoothe(clamp((dist - far * 0.62) / max(far * 0.42, 8.0), 0.0, 1.0));
      if (fade < 0.02) {
         return worldNormal;
      }

      float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
      vec3 dpdx = dFdx(feetPos);
      vec3 dpdy = dFdy(feetPos);
      vec3 bump = worldNormal - (dpdx * dFdx(lum) + dpdy * dFdy(lum)) * (NORMAL_STRENGTH * 0.10);
      return normalize(mix(worldNormal, bump, fade));
   #endif
}

float vxAlbedoBumpShade(vec3 worldNormal, vec3 bumpNormal, vec3 feetPos) {
   #ifndef GENERATED_NORMALS
      return 1.0;
   #else
      float dist = length(feetPos);
      float fade = 1.0 - smoothe(clamp((dist - far * 0.62) / max(far * 0.42, 8.0), 0.0, 1.0));
      float flatUp = max(worldNormal.y * 0.5 + 0.5, 0.08);
      float bumpUp = clamp(bumpNormal.y * 0.5 + 0.5, 0.0, 1.0);
      return mix(1.0, clamp(bumpUp / flatUp, 0.58, 1.42), 0.55 * fade);
   #endif
}
#endif

#endif
