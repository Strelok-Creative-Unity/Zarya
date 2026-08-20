#ifndef END_FOG_GLSL
#define END_FOG_GLSL

#if defined END_FOG && defined THE_END

#ifndef END_FOG_STRENGTH
   #define END_FOG_STRENGTH 0.1
#endif
#ifndef END_FOG_DENSITY
   #define END_FOG_DENSITY 1.0
#endif
#ifndef END_FOG_SAMPLES
   #define END_FOG_SAMPLES 12
#endif

#ifndef FOG_COLOR_UNIFORM
#define FOG_COLOR_UNIFORM
uniform vec3 fogColor;
#endif

float endFogFar() {
   #ifdef DISTANT_HORIZONS
      return max(far, max(dhFarPlane, float(dhRenderDistance)));
   #else
      return far;
   #endif
}

float endFogDither(vec2 p) {
   vec3 m = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
   m += dot(m, m.yzx + 33.33);
   return fract((m.x + m.y) * m.z);
}

vec3 endFogAtmosColor() {
   vec3 biome = max(fogColor, vec3(0.02));
   float biomeL = max(luma(biome), 0.04);
   vec3 hue = biome / biomeL;
   vec3 violet = vec3(0.42, 0.22, 0.68);
   vec3 murk = mix(violet, hue, 0.42);
   murk = mix(murk, END_AMBIENT, 0.22);
   return murk * 0.16;
}

float endFogDensity(vec3 worldPos, float camDist) {
   float dens = mix(0.78, 1.08, smoothstep(0.0, 48.0, camDist));
   float voidLift = smoothstep(-24.0, 32.0, worldPos.y);
   dens *= mix(1.18, 0.92, voidLift);
   return dens * END_FOG_STRENGTH;
}

void computeEndFog(vec3 viewPos, bool sky, out vec3 scattering, out vec3 transmittance) {
   scattering = vec3(0.0);
   transmittance = vec3(1.0);

   float fogEnd = endFogFar();
   vec3 worldStart = cameraPosition;
   vec3 worldEnd = feet2world(view2feet(viewPos));
   vec3 worldDelta = worldEnd - worldStart;
   float rayLen = length(worldDelta);
   if (rayLen < 1e-3 && !sky) {
      return;
   }

   vec3 worldDir = (sky || rayLen < 1e-3)
      ? normalize(view2eye(viewPos))
      : worldDelta / rayLen;
   if (sky) {
      rayLen = fogEnd;
   } else {
      rayLen = min(rayLen, fogEnd);
   }

   float dither = endFogDither(gl_FragCoord.xy);
   float stepLen = rayLen / float(END_FOG_SAMPLES);
   vec3 atmos = endFogAtmosColor();
   float sigma = 0.0076 * END_FOG_DENSITY;
   vec3 extScale = vec3(0.86, 0.94, 1.12);

   vec3 T = vec3(1.0);
   vec3 scatter = vec3(0.0);

   for (int i = 0; i < END_FOG_SAMPLES; i++) {
      float t = (float(i) + 0.5 + (dither - 0.5) * 0.08) * stepLen;
      if (t >= rayLen) {
         continue;
      }

      vec3 worldPos = worldStart + worldDir * t;
      float dens = endFogDensity(worldPos, t) * stepLen;
      vec3 optical = vec3(sigma) * extScale * dens;
      vec3 stepT = exp(-optical);
      vec3 vis = ((1.0 - stepT) / max(optical, vec3(1e-6))) * T;

      scatter += vis * dens * atmos * sigma;
      T *= stepT;
   }

   T = clamp(T, vec3(0.0), vec3(1.0));
   vec3 lost = 1.0 - T;
   float sL = luma(scatter);
   vec3 fogCol = sL > 1e-5
      ? mix(atmos, scatter / sL * luma(atmos), 0.30)
      : atmos;
   scattering = lost * fogCol;
   transmittance = T;

   if (sky) {
      float up = clamp(worldDir.y, -1.0, 1.0);
      float skyFog = mix(0.28, 0.04, smoothstep(-0.12, 0.50, up));
      scattering *= skyFog;
      transmittance = mix(vec3(1.0), transmittance, skyFog);
   }
}

vec3 endFogViewPos(vec2 uv, out bool sky) {
   float depth = texture2D(depthtex0, uv).x;
   sky = depth >= 1.0;

   #ifdef DISTANT_HORIZONS
      float dhDepth = texture2D(dhDepthTex0, uv).x;
      if (isDhLodSurface(depth, dhDepth)) {
         sky = false;
         return dhScreenToView(uv, dhDepth);
      }
      sky = sky && dhDepth >= 1.0;
   #endif

   if (sky) {
      vec3 dir = normalize(screen2view(uv, 0.999));
      return dir * endFogFar();
   }

   return screen2view(uv, depth);
}

#endif
#endif
