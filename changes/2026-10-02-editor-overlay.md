### The HUD in the editor's viewport (#460)

- `engine_over`, the editor's engine over its own renderer, has an overlay.
  It is cleared at the start of each `engine_update` and drawn in the
  owner's frames once `engine_show_overlay` hands it to the renderer. The
  editor shows its viewport engine's overlay, so a behaviour's `hud.text`
  and `hud.rect` calls appear in the editor as they do in the game. The play
  mode's client engines keep theirs off the viewport.
- `tests/test_overlay` drives an engine over each renderer the way the
  editor does: the overlay is drawn, the next frame is bare, and a second,
  unshown engine neither reaches the frame nor detaches the first engine's
  overlay when it is freed.
