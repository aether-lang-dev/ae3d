### The Vulkan renderer draws FXAA from its quoted shader

- **FXAA's pass is `ae3d.shaders.fxaa`'s tree** (`ae3d.vkquote`): its own
  descriptor set, the shader's `Params` block at binding 0 and the frame it
  smooths at 1, a mapped block per frame slot, filled before each draw by
  copying every capture's current value out of its cell (`gpu.params_write`,
  std140 as glslang lays it out). The pipeline is made from the SPIR-V the
  generator wrote from the same tree, and a tree that no longer hashes to it
  is refused, FXAA left out of the frame, rather than read through another
  shader's layout.
- The renderer keeps the tree; its texel is a capture, so when the frame
  changes size the renderer makes the tree again for the new size
  (`vkframe.fxaa_shader`). The thresholds are the pass's as they were
  (0.125, 0.0625, 0.75).
- **`fxaa_vk.frag` is gone**, and with it FXAA's three floats in the scene
  block every other pass reads (`edgeThreshold`, `edgeThresholdMin`,
  `subpixelQuality`): the block is 16 bytes shorter (16256), and every
  shader over it regenerated.
- `tests/test_gpu_fxaa.ae` holds the CPU's run of the quoted shader to the
  GPU's within one step of 255 on every channel, at 96 x 64 (6122 of 6144
  pixels exact on an Apple GPU, as before the move) and, the frame remade,
  at 80 x 56 (4467 of 4480): the tree left at the first size is five steps
  out at the second, and a subpixel of 0.5 captured in place of 0.75 eight.
  It frees what it made, and leaks nothing on macOS (it lost three of its
  own blocks before). `test_backend_parity`'s fxaa comparison, OpenGL
  against Vulkan, reads as it did: 2569 of 147456 channels differ, worst
  140, on this Mac, both before and after.
