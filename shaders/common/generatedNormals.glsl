#ifndef GENERATED_NORMALS_GLSL
#define GENERATED_NORMALS_GLSL


float sampleAlbedoLuma(vec2 uv) {
   vec3 c = texture2D(gtexture, uv).rgb;
   return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void applyGeneratedNormals(inout vec3 newNormal, vec3 albedo, vec3 tangent, vec3 binormal,
                           vec2 texCoord, vec2 absMidCoordPos, vec2 signMidCoordPos) {
   vec2 midCoord = texCoord - absMidCoordPos * signMidCoordPos;
   vec2 inset = absMidCoordPos * 0.09;
   vec2 maxOffsetCoord = midCoord + absMidCoordPos - inset;
   vec2 minOffsetCoord = midCoord - absMidCoordPos + inset;
   vec2 tap = (16.0 / max(vec2(atlasSize), vec2(1.0))) / NORMAL_RESOLUTION;

   vec2 edgeDist = min(texCoord - minOffsetCoord, maxOffsetCoord - texCoord);
   float edgeFade = smoothe(clamp(min(edgeDist.x, edgeDist.y) / max(tap.x * 2.2, 1e-6), 0.0, 1.0));
   if (edgeFade < 0.04) {
      return;
   }

   vec2 uvR = vec2(min(texCoord.x + tap.x, maxOffsetCoord.x), texCoord.y);
   vec2 uvL = vec2(max(texCoord.x - tap.x, minOffsetCoord.x), texCoord.y);
   vec2 uvU = vec2(texCoord.x, min(texCoord.y + tap.y, maxOffsetCoord.y));
   vec2 uvD = vec2(texCoord.x, max(texCoord.y - tap.y, minOffsetCoord.y));

   float dx = sampleAlbedoLuma(uvR) - sampleAlbedoLuma(uvL);
   float dy = sampleAlbedoLuma(uvU) - sampleAlbedoLuma(uvD);

   float mag = length(vec2(dx, dy));
   float knee = max(NORMAL_THRESHOLD * 0.45, 0.02);
   float shaped = mag * mag / (mag + knee);
   if (shaped < 1.0e-5) {
      return;
   }

   vec2 slope = vec2(dx, dy) * (shaped / max(mag, 1.0e-6));
   float lumaScale = mix(0.85, 1.15, clamp(dot(albedo, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0));
   slope *= NORMAL_STRENGTH * 0.55 * edgeFade * lumaScale;

   vec3 nMap = normalize(vec3(-slope.x, -slope.y, 1.0));
   newNormal = clamp(
      normalize(tangent * nMap.x + binormal * nMap.y + newNormal * nMap.z),
      vec3(-1.0),
      vec3(1.0)
   );
}

#endif
