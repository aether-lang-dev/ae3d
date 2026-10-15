### The depth copy is written with quote: a depth fragment shader

- **`ae3d.shaders.depth.depth_copy`** is `FRAGMENT_DEPTH_COPY` as Aether: the
  scene's depth copied pixel for pixel into the camera-depth target when the
  frame has one sample (`texel_fetch(depth, frag_coord()).x`). A frame with
  more samples still resolves them through the hand-written
  `FRAGMENT_DEPTH_RESOLVE`.
- **`gpu.depth_fragment`** makes a shader whose quote returns the pixel's
  depth, a float written to `gl_FragDepth`, with no colour output; returning
  anything else is refused. `gpu.writes_depth` says which a shader is.
- **The call table's forms can be templates**: `$0`, `$1` are the
  arguments, and anything that is not a plain name is one. `rgb(c)` is
  `$0.rgb`, and two new calls are `ae3d.shaderlib` functions:
  `frag_coord()` is `gl_FragCoord.xy` and `texel_fetch(t, p)` is
  `texelFetch($0, ivec2($1), 0)`. On the CPU, `frag_coord()` is the pixel's
  centre in a target whose size `gpu.cpu_set_viewport` gives, and refuses
  without it; run as plain Aether, it is the pixel `shaderlib.set_frag_coord`
  names.
- **`ae3d.vkquote`** takes a shader with no uniforms (no block, its textures
  from binding 0), draws a depth shader depth-tested and depth-written into
  a pass with no colour, and reads its images in the layout
  `set_image_layout` names (a depth image's, for the copy).
- `tests/test_gpu_depth.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val, the vertex shader too), no block and one
  sampler at binding 0, every pixel's depth copied exactly on the CPU (to its
  f32) as the body run as Aether copies it, the refusal without a viewport,
  and a depth shader returning a colour refused. Reading the texel at y, x
  instead fails it; so does dropping the return-type check.
- `FRAGMENT_DEPTH_COPY` and `depth_copy_vk.frag` are still generated, unused,
  until the GPU lanes have compared frames drawn with one sample against
  main's.
