### The editor drive finds the colour picker by the canvas id /widgets gives

- **`tools/drive_editor.ae` takes the picker's canvas id from /widgets**
  (its "canvas" field) rather than counting the canvases before it. On
  macOS's OpenGL path the editor's GPU view is listed as a canvas with no
  canvas id, so the picker came out canvas 3 of the 2 there were: every
  `/canvas/3` route answered an error and five checks failed with it
  ("the picker's square is painted at its hue", the strip and square
  picks, the hex, the drag's one Undo) in every local `./ci.sh`; runners
  drive Vulkan alone. Now the OpenGL and Vulkan drives pass every check.
- The divider drag ("dragging the divider narrows the viewport by what
  the inspector took") failed on both: the fix is aether-ui's (AppKit:
  fill_width after a fixed width makes the width a floor), where the
  picker's canvas_size 240 then fill_width held the inspector at 240 plus
  its insets against the splitter.
