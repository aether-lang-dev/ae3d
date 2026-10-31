### World text: upright, sized in pixels, outlined and shadowed; closed camera paths (#876, #889 answers)

Nic's answers to the #876 and #889 questions, the four items for one PR (876-4, 876-5, 876-8, 889-4):

- `hud.world_text_upright`: a label turned to the camera about the world's up only (876-4).
- `hud.world_text_pixels(h, on)`: sizes in screen pixels, the scale found at each draw from that draw's camera and
  the shown height of its frame, so it holds per view and under the render scale (876-5).
- `hud.world_text_outline` and `hud.world_text_shadow`: runs of their own under the text, the outline by the HUD's
  lowered-threshold rule (876-8). The edge reaches the pixel shader as a flat int in 65536ths (0.5 exactly as
  32768), so a plain run's frames are unchanged byte for byte. Depth, pixels, outline and shadow are state until
  the frame's clear, as `world_text_depth` was (876-7).
- `campath.set_closed(p, seconds)`: a last-to-first segment, the Catmull-Rom tangents wrapping (889-4).
- Tests: `test_worldtext` (54, CPU: facings, the pixel scale for perspective, orthographic and a half-height frame,
  the outline edge against the HUD's rule, the shadow's offset, the clear), `test_world_text` (65, both backends:
  the new frames held to each other, and the old ones byte for byte against main), `test_gpu_lettering` (35, the
  edge varying and a lowered edge on the CPU), `test_campath` (the closed path's values worked by hand, C1 round
  the loop). Negative controls: the shader with the edge ignored fails the outline checks; the tangents unwrapped
  fail four closed-path checks.
