### The scene file's view retired: what a scene is set to is its root's components (#895)

- **The scene's camera is a component.** The engine's camera is the scene
  root's **Camera**, put there once the window makes it, or once `engine_over`
  is handed one. The kind gains its position, yaw and pitch, and a write
  recomputes where it looks. `components.place_camera` adopts a Camera read
  from a file before the camera existed, in the engine and in the editor.
- **The weather is a component.** Weather comes from `ae3d.weather`
  (`weather_component_kind`, `weather_attach`): its kind, intensity, wind
  heading and wind speed, each written through `weather_set`. A scene loaded
  by a program that runs no weather keeps its Weather and writes it back.
- **Culling is the scene's.** Face and frustum culling are fields of
  **Rendering**, held on the engine and put to the renderer's switches when
  they change, where before they were a process-wide switch no file carried.
  `engine_set_face_culling` and `engine_set_frustum_culling` keep both in
  step.
- **No view is written.** `scene_save` takes no view. A component that
  borrows a state nothing else writes is written by the registry
  (`component.set_saved_borrowed`): Environment, Rendering, Camera and
  Weather. The editor, `engine_save_scene` and the agent's `scene.save` all
  write the scene's settings this way.
  - A file with a `view` still opens. It is applied only where the file has
    one (`scene.scene_has_view`), so a newer file's components are not undone
    by the view's defaults.
  - The agent's `scene.load` takes a newer file's camera from its Camera.
- `test_scene_settings` (new, 15 checks):
  - a scene with every setting changed (camera pose and lens, sky, bloom,
    depth of field, fog, culling, weather) saves with no view and comes back
    into a fresh engine through its components;
  - a running weather and a later camera adopt the file's values.

  `test_scene_io` reads the old file's view from the committed fixture.
  `tools/drive_editor` checks the editor's saved settings in the scene's
  components. `docs/components.md` and `docs/editor.md` describe both.
- **A material's every number in the scene file.** The file's writer and
  reader each listed a material's numbers, and neither had `cutout`, `fire`
  or `soft`: a particle's disc, a fire and a soft decal came back from a
  saved scene as plain quads. One table now (`scene.material_number_*`),
  which both read. A number a file does not name is what a new material
  holds, as before.
