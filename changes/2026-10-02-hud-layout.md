### The HUD laid out: anchors, scale, wrapped text, clipped panels, images (#459)

- `hud.place` puts a box at any of nine anchors, sized and offset in
  points. The engine tells the overlay the screen size and UI scale each
  frame: the window's content scale, or `engine_set_ui_scale` /
  `AE3D_UI_SCALE`.
- `hud.text_box` wraps text to a width and sets each line left, centred or
  right.
- `hud.push_clip` / `pop_clip` bound what is drawn to a panel. Quads are cut
  on the CPU, glyph and image areas with them, so the overlay is still one
  draw on both renderers.
- `hud.image_load` / `hud.image` draw pictures from an RGBA image page, the
  overlay's second texture. On Vulkan the overlay's two textures share one
  upload path.
- `core.env_float` and `platform.window_content_scale`.
- `tests/test_hud_layout.ae`: all of it on both renderers, at two sizes and
  two scales, to the pixel; Vulkan matches OpenGL with 0 channels apart.
