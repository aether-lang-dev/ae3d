### A program's own quoted screen pass, on Vulkan and OpenGL

- `engine_set_screen_pass(e, shader, spirv)`: a full-screen pixel shader
  of the program's, written with `quote`, drawn over every frame after the
  tone curve and FXAA, its colours shown as it writes them. The program
  keeps the shader and sets its inputs between frames by name
  (`gpu.set_float` and the rest). On Vulkan a program's quoted shader could
  not be drawn at all: SPIR-V came only from ae3d's generator over ae3d's
  own shaders, a pass took a fixed shader id, and the frame's passes were
  each wired in by hand.
- `ae3d.quotegen`: a program's generator makes its passes' SPIR-V at build
  time (glslangValidator on PATH), an Aether module of words and the tree's
  hash, as `tools/generate_shaders` does for ae3d's. A shader changed since
  stops the program when its pass is made, naming it and its generator.
- `vkquote.program_pass_new`, `vkpipes.shader_words`: a pass from words
  the caller keeps, and one that samples no texture (the descriptor pool
  is sized only for what the pass has). `gpu.QuotedSpirv`.
- `engine_set_screen_pass_rect(e, x, y, w, h)`: the pass in a rectangle of
  the frame, its quad filling it, so a program can put controls beside its
  picture (the viewport on OpenGL, `vkframe.viewport_at` on Vulkan).
- `examples/screen_pass.ae`, with `tools/screen_pass_spirv.ae` and the
  module it writes: the same picture on Vulkan and OpenGL, every pixel of
  576,000. `docs/screen-pass.md`.
- Checked by a program of its own that draws a raymarched film this way,
  against reference frames drawn by another renderer: 34 of 360,000 pixels
  more than 1/255 from them on Vulkan, 36 on OpenGL (M6). Another, a
  raymarcher, draws in a rectangle under its sliders: 111 of 307,200 on Vulkan, 87 on
  OpenGL.
