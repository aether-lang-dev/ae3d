### Render interpolation for what the fixed steps move (#563)

- A model moved during a fixed step (physics bodies, ragdoll bones,
  anything a `fixed_update` writes) is drawn between its last two steps by
  the frame's share of the next one. It is interpolated in world space under
  its parent as the parent is now, put there for the draw only and taken
  back after (Godot's semantics). Scripts and the simulation always read
  the steps' pose.
- `core.model_interpolated_position` / `_rotation` give the drawn pose at
  `engine_step_fraction(e)`, for a camera that follows a body.
  `core.model_reset_interpolation` is for teleports.
  `engine_set_interpolation(e, on)` turns it off, as do `AE3D_INTERPOLATE=0`
  and a fixed tick (`AE3D_TICK`).
- The issue's falling ball, on the real clock: 57 of 98 frames drawn
  unmoved before (the worst 6.1 times what its time asks); none of 101 after
  (the worst 1.005 times). `tests/test_interpolation.ae`.
