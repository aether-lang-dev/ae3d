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
- **Both renderers draw the irradiance**: on Vulkan `ae3d.vksky` through a
  quoted pass (`vkframe.quoted_screen_pass`), the ground copied from the
  scene block as the pass read it; on OpenGL from the tree's GLSL with
  `quoted_uniforms`. Its frames are main's on both renderers.
- **The filter is written but not drawn yet.** Its `radical_inverse` counts
  in halves, the same values as the 32-bit reversal it replaces, yet on an
  Apple M6 (MoltenVK) it left 16 of 28 Vulkan parity frames a step off in a
  few channels; main's uint reversal swapped in by hand made them exact.
  Quote cannot carry a uint32 yet (an aether PR is under way), so both
  renderers draw `FRAGMENT_SKY_FILTER` until a release that can, and the
  quoted filter, its SPIR-V and `test_gpu_sky` wait in the tree for it
  (Paul, 2026-10-17). Writing the rest of the filter in the hand-written
  one's shape made OpenGL inexact as well, so it keeps step 4's shape.
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
- `FRAGMENT_SKY_IRRADIANCE`, its `_vk` file and `vkpipes`' irradiance
  pipeline stay, unused, until they are cleaned up with the filter's.
