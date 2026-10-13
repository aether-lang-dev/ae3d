### One tree, two GLSL dialects: OpenGL draws FXAA from the quoted shader too

- **ae3d.gpu writes desktop OpenGL 4.1's GLSL** (`gpu.GL`, beside
  `gpu.VULKAN`): `#version 410 core`, each uniform and each sampler by its
  name, no set or binding qualifiers, the varying by name; and the
  full-screen vertex shader for OpenGL's screen quad (a vec2 position).
  `tests/fixtures/gpu/fxaa_gl.frag` is FXAA's, and glslang takes it and
  its vertex shader as OpenGL's GLSL.
- **The OpenGL renderer's FXAA is that GLSL**, written from the same tree
  the Vulkan SPIR-V was made from when the renderer starts; its uniforms
  are set by name from the captures each frame (`quoted_uniforms`), and the
  tree is made again when the viewport changes size. **The FXAA heredoc in
  `ae3d.shaders` is gone**: FXAA exists once, in Aether.
- `tests/test_gpu_fxaa.ae` holds OpenGL to the CPU's run of the quoted
  shader too, at two sizes, the frame's rows read as OpenGL's texture lays
  them out: within one step of 255 on Mesa (6142 of 6144 pixels exact and
  all 4480 at 80 x 56 on x86_64), and on Apple's OpenGL, a translation onto
  Metal, within two (one pixel of 4480 at 80 x 56 is two out, where the
  GPU's FXAA left it alone; the hand-written GLSL gave it the same). A
  tree left at the first size is five steps out at the second.
  `test_backend_parity`'s fxaa comparison reads exactly as it did with the
  two hand-written shaders: 2569 of 147456 channels differ, worst 140.
- The CPU evaluator rounds each value it makes to f32, as a GLSL float is:
  6127 of 6144 pixels to the bit against Apple's Vulkan, for 6122.
