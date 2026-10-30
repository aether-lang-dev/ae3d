### Camera controllers: an orbit camera and a keyframed path (#823)

- `ae3d.orbitcam`: an orbit camera lifted from the editor's viewport (target, distance, yaw, pitch, limits; a drag
  at 0.35 degrees a pixel after a 3 pixel slop, the wheel at 1.12 a notch, the arrow keys), put on a camera by
  `orbit_apply` or driven from the engine's update by `orbitcam.attach`. The editor now uses it: one
  implementation, with the editor's own limits (8..8000, 85 degrees) and the same arithmetic.
- `ae3d.campath`: keys of (time, position, target or yaw/pitch, fov), a Catmull-Rom Hermite spline over the keys'
  times for position and fov, slerp for orientations (target-to-target segments interpolate the target and look at
  it), play, pause, stop, seek, loop and a negative rate, driven from the engine's update by `campath.attach` onto
  the engine's camera or a view's. Neither is a scene component, and neither touches the animation or motion
  modules.
- `examples/camera_rig.ae`, `docs/rendering.md` "Camera controllers", `tests/test_orbitcam.ae` and
  `tests/test_campath.ae` (headless, 15 + 23 negative controls caught) and `tests/test_camera_path.ae` (frames on
  both backends, a view following a path).
- Nothing changes for a program that does not use them: the frames are the same (`frames_against`).
