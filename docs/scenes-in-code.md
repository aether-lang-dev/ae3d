# Scenes in code

`ae3d.scenedsl` writes a scene as the shape it is. A block's nesting is
the hierarchy. What a model carries goes inside its block. What it builds
is what a scene file loads into: the same models, lights, attachments and
components, ready for `scenedsl.place` or for anything that takes a loaded
scene.

```aether
import ae3d.scenedsl
import ae3d.scenedsl (scene, cube, scale, position, polished_metal, sun, camera, look_at, component, field)

s = scene() {
    sun(0.4, 0.8, 0.5)
    camera(0.0, 20.0, 90.0) { look_at(0.0, 0.0, 0.0) }
    cube(1.0) {
        scale(20.0)
        polished_metal(0.85, 0.35, 0.2)
        component("Spinner") { field("pitch", 18.0) field("yaw", 30.0) }
        cube(0.3) { position(0.0, 1.2, 0.0) }
    }
}
objects = scenedsl.place(e, s)      // each model an object, the lights lit, the components on
engine.engine_run(e)
engine.engine_free(e)
scenedsl.release(s)                 // after the engine: its lights are the scene's
```

`examples/spinning_cube.ae` is written this way.

## How it builds

Every builder takes the block it is written in as its hidden first
parameter. This is Aether's `_ctx`, the mechanism aether-ui's widgets use:

- a model in the scene's block is the scene's;
- a model in a model's block is that model's child (`core.model_set_parent`);
- a light in the scene's block is one of the scene's lights, and the first
  one is the key light;
- a light in a model's block is that model's own: the light a marker stands
  for;
- a component goes on the model whose block it is in, or on the scene's
  root.

Write `scene()` with its parentheses. `s = scene { ... }` gets past the
checker, but it binds `s` to the function and runs the block with no scene
around it.

A builder written where it means nothing does nothing and is counted. So
does a model whose file does not read. Its block's builders are skipped
with it. `scenedsl.errors(s)` gives the count, and `scenedsl.error(s)`
what the first one said.

| Builders | For |
|---|---|
| `model(path)`, `mesh(path)`, `group(name)`, `cube(size)`, `sphere(radius, segments, rings)`, `quad(w, d)`, `plane(grid, spacing)` | a model: an OBJ file (read once however many name it), a mesh file a scene was saved with, a group to hang children on, the loader's shapes |
| `name`, `position`, `scale`, `scale3`, `rotate` (degrees, as `core.model_rotate`), `rotation` (a quaternion), `hidden`, `no_shadow`, `shader` | the model |
| `polished_metal`, `rough_metal`, `metallic`, `plastic`, `matte`, `glossy`, `glass` | core's surfaces, on every material the model has |
| `material() { ... }`, `diffuse`, `specular`, `surface(name, value)`, `texture`, `normal_map`, `tile_breakup`, `emissive(r, g, b, strength)`, `emissive_map(path)` | the model's material as a scene file sets it: its numbers start as a new material's, and are then set by the file's names (`"roughness"`, `"embers"`, the list is `scene.material_number_name`) |
| `uniform`, `uniform_int`, `uniform_vec3`, `uniform_values(name, vec3) { value(...) }` | the model's shader settings |
| `sun`, `directional_light`, `point_light`, `spot_light`, `light()`; `color`, `intensity`, `direction`, `position`, `range`, `cone` | a light, as core makes it |
| `body(kind, collider)`, `record(name)`, `script`, `kind` | what the model carries, in the scene file's records: a body and its fields (`"friction"`, `"trigger"`), water, a voxel world, a figure, motion |
| `camera(x, y, z) { look_at(...) }`, `component(kind)` | the scene's Camera component; any component, by its kind's name |
| `field`, `field_int`, `field_bool`, `field_text`, `field_vec3`, `field_quat`, `field_append`, `field_object(name, node)` | the fields of a light, a record or a component, by the file's names; `field_object` names another model's node, which a builder answers (`dog = sphere(0.5) { ... }`) |

Models, materials and shapes are made the way a program makes them, by the
loader and core. Everything else is written as the scene file's own record
and read by the file's own reader (`scene.attachment_of`,
`scene.load_light`). For those, the DSL and the file agree by
construction.

## From a saved scene

`scenedsl.write_from_file(json, path)` writes a saved scene as an Aether
module whose `build()` is the scene. The editor writes one beside every
Save: `street.json` gets `street.ae`. In it:

- a model saved with a source is `model(path)`, and one with a mesh file is
  `mesh(path)`;
- its material is a `material()` block holding what differs from a new
  material;
- its records and components are `record`, `light()` and `component`
  blocks, field by field;
- a component that names another model comes after every model, written
  against that model's variable.

A water surface's uniforms are not written. The water sets them again when
it is made, as it does for a loaded file.

## What holds it

`test_scenedsl` builds a scene of every kind of builder: a group, an OBJ
model, shapes, a `material()` block, uniform arrays, bodies (one a
trigger), lights in both places, water, the camera, and a game's component
naming another object. Then:

1. The scene is placed in an engine, saved and loaded back. Every model's
   name, transform, parent, mesh, material and uniforms matches, and so do
   the lights, the records and the components.
2. The file is written as code. That code must be byte for byte
   `tests/fixtures/scene/written/module.ae`. On a mismatch the test leaves
   what it wrote in `build/scenedsl/written.ae` to be copied over, where
   the change is meant.
3. The test is compiled with that module. What its `build()` makes matches
   the file in the same way.
