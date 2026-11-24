### Streamed cells' colliders and walkers (#917, the rest)

- `stream.set_physics(st, on, friction)`: a cell's `FLAG_COLLIDER` models
  become static colliders. Their collision meshes are built on the worker
  with the decode, and each model attaches as a game object with a mesh
  collider, destroyed when the cell leaves.
- `stream.set_nav(st, field, low, high, grow)`: a resident cell's
  `FLAG_NAV` models block the walkers' field when it arrives and are
  unblocked before it leaves.
- `ae3d.nav`: a cell counts what blocks it. `flow_unblock_mesh` and
  `flow_unblock` are new: each takes one blocker off each cell of a
  footprint, so a cell another blocker holds stays blocked. A grown
  footprint changes each cell once, however many marks reach it (stamped
  discs are gathered first). Every existing read is zero or non-zero, so
  nothing reads differently.
- `test_nav`: a grown row unblocked opens what it blocked, two overlapping
  footprints keep the shared cells blocked, a footprint over a game's own
  block leaves it, and `flow_open` and `flow_unblock` behave. With the old
  set-to-one semantics, two of these fail.
- `test_stream` adds: a resident cell's crates block the field, cells not
  there block nothing, and the field is open again once every cell is let
  go (19 checks, 0 leaks).
- `test_stream_drive`, new: a ball at 30 m/s on streamed ground in a
  running engine never falls through (it does without the streamed
  colliders). Its p99 frame is 9.41 ms streamed against 9.61 ms with
  everything loaded.
- `docs/streaming.md` and `docs/crowds.md` updated.
