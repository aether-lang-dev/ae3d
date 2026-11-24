# Scripting

A script is a component kind in a file of its own: a struct, the fields it
shows and saves, and the phases it runs. This page takes a new author from an
empty folder to an object that moves and is tuned from outside its code, then
says what each part is.

## From an empty folder

```bash
git clone https://github.com/aether-lang-dev/ae3d && cd ae3d
git submodule update --init
./build.sh tools/new_game.ae
./build/new_game ../my_game "My Game"      # aether.toml, main.ae, scripts/spinner.ae, README.md
cd ../my_game
git init && git submodule add https://github.com/aether-lang-dev/ae3d ext/ae3d
git -C ext/ae3d submodule update --init
AE3D_ROOT=ext/ae3d ae run main.ae          # a window: crates fall, a lamp turns
```

`new_game` writes nothing over a file that is there. What it wrote:

- `aether.toml`: ae3d and aephysics as dependencies, patched to `ext/`
  ([building.md](building.md#ae3d-as-a-dependency) says why each line is
  there).
- `main.ae`: the scene, built in code. A sun, the ground, six crates on
  bodies that fall onto it, a lamp, and the script registered as a kind and
  given to the lamp.
- `scripts/spinner.ae`: the script.

## A script

This is `resources/scripts/bob.ae`, as CI builds it:

```aether
import ae3d.core
import ae3d.behaviour
import ae3d.component

@derive(schema)
struct Bob {
    rate: float @range(0.0, 20.0) @default(2.0) @tooltip("Radians of the curve a second.")
    height: float @range(0.0, 100.0) @default(6.0) @tooltip("Metres from the middle to the top.")
    // Where it is along the curve is what it works out, not a setting.
    clock: float @transient @readonly
}

update(b: *Bob, go: *GameObject, delta: float) {
    m = behaviour.object_model(go)
    b.clock = b.clock + delta
    step = core.cos_of(b.clock * b.rate) * b.height * b.rate * delta
    core.model_set_position(m, m.position.x, m.position.y + step, m.position.z)
}
```

The struct is the whole declaration:

- **One state per object.** The engine makes a `Bob` for every object the
  script is on, with its `@default`s, and frees it with the object.
- **Fields from the struct.** `@derive(schema)` has the compiler describe the
  struct, so every field is the inspector's, the scene file's, a save's, the
  network's and the agent's, by name. Nothing is kept beside it that could
  drift.
- **Phases by name.** `update` is found by its name and called every frame,
  handed the object's own `Bob`.

Two objects carrying it are two bobs. `test_script` holds that: two objects,
one set to a height of 12, each moving by its own height on its own clock.

### Its fields

| A field's type | Is | With |
|---|---|---|
| `float` | a number | `@range(lo, hi)` holds what is written |
| `int` | a whole number | `@range`; `@enum("calm", "storm")` a choice by name; `@object` another object's id |
| `bool` | a switch | |
| `Vec3` | a vector | `@color` a colour, 0..1 a channel |
| `Quat` | a rotation, shown in degrees | the identity when it has no default |

Every field may also take:

- `@default(...)`: what a new state holds. One argument for a number or a
  bool, three for a `Vec3`, four for a `Quat`.
- `@tooltip("...")`.
- `@transient`: worked out as the script runs, never saved.
- `@readonly`: shown, not edited.
- `@hidden`: neither shown nor saved.

A field of any other type (a pointer, a list, a struct of the game's own) is
the state's own bookkeeping: it is not registered.

**Text.** A struct holding a `string` frees it itself: only code that knows
the struct can let the string go. Such a script writes its own `create` and
`destroy`, with `heap.new` and `heap.free`, and registers the text field
beside the schema's fields through `fields(k)` with `component.text_field`.
Its numbers still come from the schema. The loader refuses one that holds a
string and has no `create` and `destroy`, and says so.

### Its phases

Each phase is optional, found by its name, and called with the script's
state and its object. Unity's names, in Unity's order:

| Phase | When |
|---|---|
| `awake(s, go)` | as it is added, before anything else |
| `on_enable(s, go)` | as it comes to run: added enabled to an active object, enabled, its object made active |
| `start(s, go)` | before its first update |
| `update(s, go, delta)` | every frame |
| `fixed_update(s, go, step)` | every fixed step, before the physics steps; not run on an object another peer simulates |
| `late_update(s, go, delta)` | after every object has updated |
| `on_collision_enter(s, go, hit)`, `_stay`, `_exit` | what its colliders touch, after each physics step ([physics.md](physics.md#collisions-and-triggers)) |
| `on_trigger_enter(s, go, other)`, `_stay`, `_exit` | what overlaps its triggers, or the trigger it is in |
| `on_net_spawn(s, go)` | on the network, on every peer, once ([networking.md](networking.md#a-networked-objects-spawn)) |
| `on_disable(s, go)` | as it stops: disabled, its object made inactive, taken off |
| `on_destroy(s, go)` | as it is taken off, after `on_disable` |

A disabled component is not updated and is not told of contacts. It is told
`awake` and `on_net_spawn`, which come once. Destroy an object from a phase
with `behaviour.scene_destroy_later`: the scene is walking its objects, and
one freed under it is a freed object walked.

**The state's type.** A script only ever loaded (by the editor, or by a
program that opens libraries) may take its state typed, as `bob.ae` does. A
script that is also compiled into a program takes it as `ptr` and casts once
(`s = p as *Spinner`), because the program hands the phase to a
`fn(ptr, ...)` slot. A typed function there passes Aether's checker and fails
the C compiler. `scripts/spinner.ae` from `new_game` serves both.

**Another component, another object.**

- `behaviour.object_find(go, "Player")` finds an object of the same scene by
  name.
- `component.state_named(go, "Health") as *Health` finds the state of one of
  its components by the kind's name, and `component.state_of(go, kind)` by
  the kind.
- `physics.rigidbody_of(go)` finds its body.

The lookup by kind hands back a `ptr` and the caller casts: a function cannot
say the type of what it finds until Aether has type parameters
(aether-lang-dev/aether#1973).

## Building and loading

A script is built into a shared library:

```bash
scripts/build_script.sh resources/scripts/bob.ae     # -> build/scripts/bob.dylib, .so or .dll
ext/ae3d/scripts/build_script.sh scripts/spinner.ae  # a game's, from the game's root
```

It is opened with `script.script_open(path)` and registered with
`script.script_kind(lib, "bob")`. The file is the component: `bob.ae`
declares `Bob`, and `health_bar.ae` declares `HealthBar`, whose schema the
loader finds as `HealthBar_schema`. From there it is given to objects as any
component is: `component.add(go, kind)`, or the editor's Add Component, under
Scripts.

A program can compile a script in instead. It imports the file and registers
it the same way the loader does:

```aether
import scripts.spinner

spin = component.schema_kind("Spinner", "Gameplay", spinner.Spinner_schema())
component.phases(spin, null, spinner.update, null, null)
```

The other phases are set the same way, with `component.set_lifecycle`,
`set_activation`, `set_collisions`, `set_triggers` and `set_net_spawn`.

**Built against this engine, or refused.** A script carries its own copy of
every module it imports, so it reads the host's objects through its own idea
of their layout. Built against another tree, it misread them. Every library
now says the layout it was built against: a number over the size of every
struct a script is handed or reaches through them, and the offset of every
field of the ones it is handed (`component.script_layout`). The loader
refuses a library that says another layout, or says none, by name:

```
build/scripts/spin.dylib: built against another engine (its layout 1648926714835107229,
this engine's -2900443801382028435); rebuild it with this tree (scripts/build_script.sh)
```

**Hot reload.** `script.script_reload(kind, old, new, scene, others)` swaps a
rebuilt library under every object carrying it:

1. A component that runs is told `on_disable` by the old code.
2. Its fields are read out, and its state freed by the code that made it.
3. A new state is made by the new code, and the fields are written back by
   name. A field the new code renamed takes its default.
4. It is told `on_enable` by the new code, and `start` runs again next frame.

The editor does this when a script's library changes on disk.

## What holds it

- `test_script` opens the built scripts and checks:
  - each script's fields, defaults and flags as its struct declares them;
  - two objects carrying `bob` keep two states;
  - a save writes `height` and not the transient clock;
  - a reload keeps each object's fields;
  - a library with no layout, and one with another engine's layout, are
    refused by name (`tests/fixtures/scripts`).
- `test_components` checks a kind read off a struct's schema:
  - every field type and attribute above, and the defaults;
  - ranges held, and a save and load;
  - a struct holding a string refused;
  - the order of `awake`, `on_enable`, `on_disable` and `on_destroy` through
    every change of enabled, active and attached.
- `test_contacts` checks the collision and trigger phases
  ([physics.md](physics.md#collisions-and-triggers)).
- `test_net_spawn` checks `on_net_spawn` on a host and a client.
