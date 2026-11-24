### Saves: off the frame, a system's own state, checkpoints, pictures (#507)

- **The frame pays only for a capture.** `persist.capture` reads the game into
  flat slots: no allocation per field, and each kind's names in a table of its
  own. The document, the text, the deflate and the disk are done from the
  capture alone, on any thread. `save_async` does them on a worker
  (`save_finished`, `save_job_ok`, `save_job_error`); `save` does them in
  place.
  - 2,000 objects: 0.38 ms on the frame, down from 8.1 ms
    (`benchmarks/bench_persist`).
  - A load takes 4.9 ms, down from 8.0: every id is a hash table's. Each
    object was looked up by walking the scene, four million comparisons a
    save.
- **What no field holds** (`persist.provider(name, width, save, load,
  context)`): a system appends records of numbers on the frame and reads them
  back over the loaded objects. `ae3d.physics` saves every moving body's
  velocity, spin and sleep.
  - **Bug:** a loaded scene's dynamic bodies went back to where the scene had
    them at the next step. They are now put where their objects were saved.
  - Two loads of one save step the same, to the bit, for 300 steps
    (`test_persist_bodies`). Why a load cannot match the world it was saved
    from, the solver's contact impulses: `docs/persistence.md`.
- **Checkpoints.** `persist.checkpoint(scene)` and
  `persist.restore(scene, doc)` put a live scene back:
  - what was made since is destroyed;
  - what was destroyed since is made back by the spawner;
  - one queued for destruction is kept (`behaviour.scene_spare`).

  The agent channel's `persist.checkpoint`, `persist.rollback` and
  `persist.checkpoints` use them (`test_agent_checkpoint`).
- **A picture in the slot.** Slot format 2 keeps a PNG between the details and
  the state. `save` and `save_async` take the RGBA of a view, and
  `slot_picture` reads it without the state. `png.encode` writes a PNG in
  memory, which `png.write` now uses. A format 1 slot loads as it did.
- `test_persist`, 42 checks: a save off the frame, the capture byte for byte
  `component.to_json`, a capture across its kind's redefinition, the picture,
  format 1, a checkpoint restored in-process, and a thousand saves and loads
  under `leaks`.
- `docs/persistence.md`: a save menu in 26 lines, and what each part costs.
