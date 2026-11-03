### A view's shadow atlases: its own, sized to it, while shadows are on (#878, #879, #880)

Nic's answers to the three (2026-11-02), for one PR:

- A view with shadows on has its own cascades' atlas and its own pair of lamps' atlases, the lamps in them chosen by
  its own budget for its own camera (option 1). On Vulkan a view had no lamps' atlases at all (`view_reset` nulled
  them and `view_make` never made them), so a lamp that was the key light threw no shadow in a view (#878).
- The rule, the same on both renderers: a view's atlases exist exactly while shadows are on for it, whenever that
  became true. A view made with shadows on makes them on its first frame; `renderer_set_shadows(r, true)` makes them
  for every live view, and `false` lets every view's go (the window keeps its own). An OpenGL view made while
  shadows were off had been unshadowed for good (#879); every Vulkan view had made a 64 MiB cascades' atlas with
  shadows off (#880).
- A view's atlases are the window's scaled to it (`rendering.view_atlas`): the window's 4096 square (or the
  cascades' atlas `AE3D_SHADOW_SIZE` sets) times the larger of the view's width and height shares, never more than
  the window's, never under 1024 texels, where a lamp's face is 128 texels. A view half the window's size holds a
  quarter of the depth. The lit shader reads a lamp's face size from its atlas (`textureSize / 8`) where it had 512
  written in, the same value for the window's atlas; `cascades.Cascades` carries its tile size for the fit.
- An OpenGL view freed its targets but not the two arrays its lamps' faces are tracked in, made on its first frame
  with a lamp's shadow; the new cases found it under `leaks`.
- `gl.renderer_view_shadow_atlases` and `vulkan.renderer_view_shadow_atlases`: what a view holds, texels a side.
- `docs/rendering.md`'s Views section said a view keeps its own lamps' atlas, which was not so on Vulkan, and that
  its atlases are 4096 squares; it says the rule now.
- Tests: `test_backend_parity`, on both renderers: a view the window's size and one a quarter of it, under a lamp
  that is the key light and under the sun, with shadows on before the view is made and turned on after (the four
  cases of the issues), each held to the window's shadow and to the other renderer's; and the rule (no atlas with
  shadows off, drawn or not; made for every live view when they go on, at the window's, half and floor sizes; let go
  of when they go off; made again after). On the old code 25 checks fail: Vulkan's views under a lamp read 1 (no
  shadow) against the window's 0.049, OpenGL's views made with shadows off read 1 under the lamp and the sun, and
  Vulkan's views held a 4096 cascades' atlas with shadows off.
