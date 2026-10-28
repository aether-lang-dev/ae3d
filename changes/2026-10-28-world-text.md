### Text in the 3D world (#871)

- `hud.world_text(h, x, y, z, size, s, colour)` draws a name tag, a damage number or a label at a point in
  the scene, `size` tall to the em in the world's units, facing the camera it is drawn from;
  `hud.world_text_fixed` lies in a plane given by its right and up; `hud.world_text_depth(h, false)` draws the
  runs after it over everything (depth tested by default). Asked every frame like the HUD's rectangles and
  cleared with them, from the HUD's own signed-distance atlas, 512 runs a frame.
- `ae3d.worldtext` keeps the runs (one quad a glyph, a record a run); `ae3d.shaders.lettering` is the pair that
  draws them, a quote shader like every pass now (SPIR-V, GLSL and MSL from one source, the pixel shader one of
  the MSL ones under `AE3D_MSL=1`), on Vulkan and OpenGL, in the scene pass after the transparent surfaces:
  depth-tested and not written, the temporal pass following its motion vector, the upscaler, depth of field and the
  composite treating it as the scene's light. A view draws it from the view's camera. It is not picked (the pick
  pass runs first). With none asked for the frame is what it was.
- `tests/test_world_text` (occlusion, a billboard as wide from two cameras where a sign goes edge-on, a view,
  the temporal pass, depth of field, the upscaler; Vulkan against OpenGL 0 of 147,456 channels at one sample),
  `tests/test_worldtext`, `tests/test_gpu_lettering` and `benchmarks/bench_world_text` (100 labels: about 50 to
  110 us of a frame, 12 to 22 us of the GPU scene pass, on an M6).
- `glapi.glVertexAttrib4f`; the generated files carry two shaders more.
