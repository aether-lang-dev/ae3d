### The editor's last fixed sections become components (#506)

- **Water** is a component kind (`components.water_kind`, `attach_water`,
  `water_of`), a view over the surface's simulation like the Light over its
  light. Every setting the simulation has is a row -- the wave's height,
  speed, scale and randomness, its colour and opacity, foam, the shore,
  reflection, the sky it reflects and its colour, caustics, shadow,
  distortion and normal strength -- where the editor's fixed WATER section
  showed seven. A write reaches the surface's uniforms at once, and the
  wave height rebuilds the wave table. It undoes as a component edit.
- The fixed WATER section and its rows are gone from the editor, with the
  undo replay, the row check and the section's show and hide that each
  selection paid for.
- `tools/drive_editor.ae` finds a component panel by its title
  (`component_body_id`) and counts the rows inside it: 159 checks, all
  passing on both backends. `tests/test_components.ae`: 65.
