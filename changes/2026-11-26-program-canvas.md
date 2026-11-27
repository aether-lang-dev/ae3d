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
- `engine_texture_new`: a texture of the program's RGBA bytes for its
  canvas draws, no colour curve, nearest and repeating, no mips
  (`vktexture.texture_create_picture`; on OpenGL an RGBA8 texture).
  `engine_texture_free`.
- `engine_canvas_draw` takes `over` after `cull`: the draw blended over
  what is there by its pixel shader's alpha, depth still tested and
  written (`vkquote.program_pipeline`).
- `platform.window_set_size`, `window_x`, `window_y`: the window resized
  in points, and where it is on the desktop.
- `gpu.set_vec4`: a shader's vec4 input from four numbers, as `set_vec3`
  sets a vec3.
- `examples/canvas.ae`: a turning globe in a canvas, the same on Vulkan and
  OpenGL to 1/255.

### Fixed

- `ae3d.quotegen` makes the folder of the module it writes, and says why a
  shader's GLSL could not be written (the emitter's error) instead of
  handing glslang nothing.
