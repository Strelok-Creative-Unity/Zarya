# Third-Party Notices

This file lists third-party code and assets embedded in Zarya.
Each section contains the original copyright notice and license text as required.

---

## David Hoskins — Hash without Sine

Used in:
- `shaders/common/dh_fade.glsl` — `dhSeamNoise()`
- `shaders/common/airFog.glsl` — `airFogDither()`
- `shaders/common/volumetrics.glsl` — `volumetricsDither()`
- `shaders/common/netherFog.glsl` — `netherFogDither()`
- `shaders/common/stars.glsl` — `starHash22()`, `starHash21()`

Original source: https://www.shadertoy.com/view/4djSRW

```
// Hash without Sine
// MIT License

Copyright (c) 2014 David Hoskins.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Simon Rodriguez — FXAA 3.11 compact

Used in:
- `shaders/common/fxaa.glsl` — `rfFxaa()`

Original source: https://github.com/kosua20/Rendu/blob/master/resources/common/shaders/screens/fxaa.frag

```
MIT License

Copyright (c) 2017 Simon Rodriguez

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## NVIDIA Corporation — FXAA 3.11

The FXAA algorithm implemented in `shaders/common/fxaa.glsl` is based on
NVIDIA's FXAA 3.11 by Timothy Lottes, simplified by Simon Rodriguez (see above).

Original NVIDIA header:

```
// NVIDIA FXAA 3.11 by TIMOTHY LOTTES
// File: es3-kepler/FXAA/FXAA3_11.h
// SDK Version: v3.00
// Email: gameworks@nvidia.com
// Site: http://developer.nvidia.com/

Copyright (c) 2014-2015, NVIDIA CORPORATION. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of NVIDIA CORPORATION nor the names of its contributors
  may be used to endorse or promote products derived from this software
  without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

---

## Minecraft vanilla textures — `sun_vanilla.png` / `moon_phases_vanilla.png`

These files are vanilla Minecraft assets shipped with the game (not authored by Zarya).
Zarya includes them as-is without claiming ownership or licensing them under MIT/BSD.

Used in:
- `shaders/shaders.properties`
  - `texture.world0/gbuffers_skytextured.suntex=tex/sun_vanilla.png`
  - `texture.world0/gbuffers_skytextured.moontex=tex/moon_phases_vanilla.png`

License / terms:
- Subject to the **Minecraft EULA** and Mojang Studios / Microsoft terms.
- No additional license is granted by this repository for these Minecraft assets.

Minecraft EULA: https://www.minecraft.net/en-us/eula
