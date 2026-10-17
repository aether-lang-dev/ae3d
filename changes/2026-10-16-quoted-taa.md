### The temporal pass is written with quote

- **`ae3d.shaders.taa.taa`** is `FRAGMENT_TAA` as Aether: the history read
  where the pixel's surface was last frame, held to this frame's
  neighbourhood and blended in, all in the folded space where a lamp does
  not decide its neighbours. `fold` and `unfold` are `@quotable` helpers,
  handed the exposure. The frame's size, the blend and the exposure are
  captures, rather than `screenSize`, `taaBlend` and `frameExposure` read
  from the scene block (Vulkan) or set by name (OpenGL). The scene's depth,
  which the hand-written pass bound and never read, is no longer bound.
- **The vector forms of GLSL's overloaded builtins** have their names by
  the naming convention (Nic's option A): `min_v3`, `max_v3`, `clamp_v3`,
  `mix_v3` and `length_v2` in `ae3d.shaderlib`, each GLSL's one name in
  `ae3d.gpu`'s call table and run on the CPU lane by lane as that name.
  `xy(c)` is `c.xy`, as `rgb(c)` is `c.rgb`.
- **Both renderers draw it**: Vulkan through `ae3d.vkquote`
  (`vkframe.draw_quoted3`, three textures), OpenGL from the tree's GLSL
  with `quoted_uniforms`, its textures at the units of their places.
- `tests/test_gpu_taa.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val, the vertex shader too), the three
  samplers in the order the body reads them, the vector builtins by GLSL's
  name, and the CPU's run over an HDR frame with a lamp, a differing
  history and motion that moves part of it by fractions of a pixel and one
  column off the screen, against the pass written as Aether over
  shaderlib (worst 1.3e-7), with history and with none. Dropping the
  history's clamp fails it; so does running `min_v3` and the rest as
  themselves rather than as GLSL's name.
- **`FRAGMENT_TAA`, `taa_vk.frag`, `vkpipes.taa` and `taaBlend` are gone**
  (the scene block is 16224 bytes). On an Apple M6, with one sample and
  with four, 27 of 28 `test_backend_parity` frames are byte-identical to
  main's on both renderers, the clouds over the skybox within main's own
  run-to-run spread; zombie_city with TAA on is byte-identical but for
  Vulkan with one sample, where main is bimodal against itself;
  `test_taa` and `test_velocity` print main's numbers. No validation
  errors.
