### The depth resolve is written with quote: a multisample texture type

- **`ae3d.shaders.depth.depth_resolve`** is `FRAGMENT_DEPTH_RESOLVE` as
  Aether: the nearest of each pixel's samples (the least depth) put in the
  camera-depth target when the frame has more than one sample. It loops
  over a captured `samples`, set before each draw from the target's sample
  count, rather than reading `depthSampleCount` from the scene block.
- **`shaderlib.TextureMS`** is a `sampler2DMS`: a multisampled texture, read
  only a sample at a time by `texel_fetch_ms(t, p, s)`, which is
  `texelFetch($0, ivec2($1), $2)` in the call table. On the CPU it reads a
  `ShaderImageMS`, one `ShaderImage` a sample (`image_ms_new`,
  `image_ms_sample`, `texture_ms_of`); a sample past the image's reads the
  last there is, as a pixel past the edge reads the edge.
- **`ae3d.gpu`** declares each sampler with its capture's type (sampler2D
  or sampler2DMS) rather than always sampler2D.
- **`ae3d.vkframe`** draws the resolve through `ae3d.vkquote`, as the
  one-sample copy is drawn.
- `tests/test_gpu_depth.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val), the sample count in the block and one
  sampler2DMS, and on the CPU every pixel resolved to its nearest sample
  exactly, the nearest of the first two when told of two, as the body run
  as Aether resolves it. Reading sample 0 whatever the index fails it; so
  does dropping `texel_fetch_ms` from the call table.
- **`FRAGMENT_DEPTH_RESOLVE`, `depth_resolve_vk.frag`,
  `vkpipes.depth_resolve` and `depthSampleCount` are gone.** On an Apple M6
  at 4x MSAA, 27 of 28 `test_backend_parity` frames are byte-identical to
  main's on both renderers, every case that reads the depth among them; the
  28th, the clouds over the skybox, differs less than main does from itself.
  No validation errors.
