# Components

A game object is its components, and the scene is an object too. That is
Unity's shape, and ae3d has had half of it since `ae3d.behaviour`: objects
with a list of components that run Unity's phases. What was missing is the
other half. Nothing outside a component's own code could see inside it, so
the editor's inspector was a fixed panel of rows written by hand for the
kinds the editor knew. The scene file carried a struct per kind, and the
agent had no way to ask what an object carried.

`ae3d.component` is that other half: a registry of **component kinds**,
each saying once what its state is made of, field by field. The inspector,
the scene file, a save and the agent all read components through it, so a
kind a game adds shows in the editor, saves and loads, and answers the agent
the day it is registered.

## A kind, registered

```aether
struct Stamina @observable {
    value: float
    max: float
    sprinting: bool
}

stamina_new() -> ptr {
    s = heap.new(Stamina)
    s.value = 100.0
    s.max = 100.0
    return s as ptr
}

stamina_free(p: ptr) { heap.free(p as *Stamina) }

stamina_update(p: ptr, go: *GameObject, delta: float) {
    s = p as *Stamina
    if s.sprinting { s.value = s.value - 20.0 * delta }
}

register_stamina() -> *ComponentKind {
    k = component.kind("Stamina", "Gameplay", stamina_new, stamina_free)
    component.float_field(k, "value", offsetof(Stamina, value), 0.0, 100.0)
    component.float_field(k, "max", offsetof(Stamina, max), 1.0, 500.0)
    component.bool_field(k, "sprinting", offsetof(Stamina, sprinting))
    component.set_observable(k, true)
    component.phases(k, null, stamina_update, null, null)
    return k
}

// Every object that needs one gets its own Stamina, freed with it.
c = component.add(player, register_stamina())
```

- **Fields are registered by `offsetof`.** Renaming a struct field breaks the
  build rather than the save file. The registration is a second copy of the
  struct's shape, written beside it; aether-lang-dev/aether#2298 asks the
  language for a derived schema, which would remove that copy.
- **Field types:** `bool`, `int`, `float` (bounded or not), `vec3`, `color`,
  `rotation` (a quaternion shown as degrees about each axis), `enum` (an int
  written by its choice's name, so reordering the choices never changes what
  a saved scene meant), `text` and `asset` (a path, shown with a picker).
  Text goes through two accessors given at registration, because only code
  that knows the struct can replace a string in it without leaking or
  double-freeing.
- **Derived values** (`float_property`, `bool_property`) are read and written
  through accessors. A spot light's cone is stored as the cosine the shader
  wants and shown and saved in degrees.
- **Defaults have one source: the constructor.** The registry makes one
  state when the kind is registered and reads every default from it, for a
  new component, for Reset, and for a save that writes only what differs.
- **`validate(state, field)`** runs after every write through the registry,
  as Unity's OnValidate does. The Transform's rebuilds the model's matrix;
  the Environment's hands the fog, the clouds and the sky back to the
  renderer.
- **Every phase, by name:** `awake`, `start`, `update`, `fixed_update`,
  `late_update` and `on_destroy`, each handed the component's own state and
  its object.
- **Flags:** `FIELD_TRANSIENT` is a field that is shown but not saved,
  `FIELD_READONLY` one that is shown but not edited, and `FIELD_HIDDEN` the
  kind's own bookkeeping.

