### Scripts are components (#508)

- A script file is a component kind: its state is a struct of its own, one
  for every object it is on; `fields(k)` declares what the inspector shows
  and the scene saves; its phases are Unity's (`awake`, `start`, `update`,
  `fixed_update`, `late_update`, `on_destroy`), each optional.
  `script.script_kind` registers a built library under Scripts, and an object
  is given one as it is given any component.
- The four scripts in `resources/scripts` keep their state per object: two
  objects bobbing had one clock between them, two pulsing one size to
  breathe about. Each is tunable in the inspector (bob's rate and height,
  orbit's rate, pulse's rate and depth, spin's speed). Orbit starts from
  where the object stands rather than jumping onto its circle.
- A library rebuilt while the editor runs is swapped under every object
  carrying it, and every one deleted and kept for undo: each keeps its
  fields, its state made again by the new code.
- The editor's Behaviour buttons put a script component on the object, and
  Add Component gives it more than one. Attaching and taking off undo as
  component steps. A scene saves a script as a component with its fields,
  and one naming a script the project lacks is kept and written back.
  Scenes from before still load their scripts by name.
- One Aether runtime per process. A script's Aether code and the program's
  shared nothing, so each would free what the other allocated and the
  runtime's accounting would underflow.
  - Linux programs now export their symbols (`-rdynamic`).
  - macOS scripts link `-undefined dynamic_lookup`.
  - On Windows the runtime is `build/aether_runtime.dll`, made from the
    toolchain's `libaether.a` by `scripts/native.sh`, with the optional
    libraries the archive calls into. Every program and script links it, as
    both link the engine's C.
  - aether-lang-dev/aether#2297 asks for that library from the language.
- `tests/test_script.ae` (13 checks): the libraries open as kinds, two
  objects keep two states and move by their own fields, a transient field is
  not saved, and a reload keeps what each object was set to.
