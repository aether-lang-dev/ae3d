### ae3d.gpu: structs, varyings, two outputs and 3D textures

Step 6's sky family needs these first (docs/aether_quote_design.md
section 11); nothing drawn changes with them.

- **`gpu.link(vertex, pixel)`**: a pixel shader may take a struct of
  varyings. The fields it reads are matched to the vertex shader's by name
  and type, not by struct, so one vertex shader serves any pixel shader
  whose inputs it hands on; the pixel shader is written with those inputs
  alone, at the vertex shader's locations (`varying_location`). A field the
  vertex shader lacks, one of another type and `position` are refused,
  naming it, as is writing such a pixel shader before it is linked. One
  that reads none links to any vertex shader, the screen's included.
- **Two outputs**: a pixel shader returning a struct literal writes each
  field to `out_<field>` at its place, location 0, 1, ... in both dialects:
  the sky's colour and motion vector. The CPU gives the struct back
  (`val_field`, `val_free`).
- **GLSL structs**: a struct the tree builds that is not its interface (a
  helper's return, a struct local) is declared once, from its literals and
  the fields read of it, and built by its constructor: a helper returns a
  struct where GLSL's had an `out` parameter (`cloudDensity`'s
  `heightFraction`). A literal that leaves a field out is refused.
- **A vertex shader's captures**: a std140 block of their own,
  `VertexParams`, at set 1, binding 0 on Vulkan (set 0 is the pixel
  shader's), uniforms by name on OpenGL. An int varying is `flat`.
- **`Texture3D`** is a `sampler3D`, read by `texture_3d(t, p)`; on the CPU
  a `ShaderImage3D`, trilinear and wrapped at the edges as the clouds'
  REPEAT samplers read.
- **New calls**: `exp`, `acos`, `asin`, `atan2` (GLSL's two-argument
  `atan`), `tan`, `floor_v3`, `splat2/3/4`, `mix_v4`, `normalize_v2`, `xz`,
  `mul_m4` (a matrix product), `m4_at` (`m[c][r]`) and `mul_transpose3`
  (`transpose(mat3(m)) * v`), each in shaderlib as plain Aether and on the
  CPU. `set_float_f32`, `set_vec2_f32` and `set_vec3_f32` copy a capture
  from a uniform block's words, bit for bit.
- `tests/test_gpu_structs.ae`, 36 checks: golden GLSL for the vertex and
  pixel shaders (glslang and spirv-val, OpenGL's checked too), the
  locations, every refusal, the CPU against plain Aether for the vertex
  shader's product, the two outputs, `texture_3d` and the new calls. Each
  of a CPU struct that mislabels a field, a link that puts every varying
  at 0, a 3D read that clamps, two outputs at one location, an int varying
  not `flat`, and a product with its rows for columns fails it.
- Found on the way, Aether 0.822.0: a struct's string field read in a loop
  as an argument beside a call was released at the end of each pass and
  again at the start of the next; `val_copy` copies a field in a function
  of its own until the fix is released. And a program that imports `exp`,
  `sqrt`, ... from shaderlib by name loses ae3d.gpu's externs of those
  names, so the test calls them by module.
