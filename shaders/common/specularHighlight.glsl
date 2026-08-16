
#ifndef SPECULAR_HIGHLIGHT_GLSL
#define SPECULAR_HIGHLIGHT_GLSL

vec3 ipbrSpecularHighlight(vec3 normalEye, vec3 viewPos, vec3 lightDir,
                           float smoothness, float metalness, vec3 albedo,
                           float lightStrength, vec3 lightColor) {
   if (smoothness < 0.05 || lightStrength < 0.01) {
      return vec3(0.0);
   }

   vec3 N = normalize(normalEye);
   vec3 V = normalize(-viewPos);
   vec3 L = normalize(lightDir);
   float NoL = max(dot(N, L), 0.0);
   if (NoL < 0.001) {
      return vec3(0.0);
   }

   vec3 H = normalize(L + V);
   float NoH = max(dot(N, H), 0.0);
   float VoH = max(dot(V, H), 0.0);
   float NoV = max(dot(N, V), 0.001);

   float rough = max(1.0 - smoothness, 0.04);
   float a = rough * rough;
   float a2 = max(a * a, 1e-4);

   float dDenom = NoH * NoH * (a2 - 1.0) + 1.0;
   float D = a2 / max(PI * dDenom * dDenom, 1e-6);

   float k = (rough + 1.0);
   k = k * k * 0.125;
   float G = (NoL / max(NoL * (1.0 - k) + k, 1e-6))
           * (NoV / max(NoV * (1.0 - k) + k, 1e-6));

   vec3 F0 = mix(vec3(0.04), max(albedo, vec3(0.04)), metalness);
   float fv = 1.0 - VoH;
   vec3 F = F0 + (1.0 - F0) * (fv * fv * fv * fv * fv);

   vec3 spec = (D * G * F) / max(4.0 * NoL * NoV, 1e-3);
   spec *= NoL * lightStrength * lightColor;
   spec *= smoothness * smoothness;

   spec *= mix(1.15, 2.4, metalness);

   return clamp(spec, vec3(0.0), vec3(6.0));
}

#endif
