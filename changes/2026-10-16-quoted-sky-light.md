### The sky's light is made by shaders written with quote

- **`ae3d.shaders.skyprobe.sky_irradiance`** and **`sky_filter`** are
  `FRAGMENT_SKY_IRRADIANCE` and `FRAGMENT_SKY_FILTER` as Aether: the
  irradiance onto every normal from the capture's 16-texel mip (the ground
  under the horizon lit when it has an albedo), and the capture
  prefiltered by GGX into the reflections' roughness levels, 48 samples a
  texel. The octahedral map's arithmetic (`oct_decode`, `oct_encode`,
  `oct_uv`, `oct_texel_direction`, `capture_q`) and the samples'
  `radical_inverse` are `@quotable` helpers. `radical_inverse` counts in
  halves, which for the filter's 48 samples is the 32-bit reversal it
  replaces, exactly; `capture_direction`'s `out` angle became the length
  of `capture_q`'s point.
- **Mips on the CPU**: `shaderlib.image_mip_chain` makes a ShaderImage's
  levels as a linear blit halves them (each texel the mean of four),
  `texture_lod` reads them trilinearly and `texel_fetch_lod` a texel of
  one; `log2` joins the builtins.
- **Both renderers draw them**: on Vulkan `ae3d.vksky` through two quoted
  passes (`vkframe.quoted_screen_pass`; the filter a ring of six draws, one
  a level, its size and roughness set before each), the ground copied from
  the scene block as the pass read it; on OpenGL from the tree's GLSL with
  `quoted_uniforms`.
- **The filter's `radical_inverse` is the hand-written one's 32-bit
  reversal, in a uint**, as Aether 0.821.0's quote can carry (aether#2947):
  `ae3d.gpu` writes a `uint32` as GLSL's `uint`, its literals and a uint's
  literal shift counts with their `u`, and runs a uint's arithmetic and bit
  operations on the CPU exactly, wrapped to 32 bits; `shaderlib.uint_of` and
  `float_of_uint` are `uint(x)` and `float(u)`. Counted in halves (the same
  values) it had left 16 of 28 Vulkan parity frames a step off in a few
  channels on an Apple M6 (MoltenVK): the same numbers, not the same
  shader. A CPU `>>` off by one fails `test_gpu_sky`.
- **The module is `ae3d.shaders.skyprobe`, not `ae3d.shaders.sky`**: with
  `ae3d.sky` in the same program (every engine program), aetherc prefixed
  the shader module's functions, the prefixed names went into the quote
  tree's helpers, and the tree hashed otherwise than `generate_shaders`'
  had: Vulkan refused both sky passes and no engine program started, while
  every test of the shaders alone passed. `tests/test_quoted_hashes.ae`
  now builds every quoted shader in a program importing the whole engine
  and holds its hash to the one the SPIR-V was made from (on the old name,
  both sky shaders fail it). `test_engine_skybox` fails, rather than skips,
  when the engine had a window and the renderer would not start on it
  (`engine.engine_renderer_failed`).
- **The sky itself, its capture and its clouds move to step 6** (Paul,
  2026-10-16): each takes its direction and two clip positions from its
  own vertex shader and writes a colour and a motion vector.
- `tests/test_gpu_sky.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val), `radical_inverse` against the 32-bit
  reversal for all 48 samples, and on the CPU: under a sky of one colour
  the irradiance is pi times it (within 2%, the octahedral texels' solid
  angles being approximate) and a rough level the colour itself; under a
  sky with a sun, both passes against the same written as Aether over
  shaderlib (the irradiance to 1e-6; the filter all within 1e-3 and all
  but 14 of 4096 texels within 1e-4, where beside the sun the f32
  evaluator and the doubles land a 256th of a sampler's weight apart). A
  `texture_lod` that reads only the top level fails it; so does an
  irradiance without its cosine.
- **`FRAGMENT_SKY_FILTER`, `FRAGMENT_SKY_IRRADIANCE`, their `_vk` files and
  `vkpipes`' two pipelines are gone**, and with them `skyLevelSize`,
  `skyRoughness`, `groundAlbedo` and `groundSun` in the scene block (193
  uniforms, 16160 bytes): the renderer hands the ground to `vksky` itself
  (`vksky.set_ground`), which watches it for a new capture in the same
  words it watched in the block. On an Apple M6 at 4x and one sample, 27
  of 28 `test_backend_parity` frames are byte-identical to main's on both
  renderers (the clouds within main's own spread, #793), every one of the
  16 Vulkan frames the filter used to move among them, and zombie_city and
  street_drive are main's but for Vulkan at one sample (#794). No
  validation errors.
- **One printed figure moves**: `test_water_sky`'s Vulkan mean reads
  40.324, 129, 55.6744 where main's reads 40.3241, 129, 55.6745, the same
  on every run: one channel a step, from the quoted filter (the
  hand-written pipeline in its place gives main's). Its loop counts in
  floats where the hand-written one counted in ints, the likeliest
  difference left. No frame the parity test or the scenes compare shows
  it.
