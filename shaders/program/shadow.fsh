uniform sampler2D gtexture;

varying vec2 texUV;
varying float alpha;
varying float shadowTint;
varying vec3 shadowVertColor;
varying vec3 shadowFilterColor;

void main() {
   vec4 albedo = texture2D(gtexture, texUV);

   albedo.a *= alpha;

   if (albedo.a < 0.1) {
      discard;
   }

   vec3 trans = albedo.rgb * shadowVertColor;
   trans = mix(trans, shadowFilterColor, 0.88);
   trans = mix(vec3(1.0), trans, pow(clamp(albedo.a, 0.0, 1.0), 0.22));

   float lum = dot(trans, vec3(0.22, 0.54, 0.24));
   trans = max(mix(vec3(lum), trans, 2.55), vec3(0.0));
   float lum2 = max(dot(trans, vec3(0.22, 0.54, 0.24)), 1.0e-4);
   trans *= mix(1.0, clamp(lum / lum2, 0.40, 1.25), 0.35);
   trans = clamp(trans, 0.0, 1.0);

   gl_FragData[0] = vec4(mix(vec3(1.0), trans, shadowTint), 1.0);
}
