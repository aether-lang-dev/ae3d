### A light's reach, where a game ends its pool

- A light reaches where its fall-off drops to a 64th. For
  `light_point(..., range = 4)` that is 28 m, so a window's glow was
  listed in every cluster within 28 m, and every pixel there shaded it.
  Hushlight's eleven pane lights cost 4-13 ms of the opaque pass.
- `core.light_set_reach(l, metres)` ends a light's pool there, with the same
  fade over its last quarter (`lightgrid.reach`, both renderers). 0, the
  default, keeps the fall-off's reach, so every scene lights as it did. The
  scene file keeps it as `"reach"` when set.
- `test_light_reach`, new: a 4 m reach puts the light in 26 cells where it
  was in 802; a limit past the fall-off and 0 change nothing; the scene
  file round trip.
- `docs/rendering.md`, "Lamps".
