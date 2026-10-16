### The colour resolve is written with quote

- **`ae3d.shaders.resolve.color_resolve`** is `FRAGMENT_COLOR_RESOLVE` as
  Aether: each pixel's samples averaged, each weighed by 1 / (1 + its luma
  at the frame's exposure), so a lamp seen by one sample at an edge does not
  stand for the whole pixel. Its sample count and exposure are captures, set
  before each draw, rather than `colorSampleCount` and `frameExposure` read
  from the scene block (Vulkan) or set by name (OpenGL).
- **Both renderers draw it**: Vulkan through `ae3d.vkquote`, OpenGL as the
  tree's GLSL with its uniforms set by `quoted_uniforms`, as the bloom's are.
- `tests/test_gpu_resolve.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val, the vertex shader too), the block and its
  one sampler2DMS, and the CPU's resolve of an HDR scene with a lamp in one
  sample and a hard edge against the same weighed mean worked out in
  doubles (worst 7e-8), the lamp's pixel well under its plain mean. Leaving
  the exposure out of the weight fails it.
- `FRAGMENT_COLOR_RESOLVE`, `color_resolve_vk.frag`, the colour-resolve
  pipeline in `vkpipes` and `colorSampleCount` in the scene block stay,
  unused, until the GPU lanes have compared multisampled frames against
  main's.
