vec3 getLightColor(float sunHeight, float skyLight) {
   float sunRedness = 1.0 - clamp(0.2*sunHeight - 3.929, 0.0, 1.0);

   vec3 lightColor = sunHeight > 0.01 ? normalize(vec3(1.0 + clamp(sunRedness, 0.12, 1.0), 1.00, 0.86))
                                      : MOON_COLOR * 0.62;

   #ifdef OVERWORLD
      float sunUp = dot(normalize(sunPosition), gbufferModelView[1].xyz);
      float sunset = exp(-sunUp * sunUp * 22.0) * smoothstep(-0.32, 0.02, sunUp) * SUNSET_INTENSITY;
      lightColor = mix(lightColor, vec3(1.0, 0.42, 0.16), clamp(sunset * 0.62, 0.0, 1.0));
   #endif

   lightColor = mix(vec3(luma(lightColor)), lightColor, 1.16);
   return mix(vec3(luma(lightColor)), lightColor, mix(0.62, 1.0, skyLight));
}