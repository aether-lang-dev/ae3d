### Engine pack: the controller's limits, the cursor injected, the night (#526, #527, #528)

- **The character controller refuses what it should** (#527). A plane that
  pushes the capsule up is a wall on the ground, and a steep one is in the
  air: walking into a 50 or 60 degree ramp it no longer climbs (its feet rose
  3.2 and 4.6 m), and a 0.4 m kerb, past its 0.35 m step, stops it at the
  face instead of being crossed. Steps, walkable ramps, jumps and pushes are
  unchanged (test_character, 14 checks).
- **The cursor and the wheel can be injected** (#528): `inject_cursor` and
  `inject_scroll`, read by the next poll as injected keys are, released by
  `inject_clear`; `mouse_frame_x`/`mouse_frame_y` give the cursor in
  framebuffer pixels, the HUD's space; the agent channel's `input.set` takes
  `cursor` and `scroll`, and `input.get` reports them. A HUD menu can be
  clicked headless or by an agent (test_input, test_agent).
- **The night** (#526). The key light is the moon once the sun is under,
  lit and shadowed from above; the procedural sky is drawn from the hour,
  with stars and the moon's disc at night, whatever the key light is; and a
  light's back fill is no longer shadowed. At 22:00 the ground reads the same
  with shadows on and off on both renderers (it read 30 and 45), and turning
  the key light round no longer turns the sky to day (test_engine_skybox).
