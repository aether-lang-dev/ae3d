### Lamps and shadows that the camera does not move

- **Lamps light what they reach (#468).** Every point and spot light lights
  the ground in its reach, wherever the camera is. Clustered shading
  (`ae3d.lightgrid`) cuts the view into 16 × 9 × 24 cells, lists every lamp in
  the cells its reach overlaps, and has each pixel shade with its own cell's
  list. It replaces the sixteen lights nearest the camera, which put a
  street's lamps out as the camera walked away.
  - `test_light_grid`: none of about 800,000 lamp-point pairs is missing a
    lamp.
  - `test_lamp_clusters`: a pool reads the same from 25 m and from 120 m,
    within 1.3 of 255. The old renderer lost 58.
- **The key light's shadow in cascades (#469).** When the key light is the
  sun or the moon, its shadow uses four cascades in one 4096 atlas. Each is
  fitted to a sphere around its slice of the view and kept on its own texel
  grid, so a moving camera moves no shadow.
  - `test_shadow_cascades`: a shadow's edges stay within 1.5–2.3 cm over
    twelve camera poses. The old map's wandered 13 cm.
- **Casters only where they are read.** A caster goes into a cascade only
  where its shadow can land on what that cascade shades. The test uses the
  cascade's slice of the view, and the blend band before it, as its map sees
  them.
  - On Vulkan the casters are drawn kind by kind, so each pipeline is bound
    once.
  - The street drew 339 calls with its key lamp in cascades, 250 with this.
- **Every lamp has its own shadow (#490).** A lamp was shadowed by the key
  light's map. A wall in the moon's shadow went dark under its lamp, and a
  street whose key light was a lamp was shadowed along a direction set by
  where the camera looked.
  - Each lamp in the budget now has a cube of six 512-texel faces in a
    4096 atlas (`ae3d.lampshadows`). Ten lamps fit a frame: the key light
    when it is a lamp, then the nearest whose light reaches the view. A
    lamp past the budget is unshadowed.
  - No light is shadowed by another light's map. The fills are not
    shadowed at all.
  - Faces are drawn in two layers. What stands still is drawn only when it
    changes. What moves on its own is drawn over a copy of the still layer.
  - `zombie_street` draws 87 calls a frame on OpenGL and 88 on Vulkan,
    against the 255 its one map drew.
  - `test_lamp_shadows` (21 checks, both renderers):
    - a lamp's shadow ends within 1.1 cm of where geometry puts it;
    - four camera poses move it by 0.3 cm;
    - OpenGL and Vulkan agree exactly;
    - a lamp in the moon's shadow lights its ground as fully as open ground;
    - a frame in which nothing moved draws no face.
  - `test_ray_shadows`: the map path and the rays shadow the same ground
    alike.
- **The shadow test measures a real shadow (#464).** `test_engine_shadows`
  measures a box's shadow where geometry puts it: 42% darker. Its old scene
  measured a shadow of half a percent.
- **The demo street's lamps are cut-off luminaires.** They are spot lights
  down onto the road, whole to 55° and gone by 85°. As open point lights,
  once no longer dimmed by the key light's shadow, they lit every facade in
  full. The critique now passes on both renderers:
  - lit in pools (14% of the frame bright);
  - the road in separate pools;
  - the night dark (median 0.25).
- **Critique checks restated.** Three of the critique's checks were only met
  because the key light's shadow covered the facades.
  - The lamps' reflection on the wet road is now the bright cells it adds
    (at least one streak, 12 cells) instead of a ratio to the dry road.
  - The frame-wide shadow checks now ask for any light taken out of the
    frame (1.01×), not 1.15× and 1.8×.
  - A new check requires the figure's own shadow at its feet: at least
    three cells darkened by 30% or more.
