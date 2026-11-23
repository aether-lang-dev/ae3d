### AE3D_PERF names what the transparent pass shades

- `perf transparent_cover` (with `AE3D_PERF=1`): the five blended models
  covering the most screen a frame, by name, with their draws. A blended
  surface is lit at every pixel it covers once per layer, so the
  transparent stage's cost goes with covered area, not draws: about 1.75
  ms per screen-covering layer at 640x360, 4x MSAA, M1 Pro. A game whose
  transparent stage read 29 ms with its particles and water removed had
  nothing that said what was left.
- Measured on the way, M1 Pro at 1792x1008 with 4x MSAA: breaking the
  scene pass to resolve the depth (occlusion, reflection, water) costs
  0.55 ms. Store and reload of the multisampled targets is not where a
  transparent stage's time goes.
- `engine.transparent_share(cam, m, width, height)`: the estimate, for a
  program's own accounting.
- `test_transparent_cover`, new: a sheet filling the view is one screen, a
  small far one a sliver, an opaque one and one behind the camera none.
- `docs/performance.md`, "Measuring".
- A particle emitter's model is named "particles", so the line names it.
  A game names its own with `core.model_set_name(particles.emitter_model(em), ...)`.
  The share is an upper bound: an emitter's bounds count as covered where
  its cards are sparse.
