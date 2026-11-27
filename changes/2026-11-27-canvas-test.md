### Added

- `tests/test_canvas`: a program's canvas held to its docs on OpenGL and
  Vulkan, pixel by pixel. A picture of the program's (`engine_texture_new`)
  is read nearest, repeating, its bytes through no colour curve, top row
  first: all 16,384 pixels of a card showing a 4 x 4 picture twice each
  way are their texel exactly. Draws with `over` are laid on what is there
  by their alpha, one without is written as it is, each depth-tested and
  writing depth, in the order queued: seven bands, each within 2/255 of
  its colour worked out by hand. Linear filtering, clamping, an sRGB
  picture, `over` turned off or an `over` draw writing no depth each
  fail it. Its pairs are `tests/lib/canvascard`, their SPIR-V made by
  `tools/canvas_test_spirv.ae`.
