### Lamps: still instances drawn once, a light that casts no shadow, a limit

- **An instance stream that stands still is a static caster.** A lamp's
  face drew every instanced model in its reach over its static layer every
  frame, so a town of instanced props was redrawn into every face of every
  shadowed lamp, every frame. Hushlight found instancing slower than
  copies: 267 draws became 1,436. Now a stream moves only in the frames
  its instances change (`Model.instances_changed`, on both renderers);
  standing still, it is drawn into the static layer once. 40 instanced
  props among ten lamps: 1,047 → 125 draws a frame, 11.5 → 10.6 ms
  (`benchmarks/bench_lamp_instances.ae`, M1 Pro, Vulkan).
- **`core.light_set_shadows(l, false)`**: a light lit but never given a
  map (a window's glow, a fill light). The scene file keeps it as
  `"shadows": false`.
- **`engine.engine_set_lamp_shadow_limit(e, n)`**: how many lamps a frame
  are shadowed, the nearest first, at most ten.
- `test_lamp_shadows` (27 checks):
  - a still instance stream drawn into its faces as it settles, then not
    again;
  - a light with no shadow given no map, and the next lamp given its slot;
  - a limit of three shadows the three nearest;
  - a moving stream is moved every frame, as its check means.
- `docs/rendering.md`, "The lamps' own shadows".
