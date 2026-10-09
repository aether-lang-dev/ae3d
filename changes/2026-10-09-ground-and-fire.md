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
- **The sand's normal map is the slope of real ripples (#737, #702).** It
  was the slope of the colour's relief, whose grain sampled a texel apart
  stood the normals at a median 50 degrees; under a low sun every texel
  turned from it in a speckle of dark. `tools/make_sky.ae` now writes it
  from wind ripples' height (a gentle windward climb, a steeper lee, a
  degree of grain): a median of 2.9 degrees, 12.2 at the 99th percentile.
  Under a 19-degree sun the near sand's luminance spread is 0.18 where it
  was 0.44, and none of it is over 1.5 times the mean (21% was). The
  colour texture and the skies it writes are unchanged.
- **Triplanar mapping on a material (#737).** `material_set_triplanar`
  takes its colour and normal map from the world position on three planes,
  blended by the way the surface faces, normals by the whiteout blend
  (Golus 2017): slopes without one projection's stretch, no UVs needed. A
  wall with every UV at (0, 0) is one colour (grain 1.5) and mapped so has
  its texture's (33.8). The sand example's heap and dunes use it.
- **A normal map's averaged-away bumps go into the roughness (Toksvig,
  #737).** A mip that averages a normal map's bumps is shorter than one;
  the shortness is put back as roughness, so a highlight over bumps too
  fine for the pixel spreads instead of sparkling or turning to a mirror.
  A glossy wall whose 30-degree bumps the mips flattened peaks at 59 where
  the same wall flat peaks at 241. On every normal-mapped surface.
- **The sand example's grains reflect as sand does,** a specular of 0.03 as
  its plain's, where the default reflected the sky whole.
- **The ground lights what faces down (#740).** `engine_set_ground_bounce`
  gives the sky's irradiance a ground under the horizon, its albedo lit by
  the sky and the sun, where a renderer without probes' light took the
  sky's lower half as it was drawn: under the sky drawn from the sun, a
  haze. Over desert sand a downward face is lit (0.78, 0.64, 0.48) where it
  was (0.22, 0.40, 0.99) under a blue sky, red over blue 1.63 against 0.22,
  and an upward face within 3% of before, on both renderers
  (`tests/test_ground_bounce.ae`). The campfire uses it. A painted sky
  keeps its own ground: the sand example's heap, its shaded side under a
  blue sky, is unchanged by it.
- **Soft particles (#738).** `particles.set_soft` / `core.model_set_soft`:
  a blended particle fades out within its softness of what the scene drew
  behind it, from the scene's depth read at binding 4 (unit 4 on OpenGL),
  where the water reads it. A glowing particle standing in the ground is
  296 bright just over it soft, 687 hard, and 687 either way higher up, on
  both renderers. `set_fire` and `set_smoke` make theirs soft; the
  campfire's flames melt into the logs instead of cutting a line.
