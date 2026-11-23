# Saving and loading

`ae3d.persist` saves a running game to a slot and reads it back over the
scene it was played from. What is saved is declared, not written:

- every field a component's kind registers (or its struct's schema declares:
  [scripting.md](scripting.md#its-fields)) that is neither hidden nor
  transient, and only where it differs from its default;
- every object's transform, whether it is active, and its components;
- the objects spawned since the scene was loaded, and the ids of those
  destroyed since;
- what each system keeps that no field holds: a body's motion and its sleep.

## A save menu

```aether
// Once the scene is loaded, as authored: what saves are written over.
base = persist.baseline(engine.engine_scene(e))
persist.set_spawner(make_crate, e as ptr)        // what makes a spawned object back

// Save: the game captured on this frame, written by a worker.
save_slot(e: *Engine, base: *Baseline, slot: int, played: float) -> *SaveJob {
    engine.engine_view_render(e, g_thumbnail_view, engine.engine_camera(e))   // a small view
    picture = engine.engine_view_pixels(e, g_thumbnail_view)     // 160 x 90, RGBA
    return persist.save_async(engine.engine_scene(e), base, "saves/${slot}.save",
                              "Slot ${slot}", played, null, picture, 160, 90)
}
// Each frame after: persist.save_finished(job), then save_job_ok or save_job_error.

// The menu: each slot's details and picture, without reading its game.
list_slot(slot: int) {
    info = persist.slot_info("saves/${slot}.save")
    if info == null { return }                               // empty, or not a save
    png, length = persist.slot_picture("saves/${slot}.save")
    show_slot(json.get_string_raw(json.object_get_raw(info, "title")),
              json.get_number(json.object_get_raw(info, "play_seconds")), png, length)
    json.free(info)
    free(png)
}

// Load: the scene loaded again as authored, then the slot read over it.
load_slot(e: *Engine, slot: int) -> bool { return persist.load(engine.engine_scene(e), "saves/${slot}.save") }
```

## What the frame pays

A save reads the game once, on the frame, into a capture: flat 8-byte slots
with nothing allocated per field. The capture holds each object's id, names,
transform and changed fields, each kind's names and choices once, and each
system's records. Everything else is done from the capture alone, on any
thread, while the game goes on and kinds are redefined (a script reloaded):

- the document it is written as;
- the text, the deflate and its CRC-32;
- the atomic write to disk.

`save_async` does all of that on a worker (std.worker), so the frame pays
only for the capture. `save` does it all before it returns.

`benchmarks/bench_persist`, 2,000 objects of five changed fields each, best
of seven on an M1 Pro:

| | ms |
|---|---|
| the capture (the frame's part) | 0.38 |
| the capture as a document | 3.9 |
| a save, capture to disk | 20.5 |
| a load | 4.9 |

Every lookup by id is a hash table's, the baseline's and the scene's. A save
of 2,000 was 8.1 ms on the frame before: the document was built on the frame,
and each object was looked up by walking the scene, four million comparisons.

## Slots

A slot file is:

1. "AE3S" and the slot's format (2);
2. the details as text (title, when it was saved, play time, the game's own
   fields), for a menu to list without reading the rest;
3. the picture, a PNG or nothing, read with `slot_picture`;
4. the state, deflated, with its CRC-32.

It is written atomically: a crash mid-save leaves the slot it had. A slot
cut short or changed reads as damaged, not as a game. A slot of format 1,
from before slots had pictures, reads as it did.

`save_json` and `load_json` write and read the same document as text, for a
diff or a bug report.

## Versions

Every save records each kind's schema version. A save from an earlier
version is read through:

- the kind's renames (`component.rename_field(k, old, new, version)`);
- the migrations registered for each step since
  (`persist.migration(kind, version, apply)`), oldest first.

A field added since takes its default, and one removed is dropped and
counted (`last_unknown`).

## A system's own state

A system saves what no component field holds by registering a provider:

```aether
persist.provider("physics", 8, save_bodies, load_bodies, p as ptr)
```

On the frame its `save` appends records of that many numbers to the capture
(`component.put_float`). `load` reads them back, as
`systems.<name>.records`, once every object of the save is in the scene with
its transform and components. Two providers of one name (two physics worlds)
write one list, and each keeps to its own scene.

`ae3d.physics` saves every moving body: its object's id, its velocity, its
spin, and whether it is awake. Loaded, each body is put where its object was
saved. Before, a dynamic body wrote the scene's place back over the loaded
object at the next step.

**What a load gives back, and what it cannot.**

- Every body is where it was, as fast and as awake, to the bit: std.json
  writes a double whole.
- Two loads of one save step the same, body for body, to the bit
  (`test_persist_bodies`, 300 steps): a late joiner seeded from a host's save
  goes on as every other peer loaded from it does.
- A load cannot step as the world it was saved from went on. The solver
  carries each contact's impulses from step to step, which a save does not
  hold, and a loaded world's contacts begin again.

The animator's clips and times are the motion layer's to provide (#853).

## Checkpoints

`persist.checkpoint(scene)` is the scene as it is now, every object in it
with its model. `persist.restore(scene, doc)` puts a live scene back to it:

- what was made since is destroyed;
- what was destroyed since is made back by the spawner (counted in
  `last_missing` where there is none);
- one waiting to be destroyed is kept;
- every field and body is as it was.

The agent channel's `persist.checkpoint`, `persist.rollback` and
`persist.checkpoints` are these ([agent.md](agent.md)): an agent building a
game keeps the scene, tries something, and puts it back.

## What holds it

- `test_persist`:
  - a played scene comes back whole from a slot and from text;
  - a damaged slot is refused, and a version 1 save migrates;
  - a save off the frame writes the same slot, and one that cannot be written
    says why;
  - captured fields are byte for byte `component.to_json`;
  - a capture survives its kind's redefinition;
  - a slot's picture decodes to the pixels given, and a format 1 slot loads;
  - a checkpoint restored in-process: what was made since goes, what is
    queued for destruction is kept, and what was removed comes back through
    the spawner or is counted;
  - a thousand saves and loads in a row, held to no leak by `leaks`.
- `test_persist_bodies`: moving bodies saved and loaded, and two loads stepped
  together.
- `test_agent_checkpoint`: the channel's checkpoint and roll back.
