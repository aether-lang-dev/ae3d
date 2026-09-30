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
- **Natural Motion** is a component kind (`components.natural_kind`,
  `attach_natural`, `natural_of`) owning the motion record the scene file
  writes with a figure: its mode by the file's name, whether it protects
  itself falling, its strength and when it gets up. A figure without it has
  no component; Add Component gives one. The simulation, the save and the
  load read it off the figure's object. The editor's MOTION section, its
  rows, undo slots and the figure row's own copy of the record are gone.
- With every per-object setting a component, the editor's row check runs
  the rows it has left (the selection's and the view's) without selecting
  anything.
- aether-lang-dev/aether#2320: `offsetof(T, f)` inside a module that also
  has a function `f` names the function -- why Natural Motion lives in
  ae3d.components beside Physics Body (both views over the scene's records)
  rather than in ae3d.motion, whose getters share the fields' names.

### The editor takes real mouse input on Windows

Driven with physical clicks, drags and the wheel, the editor was slow and
most of it ignored the mouse. aether-ui#217 fixes the toolkit side (clicks
on rows and rounded buttons, toggle/slider/picker values, the wheel, scroll
view sizing, 62 fps timers); the pin moves to it. In the editor:

- The viewport is made at a 240-pixel height floor, as it already was for
  width, and fills what the console and status footer leave. Made at 620,
  the toolbar, view, console and footer asked for 892 pixels in a window
  with 824 under the status bar, so the row ran past the window: the footer
  and the last rows of both side panels (PLAY, BEHAVIOUR) were unreachable.
- The wheel pushed away zooms in, as in Unity and Blender; it zoomed out,
  and a sideways scroll zoomed out too.

### `ae build` and `ae run` build every example

- `aether.toml` at the root: aephysics as a dependency patched to its
  submodule (aephysics#55 exports its root) and `-ffp-contract=off`, so
  `ae run examples/physics.ae` builds and runs with the toolchain alone.
- The engine's modules say what they need: `ae3d.core` names the crash
  handler with `@source`, `ae3d.vkdevice` the DLSS stub and macOS's Metal
  layer, and `ae3d.platform` links GLFW and the platform's windowing and GL
  libraries with `@link` in `when target.os` arms.
- The examples' black hole renderer is imported as
  `examples.lib.blackhole`, by its path from the root, so it needs no
  search path; `examples/lib` is off `AETHER_LIB_DIR`.
- `build.sh` and the editor's build leave out of a program the `@source`
  files the engine's shared library carries (`ae3d_program_sources`): one
  crash handler, and the Streamline shim rather than the stub.

### A destroyed object's last fields reach every client (#513)

A snapshot leaves a destroyed object out and the destroy carries only its
place, so a change the host made in the object's last tick, carried by one
snapshot a client lost, never arrived: the client held ticks past the
destroy with the old value (macOS CI, the rocket's last burn at tick 145
and its destroy at 146). The host now keeps the fields as they were when
the object went, and snapshots against a base older than the destroy carry
them (flag 8) until every client has acknowledged a snapshot of that tick.
Reproduced under contention (29% of runs with the destroy on the tick after
a burn; 300 of 300 pass with the fix); `last_change` in test_net_fields
holds it deterministically over the hub.
