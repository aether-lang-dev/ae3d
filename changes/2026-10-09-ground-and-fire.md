### Ground that holds up to the horizon; fire that looks like fire

- **Scene textures filter across 16 texels at a slant (#737).** No sampler
  used anisotropic filtering on either backend, so ground ahead of a walker
  fell to one blurred mip a few metres out. `engine_set_anisotropy` (16 by
  default, capped at the device's; 1 is off). A 1 m checker seen at a
  grazing angle keeps 71.7 of fine detail against 44.6 (mean 4-neighbour
  Laplacian), on OpenGL and Vulkan alike (`tests/test_anisotropy.ae`).
- **A material breaks up its repeat (#737).** `material_set_tile_breakup`
  samples the colour and the normal map as hexagons of offset copies,
  optionally turned (Mikkelsen 2022), blended where they meet. A noise wall
  repeating every metre matches itself a tile over at 0.94, broken up at
  0.01 (`tests/test_tile_breakup.ae`).
- **A material varies over the world (#737).** `material_set_variation`:
  the albedo lighter and darker by patches of world space. A white wall's
  spread is 0.076 at 0.3 against 0.002 without.
- **A detail layer at the eye's feet (#737).** `material_set_detail`: the
  material's own textures again at a finer scale, faded out by a distance:
  a texture magnified four times over has 46.1 of grain against 16.8.
- All four saved with the scene; `examples/sand.ae`'s plain and horizon use
  them.
- **Fire is the engine's (#738).** `particles.set_fire` makes each
  particle a flame simulated by the new `ae3d.flames` (stable fluids with
  vorticity confinement, baked at load into a 4 by 4 flipbook) glowing as a
  black body (`core.model_set_fire`): a hot flame draws (250, 232) red and
  green, one cooled to 0.6 (193, 63). Flipbook frames blend instead of
  stepping. `set_smoke`, `set_area` (born over a disc), `set_stretch` (sparks
  drawn along their flight), `set_glow`, and `set_light` (a point light of
  the black body's colour, flickering about its power, never past it) on an
  emitter; `core.model_set_billboard_lift` stands a billboard on its point.
  A blended emitter is no longer cut at a half, which clipped every soft
  rim. `examples/campfire.ae`; `tests/test_flames.ae`.