A component's **version** counts its changes: every write through the
registry, and, for a kind whose state struct is `@observable`
(aether-lang-dev/aether#2220, in 0.727), every store the script makes itself
(`s.value = 40`). The runtime notifies the component, and it bumps the
count. A save or the network compares versions to find what changed.

## The engine's kinds

Each is a **view over a struct the engine already has**, never a copy of it,
so a program that calls `core.model_set_position` and the inspector showing
that position agree without anything syncing them.

| Kind | State | Fields |
|---|---|---|
| Transform | the object's model | position, rotation, scale |
| Mesh Renderer | the object's model | visible, casts shadow |
| Material | the model's material | color, metallic, roughness, reflectivity, exposure, opacity, texture, normal map |
| Light | the light it carries | type (point, directional, spot), color, intensity, ambient, temperature, range, direction, inner and outer angle |
| Camera | the camera it carries | field of view, near, far, speed, sensitivity, invert mouse |
| Water | the surface's simulation | wave height, speed, scale and randomness, color, opacity, foam and its intensity, shore fade and foam, reflection, sky color, sky, caustics and their intensity and scale, shadow, distortion, normal strength |
| Terrain | the terrain's voxel world | biome, seed, style (blocks or smooth); each write fills and draws the world again on its model |
| Physics Body | the body record the scene file writes | body (static, kinematic, dynamic, character), collider (box, sphere, capsule, hull, mesh), friction, bounce, density; no body is no component |
| Figure | the animated figure (ae3d.figure) | clip (by the file's name; none stops it), loop, speed, time (a share of the clip); made from its file, never added from a menu |
| Environment | the engine | sky (an image, or none), sky color, sun by time, time of day, clouds, cloud wind, overcast and its color, fog, fog start, end, density and color |
| Rendering | the engine | FXAA, bloom and its threshold and intensity, shadows and their distance, reflections and their height and strength, ambient occlusion and its radius and intensity, temporal antialiasing |

`engine.object` gives every object a Transform first, and a drawn one its
Mesh Renderer and Material. An object with no model still has a Transform:
its model is a group that is never drawn.

## The scene is an object

`behaviour.scene_root(scene)` is the scene itself, a game object named
Scene. It is never one of the scene's objects, so it is never found, listed,
destroyed or cleared with them, and its components run before any object's
in every phase. The engine puts **Environment** and **Rendering** on it,
with the engine as their state. `engine_set_fog` and the Scene's fog row
edit one value. A game puts its rules there too: a match timer, a score.

## Saved

A component is written by whatever owns its state:
- **A view** (Transform, Material, Light, Environment) is written by the
  model, the light or the scene's view, as before.
- **A component that owns its state** (a game's kind, a script) is written
  by the registry. Its entry in the scene file's `components` array names
  its model by its place among the models written, or -1 for the scene:

  ```json
  {"kind": "Stamina", "enabled": true, "model": 3,
   "fields": {"value": 40, "max": 100, "sprinting": false}}
  ```

Loading reads the fields by name:
- a field the file does not name keeps its default, so a file from before
  the field existed loads;
- a name the kind no longer has is counted and skipped;
- an enum value the kind no longer offers leaves the field as it was;
- a component of a kind the loading program has not registered is **kept**
  and written back when the scene is saved.

A game's script, opened in an editor that has not built it, survives the
round trip.

## Scripts

A script is a component kind in a file of its own, built into a shared
library and opened at run time (`ae3d.script`). The file declares its state
struct, `create` and `destroy` for it, `fields(k)` registering what the
inspector shows and the scene saves, and whichever of Unity's phases it
needs -- `awake`, `start`, `update`, `fixed_update`, `late_update`,
`on_destroy`. `script.script_kind(lib, name)` registers it under Scripts;
from there it is given to objects as any component is. A game that compiles
its scripts in registers the same functions with `component.kind` directly,
so one file serves the editor and a shipped game.

`script.script_reload(kind, old, new, scene, others)` swaps a rebuilt
library under every object carrying it: each attachment's fields are read
out, its state freed by the old library and made again by the new, and the
fields written back by name.

**One Aether runtime per process.** A script is Aether code, and Aether code
calls the runtime -- its strings, its allocations, the accounting it keeps
of both. Two runtimes in one process, the program's and a script's, each
free what the other allocated and the books underflow (the runtime asserts
it). So a script uses the program's runtime:
- on Linux the program exports its symbols (`-rdynamic`) and the script
  leaves the runtime to be found in it;
- on macOS the script is linked `-undefined dynamic_lookup`;
- on Windows, where an executable exports nothing a DLL can import, the
  runtime is a DLL of its own, `build/aether_runtime.dll`, made from the
  toolchain's static library by `scripts/native.sh`, which every program and
  every script links, as both link the engine's C (`libae3d_native`).

aether-lang-dev/aether#2297 asks the language for that library: the runtime
and the engine as one library that a program and its scripts link, on every
platform.

## Asked over the channel

`object.list`, `object.get`, `component.kinds`, `component.get`,
`component.set`, `component.add`, `component.remove` and
`component.enable` ([the agent channel](agent.md)). An object is named by
its index, its name, or `Scene`. `component.kinds` gives every kind with
each field's type, range, choices and tooltip: what an agent needs to write
a valid value without having read the source. `tests/test_agent_components.ae`
drives each over a socket.

## Held to

- `tests/test_components.ae`: registration, ranges, enums by name, text
  through accessors, rotations normalised, the JSON round trip in full and
  as differences, a file from before a field and one naming a field that is
  gone, reset, copying, one per object, the script's own store on an
  `@observable` state bumping the version, the observer taken off when the
  object is freed, a thousand components added and freed, the engine's
  kinds writing through to the model, the material, the light and the
  engine, the scene's root running first and never listed, and a scene
  file carrying components that own their state, with one of an unknown
  kind kept.
- `tests/test_agent_components.ae`: the channel's ops.
- The editor's driver (`tools/drive_editor.ae`) presses the panels on both
  renderers ([the editor](editor.md)).
