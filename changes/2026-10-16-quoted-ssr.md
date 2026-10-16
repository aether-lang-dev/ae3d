### The wet road's reflection is written with quote

- **`ae3d.shaders.ssr.ssr`** is `FRAGMENT_SSR` as Aether: the road's pixels
  rebuilt into the world from the depth, the view ray reflected about the
  road and marched until it enters what was drawn, the hit bisected and read
  through a cone as wide as the surface is rough, and the light added to
  the scene. `hash2`, `value_noise`, `puddle` and `reflection_at` (the cone,
  an early return for a sharp one) are `@quotable` helpers, and so is
  `ssao.world_at`, which both passes call: a helper from another module is
  written out with the ones of the shader's own.
- On Vulkan the camera's matrices and eye are copied from the scene block,
  as the pass read them there before; the strength and the road's height
  are captures. On OpenGL the uniforms are set by `quoted_uniforms`, the
  textures at the units they had.
- **More of GLSL**: `texture_size` (`vec2(textureSize(t, 0))`), `floor_v2`,
  `fract_v2`, `clamp_v2`, `length_v3`, `reflect` and `pow`.
- `tests/test_gpu_ssr.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val, the vertex shader too), and on the CPU a
  road running to a lit wall under a real camera (Vulkan's matrices as its
  renderer corrects them): with strength 0 every pixel is the scene's; the
  sky and the wall above its foot are untouched; on the road below the
  wall its light is added; and against the pass written as Aether over
  shaderlib the same pixels gain light (all but one of 6144) and the light
  added is the same to 0.2%. Pixel for pixel they cannot agree: the
  puddles are a hash of the road's metres, fract(sin(x) * 43758.5) with x
  near a thousand, which f32 and doubles put in different places. A
  reflection about the wrong normal fails it, and so does a `reflect` on
  the CPU that does not double its dot product.
- **`FRAGMENT_SSR`, `ssr_vk.frag`, the SSR pipeline in `vkpipes`,
  `ssrRoadHeight` and `ssrStrength` are gone** (the scene block is 16208
  bytes). On an Apple M6, with one sample and with four, 27 of 28
  `test_backend_parity` frames are byte-identical to main's on both
  renderers (the clouds within main's own spread), the wet ground's
  reflection numbers in its log are main's, and zombie_city and
  street_drive are byte-identical but for Vulkan with one sample, main's
  own flicker. The reflection is in those frames: zombie_city without it
  differs by some 45000 channels, street_drive by 40000. No validation
  errors.
