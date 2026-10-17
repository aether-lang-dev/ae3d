### Vertex shaders written with quote: the full-screen pass's first

- **`gpu.vertex(name) quote | v: Vertex | { return Varyings { ... } }`**
  is a vertex shader (step 6, docs/aether_quote_design.md section 11). Its
  quote takes one struct, the vertex's attributes, and returns a struct
  literal: the field `position` is `gl_Position`, the others its varyings
  at the locations of their places. An attribute is a field of the
  parameter the body reads, written at the location one table gives it
  (`ATTR_*`: position 0, uv 1, normal 2, the instance streams after, as
  the pipelines' vertex input state has them). An attribute the table
  lacks, and a return other than a struct literal, are refused.
  `gpu.emit_vertex_glsl` writes it for either dialect; the CPU runs it
  (`cpu_vertex_attr`, `cpu_run_vertex`, `cpu_varying`).
- **The full-screen pass's vertex shader is one** (`gpu.screen_vertex`,
  `ScreenVertex` to `ScreenVaryings`), and `emit_screen_vertex` writes it
  for each quoted pass, its varying under the pass's parameter's name. Its
  position is a vec3 on both renderers: OpenGL's quad gives two
  components, and the third reads 0, as the GL spec fills it.
- `tests/test_gpu_vertex.ae`: the GLSL for Vulkan and OpenGL 4.1 (golden
  fixtures; glslang and spirv-val), the varying named for the pass it
  feeds, the quad's four corners on the CPU, and both refusals. A position
  at the wrong location fails it; so does a CPU that drops an output's
  lane.
