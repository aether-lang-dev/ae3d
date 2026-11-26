### Added

- A program's own quoted draws (`engine_screen_draw`): a pixel shader
  written with `quote` drawn in as many rectangles of the frame as the
  program queues, each draw with the shader's inputs as they were when it
  was queued, after the screen pass and in the order queued, blended over
  what is there as a premultiplied colour is: sprites drawn by a shader.
  They stay queued until `engine_screen_draws_clear`;
  `engine_set_screen_clip` cuts the draws queued after it to a rectangle.
  Each shader's pass is made the first time it is queued and kept (Vulkan
  from ae3d.quotegen's SPIR-V, growing its sets as more draws are queued;
  OpenGL compiling its GLSL). `vkpipes.BLEND_PREMULTIPLIED`.
- `examples/screen_draws.ae`: a backdrop of `fill` lines and balls cut to
  a rectangle; the same on Vulkan and OpenGL but for one pixel of 576,000,
  1/255 apart.
  `docs/screen-pass.md`.
- Checked by a program of its own that draws each atom of a molecule as a
  draw of a ball shader: every atom where, and as, reference frames drawn
  by another renderer have it, and no pixel more than 2/255 from them, on
  Vulkan and OpenGL.
