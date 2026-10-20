### The quoted sky's material bind is counted again

- **Vulkan counts the sky's material bind** (`vkframe.draw_sky`). The
  hand-written sky was drawn through `draw_pipeline`, which counts a
  material bind when the texture behind the scene set changes; the quoted
  sky (#799) binds its own set and was not counted, so zombie_street's
  frame read 52 material binds on Vulkan against the 53 its budget holds
  (`./ci.sh`, "the demo scene, held to what it cost last time"). Bisected
  over the first-parent history: dafd5ffd 53, 6478e3a8 (#799) 52. Now 53;
  nothing drawn changes.
