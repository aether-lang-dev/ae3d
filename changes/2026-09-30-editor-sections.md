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
- **Terrain** is a component kind (`components.terrain_kind`,
  `attach_terrain`, `terrain_of`) over the terrain's voxel world: its biome
  and style are choices and its seed a whole number. Each write fills the
  world again and draws it on the model it already has
  (`terrain.rebuild`); a sculpted world is drawn again with `terrain.draw`.
  The editor's biome buttons, style buttons and seed row, with their undo
  slots and row check, are gone; its section is the sculpting brush alone
  (SCULPT), shown with a terrain selected. A terrain edit says what was
  built in the console and counts the new geometry in the title.
- The component registry has `int_property` and `enum_property`: an int or
  a choice the state derives through accessors, as `float_property` and
  `bool_property` already were -- read, written, copied, reset, compared
  and saved like the rest.
- **A model's geometry can change while a renderer holds it.**
  `core.model_geometry_changed(m)` bumps the model's geometry stamp, and
  both renderers take a model whose stamp moved past what they uploaded out
  and add it back before the next frame: one compare a model when nothing
  changed. A game regenerating terrain or swapping a mesh no longer has to
  reach into the backend, and the editor no longer does.
- `voxel.world_model(w)` is the model a world was last built onto.
- **Physics Body** is a component kind (`components.physics_kind`,
  `attach_physics`, `physics_of`) owning the body record the scene file
  writes: its body and collider are choices by the file's names, a
  character is always a capsule, and a body always has weight. An object
  without a body has no component; Add Component gives it one and Remove
  takes it away, both undone as component steps. The editor's No body /
  Static / Kinematic / Dynamic / Character and collider buttons, its
  friction, bounce and density rows and their undo are gone.
- `component.set_recorded(k, true)`: a kind the scene file records in a
  typed record of its own (a body is its model's physics) is left out of
  the saved components, so it is never written twice.
- A choice with more than three options lays them in rows of three under
  its caption: five biomes or five colliders beside a caption ran past the
  inspector at its narrowest, which the driver now checks.
- **Figure** is a component kind, registered beside its struct in
  ae3d.figure (`figure.figure_kind`, `attach_figure`): the clip it plays,
  chosen by name from the figure's own file through the inspector's picker
  (the editor lists the shown figure's clips), whether it loops, its pace
  and how far into the clip it stands. A figure comes from a file, so the
  kind has no constructor and Add Component never offers it. The editor's
  FIGURE section -- eight clip buttons, Loop, the speed and time rows and
  their undo -- is gone.
