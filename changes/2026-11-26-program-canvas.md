### Added

- A program's own canvas (`engine_canvas_new`): meshes of the program's
  (`engine_mesh_new`) drawn with its own quoted vertex and pixel shader
  pairs (`engine_canvas_draw`), depth-tested, into a picture with depth of
  its own each frame before the frame's passes, and shown in a rectangle of
  the frame as its shaders wrote it (`engine_canvas_show`). A draw takes
  both shaders' inputs as they are when it is queued; draws stay queued
  till `engine_canvas_begin`. `engine_canvas_lens` makes an OpenGL-shaped
  projection the running renderer's. `ae3d.quotegen.add_pair` writes a
  pair's SPIR-V, `gpu.pair_hash` checks it, `gpu.set_m4` sets a capture
  from an `ae3d.shaderlib` `mat4`. Vulkan: `ae3d.vkcanvas` (images, render
  pass, framebuffer), `vkquote.program_pair_new`; OpenGL: an offscreen
  target with depth. `docs/canvas.md`.
- `examples/canvas.ae`: a turning globe in a canvas, the same on Vulkan and
  OpenGL to 1/255. A program of its own draws a sky and a land, a grid its
  vertex shader raises into hills, into a canvas: no more than 71 pixels of
  307,200 more than 2/255 from reference frames drawn by another renderer,
  on either renderer.

### Fixed

- `ae3d.quotegen` makes the folder of the module it writes, and says why a
  shader's GLSL could not be written (the emitter's error) instead of
  handing glslang nothing.
