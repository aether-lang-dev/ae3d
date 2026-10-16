### The sky's light is made by shaders written with quote

- **`ae3d.shaders.sky.sky_irradiance`** and **`sky_filter`** are
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
- `FRAGMENT_SKY_FILTER`, `FRAGMENT_SKY_IRRADIANCE`, their `_vk` files and
  `vkpipes`' two pipelines stay, unused, until the GPU lanes have compared
  frames against main's.
