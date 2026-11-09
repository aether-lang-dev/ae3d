### Morph targets (#910, its first item)

- **Imported from glTF** (`ae3d.morph`, `gltf`): every primitive's targets,
  their POSITION, NORMAL and TANGENT offsets, sparse or not, named by the
  mesh's `extras.targetNames`, starting at the mesh's `weights` (a node's own
  `weights` over them), and a "weights" animation channel as an
  `anim.WEIGHTS` channel, one number a target a key, STEP, LINEAR and
  CUBICSPLINE. The importer only warned at a morph target animation before.
  Held to the files: 73,866 offsets of three Khronos samples
  (AnimatedMorphCube, MorphPrimitivesTest, MorphStressTest) equal the
  file's accessors to the bit, read by the test's own reader.
- **Drawn on both renderers, before the skinning** (`ae3d.vkmorph`,
  `gl.gl_morph_model`): the bind pose plus the active targets' weighted
  offsets written into the mesh's own vertex buffer, which every pass then
  reads -- the scene, its depth and shadows, the pick, the rays' skinning --
  a compute pass on Vulkan (`morph_vk.comp`) and transform feedback on
  OpenGL 4.1. Only the active targets are read; a model whose weights are
  all zero dispatches nothing, the first such frame copying the bind pose
  back. Read back, the morph matches the CPU's (`morph.apply`) within 3e-8 m
  on both, and on Vulkan the device's morph-then-skin within 2.4e-7 m.
  A blink on a figure standing still skins its ray structure again
  (`vkrays.skin_pose` takes `reshaped`).
- **Weights as pose curves** (`pose.add_curve`, `pose.add_morph_curves`): a
  rig's poses carry them after the joints; takes sample them from a weights
  channel (`clips.from_scene`), blends lerp them, additives add them, and
  the animator inertializes them as it does the joints.
- **Measured** (`bench_morph`, RTX 4070 Ti): 0.075 to 0.096 ns a vertex an
  active target on the device (262,144 vertices, 16 targets), 0.07 to 0.15
  ns a vertex for the pass itself; MorphStressTest imports in 0.76 ms.
- `generate_shaders` reads glslang's Windows output (CR LF lines), so the
  SPIR-V is made and checked with Khronos' Windows build of 16.6.0 as well.
