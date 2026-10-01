### Engine and editor pack (#520, #521, #523, #524, #525)

- **ae3d is a dependency** (#524). `aether.toml` exports `src/ae3d`, so a game
  that names ae3d in its own manifest, patched to a checkout, imports
  `ae3d.*` with no `--lib`: `examples/spinning_cube.ae` builds unchanged from
  a project outside the engine. `docs/building.md` says what such a project
  restates. The engine finds the files it ships with through
  `core.resource_path` -- the working directory, `AE3D_ROOT`, beside the
  executable or above it -- so a game's HUD has its font.
- **The sky and the clouds set before `engine_run`** (#525) no longer crash
  the program: before the device exists they are kept, and made when the
  engine starts. `engine_set_sky` and `engine_set_time_of_day` keep the last
  one asked for, as they do after. The skybox suite sets the sky, clouds and
  overcast in `main` on both backends; without the fix it dies with signal 11.
- **Scripts run while the scene runs** (#520), as in Unity: Simulate and Play
  run them, edit mode does not. Stop gives every object its place, turn and
  scale back (they were kept for bodies alone) and every running component its
  fields, to start afresh the next time. The driver attaches a script, sees
  nothing move, simulates, sees it move, stops, and reads the scene as it was.
- **A component folds from its whole header** (#521), not its 10 px caret.
- **`round_trip_floor_us`** (#523): the least of a peer's last sixteen round
  trips, the link without the frames a ping waits for, in `ae3d.net` and
  `net.stats`. `test_agent_net` holds `net.set_link` to it rather than to the
  smoothed round trip, whose frames made the check fail 2 times in 74.
