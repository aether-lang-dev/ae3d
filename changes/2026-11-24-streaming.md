### Streaming a world larger than memory (#917, its core)

- `ae3d.cellfile`, new: a cell's models in one binary file. It holds their
  vertices as the renderer takes them, their indices and instances, their
  materials as JSON, their world transforms, and what each is to the world
  (drawn, shadowed, a collider, a nav blocker). `decode` touches nothing
  the loop thread does, so a worker runs it: the file, the meshes, the
  materials' JSON and the textures it names. `instantiate` hands a decoded
  mesh to a model.
- `ae3d.worldbake`, new: a scene cut into a grid of cells by where each
  model's bounds' centre stands, plus each cell's stand-in. A stand-in
  merges the cell's models drawn once, simplifies them to the coarsest cut
  of their cluster graph with no crack between materials, and bakes each
  texture's mean colour, in linear light, into the material, so it holds
  no texture. `world.json` names them.
- `ae3d.stream`, new: the cells loaded around any number of foci (the
  camera, a host's players).
  - Each cell is a state machine: unloaded, loading (on a worker),
    leaving, loaded, attaching (models to the renderer within a per-frame
    byte budget, nearest first) and resident.
  - A cell is wanted within the radius, kept to the radius plus a margin,
    and its stand-in is drawn out to the far radius wherever the cell is
    not resident.
  - Arrival and departure are reported as events. Memory is counted as
    resident bytes and peak bytes.
  - `stream.cells` on the agent channel reports every cell that is not
    unloaded.
- `core.offer_preloaded_image` / `drop_preloaded_image`: a picture decoded
  elsewhere is handed to the renderer for the model that names it.
- `scene.material_json` / `material_from_json` are exported.
- `test_stream`, new: a 512 m world of 256 cells (2,048 models, 1.32M
  triangles; the stand-ins are 0.20M) is baked and driven across at
  30 m/s in real time. It checks that:
  - no cell within 64 m of the focus was ever missing;
  - what is held stayed under the stated ceiling (15.2 MB of 23.3) and
    under half of the whole world held;
  - a stand-in is drawn exactly where its cell is not;
  - every cell left behind was let go;
  - pacing 2 m either side of a border loads its cell once (six times with
    no margin);
  - the cell file round-trips;
  - nothing leaks.
- `docs/streaming.md`, new.
