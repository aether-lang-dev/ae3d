### The occlusion is written with quote: mat4, and calls each dialect writes its own way

- **`ae3d.shaders.ssao.ssao`** is `FRAGMENT_SSAO` as Aether: the
  hemisphere over each pixel sampled from the last frame's depth, twelve
  samples on a spiral turned per pixel. `world_at` and `dither` are
  `@quotable` helpers; `worldAt`'s `out` parameter became the depth read
  beside it. The depth is its one texture (the frame, which the old pass
  bound and never read, is not bound), and the camera's matrices, eye and
  the frame's size are captures. On Vulkan they are copied from the scene
  block as its renderer wrote them, clip correction and all, at the moment
  the old pass read them there.
- **`shaderlib.mat4`** is GLSL's mat4: four vec4 columns, std140's 64 bytes
  as they are (glslang agrees with every offset). `mul(m, v)` is `m * v`;
  `mat4_of` makes one of `ae3d.core`'s sixteen doubles and `zero_mat4` one
  of zeros. `gpu.set_mat4` sets a capture from doubles, `set_mat4_f32` from
  a uniform block's f32s, and `set_vec3` joins the setters. On the CPU a
  matrix is read where its capture holds it.
- **A call's GLSL can be the dialect's own**: the call table gains
  `CALL_GL`, OpenGL's form where it is not Vulkan's. `depth_clip(d)` is `d`
  on Vulkan and `(d * 2.0 - 1.0)` on OpenGL, whose clip z runs -1..1;
  `screen_y_sign()` is -1 on Vulkan and 1 on OpenGL, whose screen y runs
  up. These were the strings the generator rewrote in each hand-written
  shader for the Vulkan build. The CPU runs them as the dialect
  `gpu.cpu_set_dialect` names, Vulkan's unless told; run as plain Aether
  they are Vulkan's.
- **More of GLSL's builtins**: `xyz`, `dot_v2`, `normalize`, `cross`,
  `distance`, `sqrt`, `sin` and `cos`. The table's arrays are five entries a
  line, so an entry's line is the same in each.
- `tests/test_gpu_ssao.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val, the vertex shader too), and on the CPU
  a floor meeting a wall under a real camera, Vulkan's matrices as its
  renderer corrects them: every pixel against the pass written as Aether
  over shaderlib (all within 1e-3, 99.9% within 1e-4: the evaluator holds
  f32s where the reference keeps doubles, and a sample at the occlusion
  test's edge can round either way), the corner occluded and the open floor
  not; and run as OpenGL over OpenGL's matrices and depth, the same world
  positions with the image upside down. A transposed `mul` fails it, and so
  does OpenGL's `depth_clip` run as Vulkan's.
- **`FRAGMENT_SSAO`, `ssao_vk.frag`, `vkpipes.ssao`, `ssaoRadius` and
  `ssaoIntensity` are gone.** On an Apple M6, with one sample and with
  four, 27 of 28 `test_backend_parity` frames are byte-identical to main's
  on both renderers (the clouds within main's own spread), the occlusion's
  numbers in its log are main's, and zombie_city and caustics are
  byte-identical but for Vulkan with one sample, main's own multimodal
  case. The occlusion is in those frames: zombie_city without it differs
  by some 17000 channels. No validation errors.
