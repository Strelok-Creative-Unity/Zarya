#ifndef RF_GLASS_TINT_GLSL
#define RF_GLASS_TINT_GLSL

bool rfIsGlassId(int id) {
   return id == 20018 || (id >= 21000 && id <= 21016);
}

vec3 rfGlassAlbedo(vec3 texRgb, vec3 vertRgb) {
   return clamp(texRgb * vertRgb, 0.0, 1.0);
}

vec3 rfGlassTransmit(vec3 texRgb, vec3 vertRgb, int id) {
   if (id == 20018) return vec3(1.0);
   if (id == 21016) return vec3(0.20);
   if (id == 21015) return vec3(0.12);
   if (id == 21000) return vec3(0.90);

   vec3 glassCol = rfGlassAlbedo(texRgb, vertRgb);
   float chroma = max(glassCol.r, max(glassCol.g, glassCol.b))
                - min(glassCol.r, min(glassCol.g, glassCol.b));
   vec3 tint = mix(vec3(1.0), glassCol, 0.38 + 0.22 * chroma);
   tint *= 0.82 / max(dot(tint, vec3(0.22, 0.54, 0.24)), 0.08);
   return clamp(tint, 0.18, 1.25);
}

vec3 rfGlassAbsorb(vec3 transmit) {
   return 1.0 - clamp(transmit, 0.0, 1.0);
}

vec3 rfApplyGlassTint(vec3 color, vec3 absorb) {
   return color * (1.0 - clamp(absorb, 0.0, 1.0));
}

vec4 rfGlassSurface(vec3 texRgb, vec3 vertRgb, vec3 ambient, float fresnel) {
   vec3 sheet = rfGlassAlbedo(texRgb, vertRgb) * ambient * 0.28;
   return vec4(sheet, clamp(0.014 + fresnel * 0.06, 0.010, 0.12));
}

#ifdef RF_GLASS_SAMPLER
#ifndef ATLAS_SIZE_UNIFORM
#define ATLAS_SIZE_UNIFORM
uniform ivec2 atlasSize;
#endif

vec2 rfGlassTileOrigin(vec2 uv) {
   return floor(uv * vec2(atlasSize) * 0.0625) * 16.0;
}

vec3 rfGlassSheetRgb(vec2 uv, vec3 texRgb, vec3 vertRgb) {
#ifdef GLASS_OPAQUE_FRAME
   return rfGlassAlbedo(texRgb, vertRgb);
#else
   vec3 pane = texRgb;
   if (atlasSize.x > 1) {
      pane = texture2D(RF_GLASS_SAMPLER, (rfGlassTileOrigin(uv) + 8.0) / vec2(atlasSize)).rgb;
   }
   return rfGlassAlbedo(pane, vertRgb);
#endif
}

float rfGlassFrameMask(vec2 uv, vec3 texRgb, float texA) {
#ifndef GLASS_OPAQUE_FRAME
   return 0.0;
#else
   float lum = dot(texRgb, vec3(0.2126, 0.7152, 0.0722));
   float detail;
   if (atlasSize.x > 1) {
      vec2 atlas = vec2(atlasSize);
      vec2 pixel = uv * atlas;
      vec2 tileOrigin = rfGlassTileOrigin(uv);
      vec2 tileMin = tileOrigin + 0.5;
      vec2 tileMax = tileOrigin + 15.5;
      vec2 tap = vec2(1.0);

      vec4 n = texture2D(RF_GLASS_SAMPLER, clamp(pixel + vec2(0.0, -tap.y), tileMin, tileMax) / atlas);
      vec4 s = texture2D(RF_GLASS_SAMPLER, clamp(pixel + vec2(0.0,  tap.y), tileMin, tileMax) / atlas);
      vec4 w = texture2D(RF_GLASS_SAMPLER, clamp(pixel + vec2(-tap.x, 0.0), tileMin, tileMax) / atlas);
      vec4 e = texture2D(RF_GLASS_SAMPLER, clamp(pixel + vec2( tap.x, 0.0), tileMin, tileMax) / atlas);
      float relA = texA - 0.25 * (n.a + s.a + w.a + e.a);
      float lumAvg = 0.25 * (
         dot(n.rgb, vec3(0.2126, 0.7152, 0.0722)) +
         dot(s.rgb, vec3(0.2126, 0.7152, 0.0722)) +
         dot(w.rgb, vec3(0.2126, 0.7152, 0.0722)) +
         dot(e.rgb, vec3(0.2126, 0.7152, 0.0722))
      );
      detail = max(relA, abs(lum - lumAvg));

      vec2 d = min(pixel - tileOrigin, tileOrigin + 16.0 - pixel);
      detail = max(detail, step(d.x, 2.2) * step(d.y, 2.2));
   } else {
      detail = abs(dFdx(lum)) + abs(dFdy(lum)) + abs(dFdx(texA)) + abs(dFdy(texA));
   }
   return step(0.055, detail);
#endif
}

vec4 rfGlassApplyFrame(vec4 surface, vec2 uv, vec3 texRgb, float texA, vec3 vertRgb, vec3 ambient) {
#ifdef GLASS_OPAQUE_FRAME
   float mask = rfGlassFrameMask(uv, texRgb, texA);
   vec3 frame = rfGlassAlbedo(texRgb, vertRgb) * ambient * 0.78;
   return vec4(mix(surface.rgb, frame, mask), mix(surface.a, 1.0, mask));
#else
   return surface;
#endif
}
#endif

#endif
