### Objects are their components, and the scene is one of them (#506, #510)

- `ae3d.component` is a registry of component kinds. Each kind states its
  fields once, by `offsetof`, beside its struct, and its defaults come from
  its constructor. The inspector, the scene file and the agent read every
  component through it.
  - Field types: bool, int, float (bounded or not), vec3, colour, rotation
    in degrees, enums written by name, text and assets, plus properties the
    state derives.
  - `validate` runs after every write through the registry. A version
    counts every change, including a script's own stores on an
    `@observable` state (Aether 0.727's `std.observe`).
- The engine's own kinds are views over the structs it already has:
  Transform, Mesh Renderer, Material, Light and Camera. `engine.object`
  gives every object a Transform, and a drawn one its renderer and
  material.
- A scene has a root object, Scene. Its components are the scene's and
  run before any object's.
  - The engine puts Environment (the sky, the sun by the hour, clouds,
    overcast, fog) and Rendering (the post passes, shadows, reflections,
    occlusion, TAA) on it, with the engine itself as their state.
  - `engine_set_fog` and the Scene's fog row edit one value.
- Components that own their state go through the scene file on the objects
  they were on and on the scene. A kind the loading program lacks is kept
  and written back on save.
- Seven new agent ops: `object.list`, `object.get`, `component.kinds`, and
  `component.get`/`set`/`add`/`remove`/`enable`. `component.kinds` gives
  every field's type, range and choices.
- The editor's inspector is the selected object's components, drawn from
  their kinds:
  - a panel each, with its enable switch and Reset, Move Up, Move Down and
    Remove, then Add Component;
  - Transform first, as in Unity;
  - an edit reaches every selected object carrying that kind, one axis of a
    vector at a time;
  - selecting an object of the same shape keeps the panels;
  - rows follow whatever changes a value (a script, the gizmo, the physics,
    the agent, an undo) and are never rewritten under the caret;
  - assets are picked from lists (the engine's skies);
  - every edit, add and removal is one undo step.

  The scene's own settings moved from the editor's globals onto the engine
  the viewport draws with, and show when the hierarchy's new **Scene** row
  is selected, with the weather, the presets, the shading switches and the
  viewport's camera. The editor's fixed Transform, Material, Light, Sky
  and post rows are gone, 520 lines of them. `tools/drive_editor.ae`
  presses the panels on both renderers (151 checks).
- Fixed, found on the way:
  - `engine_set_sky` made a new sky every call and never freed the one it
    replaced, so dragging the hour made one a frame. The engine now owns
    the sky it makes, reuses it while the image is the same, and frees the
    one it replaces.
  - A light's cone set in degrees refused an outer angle narrower than the
    inner one; the angle just set now wins and the other gives way.
  - `core.quat_to_euler` joins `quat_from_euler`.
  - The editor's bounded run checks its rows grouped by the object each
    reads, selecting each object once rather than twice a row: a selection
    builds the inspector's panels, and the check took 3 s of a 4 s run on
    Windows and more than the 90 s backstop under GTK on a software display.
    It takes 0.65 s now, with the same report.
  - `AE3D_EDITOR_PROFILE=1` marks every frame of a bounded run, the snapshot,
    each stage of the report and the window closing; `ci.sh` runs the editor
    with it and prints the log's tail when a run fails, so a hang says where.
