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
