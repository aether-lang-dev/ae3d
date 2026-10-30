### The environment map on the Environment component (#869, Nic 875-7)

- `environment map` (a path), `environment intensity` and `environment yaw` are
  fields of the scene's Environment component, so the scene file, the editor's
  Scene panel and `component.get`/`component.set` carry them in one change.
  Intensity 1 is the file's own values (Nic, 875-4). Only fields that differ from
  the defaults (none, 1, 0) are saved, and a save from before loads with no map.
- The scene file's `view` gets an `environment` object (`image`, `intensity`,
  `yaw`), each key written only when it differs; `engine_view` and
  `engine_apply_view` carry it. Loading a scene sets the map the file names (the
  sky for an older file), reading the file only when the path changed.
- `engine_set_environment` keeps the path and scale it had when the map would not
  load, so what is read back is what lights the scene.
- The editor's asset picker for the map lists resources/environment/*.hdr and
  *.exr, then Browse.
