### The sky, its capture and its clouds written with quote

Step 6's sky family (docs/aether_quote_design.md section 11), on both
renderers. The frames are main's.

- **`ae3d.shaders.skydome`** (not `sky`: ae3d.sky is the engine's) is the
  sky in Aether: `sky_vertex`, the cube about the eye at the far plane
  (`pos.xyww` as `vec4(vec3(pos.x, pos.y, pos.w), pos.w)`), handing on
  `tex_coords`, `clip_now` and `clip_prev` at locations 0, 1 and 2, where
  the hand-written shader had TexCoords, ClipNow and ClipPrev; and three
  pixel shaders over those varyings: `sky` (its colour at 0 and its motion
  vector at 1), `sky_capture` and `cloud`. The last two read none of them
  and link to the screen's vertex shader. FRAGMENT_SKYBOX's three #ifdef
  variants are three quotes sharing `@quotable` helpers, the variants'
  differences arguments (the discs, the march's steps), and
  `cloudDensity`'s `out float heightFraction` is a `CloudSample` it returns.
  Each helper keeps the hand-written one's shape where the rounding depends
  on it; the capture's octahedral decode is its own (`texel_direction`),
  a vector at a time as the hand-written one is: ae3d.shaders.skyprobe's,
  a lane at a time, put five texels of the capture's directions a rounding
  apart on MoltenVK, and the scene a step apart in three or four pixels.
- **Vulkan**: `vkquote.pair_new` draws a linked pair, the vertex shader's
  captures a block of their own at set 1, into the scene pass's two
  attachments, depth-tested and not written. The sky, the capture and the
  cloud pass copy what they are drawn from word for word
  (`gpu.set_*_f32`), as the hand-written shader read it: out of the scene
  program's block, and the sky's own values out of `vkframe.sky_words`. A quoted pass takes five textures (the clouds').
- **OpenGL** compiles the same trees' GLSL at start, the sky's program
  from its pair, and sets their uniforms by name before each draw.
- The generator writes `sky_quoted`, `sky_capture_quoted` and
  `cloud_quoted`, the sky's vertex shader from its own quote
  (`SKY_QUOTED_VERTEX_HASH`, its VertexParams offsets held to glslang's).
- **`VERTEX_SKYBOX`, `FRAGMENT_SKYBOX`, `sky_vk.*`, `sky_capture_vk.frag`,
  `cloud_vk.frag` and `vkpipes`' three sky pipelines are gone** (with
  `vkframe.screen_pass`, which only the hand-written capture and clouds
  drew through), and with them ten uniforms of the scene block only they
  read: `projection`, `view`, `cloudSunColor`, `skySun`, `cloudFrame`,
  `skyProcedural`, `skyFlat`, `skyTurbidity`, `cloudPassSize` and
  `cloudHistoryOn` (183 uniforms, 15952 bytes; 53 shaders). The renderer
  sets them in the sky's own words instead (`vkframe.set_sky_*`, the same
  32-bit words), which the quoted passes copy from and `vksky` watches for
  a new capture.
- `tests/test_gpu_skydome.ae`, 46 checks: golden GLSL for all four in both
  dialects (glslang and spirv-val), the link and its locations, the two
  outputs, the CloudSample struct, and on the CPU the vertex shader and
  each pixel shader -- the sky painted, by day, by night, flat and
  overcast, the capture with its clouds marched through 3D noise, the
  cloud pass with its history -- against the same shader written as plain
  Aether. The far plane's w for z, a motion vector of swapped clip
  positions, the capture's march a step short, the history folded at a
  quarter, an evaluator's exp 2% out and the links' locations from 1 each
  fail it.
