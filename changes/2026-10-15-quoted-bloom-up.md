### The bloom's up pass is written with quote; a quoted pass samples several textures

- **`ae3d.shaders.bloom.bloom_up`** is `FRAGMENT_BLOOM_UP` as Aether: a
  level's own downsample plus a 3x3 tent of the coarser level's sum (the
  `tap` helper bloom_down uses), divided by the number of levels on the last
  step. `top` is a float capture, since GLSL divides by it and quote has no
  cast to make one from an int.
- **`ae3d.vkquote` takes a shader's textures at bindings 1, 2, ...**, in the
  order the shader names them (`gpu.samplers_name`), not just one;
  `prepare` takes arrays of views and samplers. vkframe's `draw_quoted2`
  draws with two. On OpenGL the quoted program's textures are units 0, 1, ...
  in the same order (`quoted_uniforms`).
- Both renderers draw the up pass from its quoted shader: one shader, its
  texel and `top` set through its cells before each step (a ring of 5 draws on
  Vulkan, the steps up from at most six levels).
- `tests/test_gpu_bloom.ae` adds bloom_up: its GLSL for Vulkan and OpenGL
  (golden fixtures, glslang and spirv-val), its block (`vec2 texel@0`,
  `float top@8`, 16 bytes), its two samplers in order, and its CPU run
  against the pass written as Aether on a middle step and the last (exact on
  both). With the level's texture swapped for the sum's, 5 checks fail.
- **`FRAGMENT_BLOOM_UP`, `bloom_up_vk.frag` and `vkpipes.bloom_up` are
  gone**, and with them `bloomTop` and `texelSize` in the scene block (only
  the two bloom passes read them) and vkframe's `set_texel`: the block is 16
  bytes shorter (16240), and every shader over it is regenerated. On an Apple
  M6 the frames drawn with bloom are byte-identical to main's on both
  renderers, as for the down pass.
