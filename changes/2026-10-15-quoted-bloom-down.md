### The bloom's down pass is written with quote, its helpers @quotable

- **`ae3d.shaders.bloom.bloom_down`** is `FRAGMENT_BLOOM_DOWN` as Aether:
  thirteen taps in five groups of four, each group weighed by brightness on
  the pyramid's first level, and there only the light past the threshold
  kept. Its four helpers (`luma`, `tap`, `group`, `past_threshold`) are
  `@quotable` functions (Aether's quote version 2), each written out as a
  GLSL function and run on the CPU as the Aether it is. A helper reads only
  its parameters, so `tap` is given the texture and texel the GLSL read as
  uniforms. FXAA's `luma` became a helper the same way.
- **Both renderers draw it.** One shader is drawn for every down step of a
  frame, the SSR's two blurs and up to six levels, its texel and level set
  through the captures' cells before each draw (`gpu.set_vec2`, `set_int`,
  `set_float`). On Vulkan, `ae3d.vkquote`'s pass now has a ring of sets and
  blocks per frame slot, a buffer each so no device's uniform-offset
  alignment applies (`pass_new`'s `draws`, `prepare`'s `draw`); a draw past
  the ring is refused and said once, never wrapped onto a set the GPU may
  still be reading. On OpenGL, the program is the tree's GLSL and its
  uniforms are set by name, as FXAA's are.
- `tests/test_gpu_bloom.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures, glslang and spirv-val), the std140 block and its values, and the
  CPU's run of the quoted pass against the same pass written as Aether on an
  HDR image with a lamp and a hot pixel, on the first level (worst 6e-8) and
  a later one (0), each from a shader built for the other level and set
  through its cells.
- **`FRAGMENT_BLOOM_DOWN`, `bloom_down_vk.frag` and `vkpipes.bloom_down` are
  gone**, and with them `bloomFirst` and `bloomThreshold` in the scene block
  every other pass reads; every shader over it is regenerated. On an Apple M6
  (Vulkan with 4x MSAA, OpenGL 4.1 over Metal) the frames drawn with bloom
  are byte-identical to main's on both renderers (`test_backend_parity` with
  `AE3D_PARITY_DUMP`), and its OpenGL-against-Vulkan bloom comparison reads
  as main's: 2100 of 147456 channels differ, worst 116.
