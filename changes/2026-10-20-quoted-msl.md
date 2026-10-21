### The quoted shaders written as MSL

- **ae3d.gpu writes MSL** (`gpu.METAL`: `emit_msl`, `emit_vertex_msl`,
  `emit_screen_vertex_msl`) from the same trees as the GLSL, with Vulkan's
  conventions (each vertex shader negates its position's y as it returns
  it); docs/aether_quote_design.md section 11, "What it buys MSL", has the
  rules. Step 5 of section 9; no Metal renderer yet, and no aether change.
- **`src/ae3d/metal`**: every quoted shader's MSL (41 files), written by
  `tools/generate_shaders.ae` beside the GLSL and held current by `--check`.
- **`scripts/msl_check.sh`** (in `./ci.sh` on macOS): Metal's compiler,
  through the device (`tools/mslc.m`), every warning an error; each block
  struct's std140 offsets are `static_assert`s in the text.
- **`tests/test_gpu_msl`**: what the dialect writes where it departs from
  the GLSL, no GPU.
