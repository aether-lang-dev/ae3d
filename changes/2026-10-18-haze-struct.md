### The composite's haze as one captured struct

Step 6's composite (docs/aether_quote_design.md section 11), as the design
had it: the heat haze's columns are a captured struct with array fields,
not eight `vec4` captures. The frames are main's.

- **`composite.Haze`** is `{ count: int, column: vec4[4], shape: vec4[4] }`.
  The haze's loop reads `haze.column[kk]` and `haze.shape[kk]`, and keeps
  the hand-written loop's break, continues and `float(k)`. `haze_column` is
  gone. `composite.set_haze` copies a renderer's 32 words into it.
- **ae3d.gpu takes a captured struct.** The tree says which fields the body
  reads and as what (aether#2972, Aether 0.829.0: `vec4[4]`, not
  `UNKNOWN[4]`). It does not say where they are in the cell, so the shader's
  module places them with the compiler's offsets:
  `gpu.capture_field(s, "haze", "column", offsetof(Haze, column))`.
  - GLSL: a struct of the fields the body reads, in the cell's order,
    declared before the block that holds it.
  - `params_write` repacks each element from the cell to std140's 16-byte
    stride. A `float[4]` is doubles 8 bytes apart in the cell and 16 apart
    in the block.
  - The CPU reads a field, or an array's element, from the cell.
  - OpenGL sets the struct a value at a time, by the names
    `gpu.uniforms_*` give (`haze.column[2]`).
  - A field the body reads that nothing placed is refused, when the shader
    is written and when it is run.
- **Generator:** a captured struct's array is reported by glslang once,
  with its stride. Each element ae3d.gpu places is held to it. The
  generator still verifies 302 offsets. The SPIR-V is 973140 bytes, down
  from 974884.
- **Tests:** `test_gpu_composite` has 35 checks, up from 24. It holds the
  haze's struct declaration, its place in the block (144 bytes at 0) and
  its 14 values for OpenGL. It holds `params_write`'s repack and
  `set_haze`'s copy. It holds a struct of `float[4]`: repacked 16 apart,
  compiled by glslang and spirv-val, and read by the CPU. A field read but
  not placed is refused. The CPU haze cases give main's numbers.
- **Frames:** `frames_against.sh` against main: 59 frames, none differ
  (the clouds within #793). test_backend_parity's 56 frames at 1x and 4x
  are main's but for the clouds (#793). zombie_city and street_drive at
  AE3D_TICK=60 draw main's frames on both renderers, within each mode
  (#794); Vulkan at 1x never draws the same frame twice on main either.
  The sky-lit and composite suites print main's numbers.
- **Negative control:** with the columns placed at `offsetof(Haze, shape)`,
  2 of test_gpu_composite's checks fail (the repack, the ripple: 0 of 41
  pixels). 6 of test_heat_haze's fail, 3 on each renderer.
