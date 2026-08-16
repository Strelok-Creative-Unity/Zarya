#ifndef RF_SHARPEN_GLSL
#define RF_SHARPEN_GLSL


vec3 rfSharpenFromNeighbors(vec3 color, vec3 n, vec3 s, vec3 w, vec3 e, float amount) {
   if (amount < 0.001) {
      return color;
   }

   vec3 mn = min(min(n, s), min(w, e));
   vec3 mx = max(max(n, s), max(w, e));
   vec3 avg = (n + s + w + e) * 0.25;
   vec3 sharp = color + (color - avg) * (amount * 1.6);

   mn = min(mn, color);
   mx = max(mx, color);
   vec3 pad = (mx - mn) * 0.12 + 0.004;
   return clamp(sharp, mn - pad, mx + pad);
}

vec3 rfSharpen(sampler2D tex, vec2 uv, vec3 color, float amount) {
   if (amount < 0.001) {
      return color;
   }

   vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
   vec3 n = texture2D(tex, uv + vec2( 0.0, -1.0) * texel).rgb;
   vec3 s = texture2D(tex, uv + vec2( 0.0,  1.0) * texel).rgb;
   vec3 w = texture2D(tex, uv + vec2(-1.0,  0.0) * texel).rgb;
   vec3 e = texture2D(tex, uv + vec2( 1.0,  0.0) * texel).rgb;
   return rfSharpenFromNeighbors(color, n, s, w, e, amount);
}

#endif
