### A shader as a tree: ae3d.gpu

- New `ae3d.gpu`: a shader built as a tree of nodes (the shapes Aether's
  planned `quote` will hand a library, `docs/aether_quote_design.md`),
  written out as GLSL or run on the CPU. Step 1 of that plan: the back ends
  proved before the compiler changes.
- The GLSL back end writes a Vulkan fragment shader: the captures in a small
  uniform block and a sampler binding each, the parameter at location 0, a
  return as the output colour, parenthesised only where the operators need
  it. FXAA (`fxaa_vk.frag`'s main, built node for node in
  `tests/test_gpu.ae`) comes out as `tests/fixtures/gpu/fxaa.frag`, which
  reads as the hand-written one does, compiles with glslang and passes
  spirv-val.
- The CPU back end runs the same tree over vec2/vec3/vec4 values in doubles,
  texture() bilinear and clamped at the edges. On a 12x8 image with edges,
  flat ground and a lone bright pixel it agrees with FXAA written straight
  in Aether on all 96 pixels, worst 2.4e-8, both of FXAA's paths taken (41
  and 55 pixels); a smoothstep off by a twentieth fails it at 0.114.
- The reference FXAA is written with vec2/vec3/vec4 as distinct types over
  f32x4, which Aether 0.809 makes work (aether#2778: a scalar variable now
  splats across a lane vector, and two different distinct types no longer
  mix in an operator).
- And against the GPU (`tests/test_gpu_fxaa.ae`, a GPU suite): the
  renderer draws a sphere and a cube with FXAA off (twice, the same frame)
  and on, and gpu.fxaa_shader() runs on the CPU over the plain frame with
  the pass's own uniforms. Every channel of every pixel is within one step
  of 255 of what fxaa_vk.frag made on the GPU: on an Apple GPU through
  MoltenVK, 6110 of 6144 pixels exactly; on lavapipe, 6121 on x86_64 and
  5957 on arm64, the rest a rounding apart. The smoothstep off by a
  twentieth is two steps out and fails it.
