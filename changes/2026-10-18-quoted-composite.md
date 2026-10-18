### The composite written with quote

Step 6's composite (docs/aether_quote_design.md section 11), on both
renderers. The frames are main's.

- **`ae3d.shaders.composite`** is the frame's tone curve in Aether. It
  ripples the light where hot air rises over a fire, adds the bloom, scales
  by the eye's exposure, applies ACES and then the sRGB encoding, and adds
  half a step of grain. A capture is passed through as data.
- **The heat haze's columns are eight `vec4` captures.** The hand-written
  shader read them as two `vec4[4]` arrays. The haze's loop picks its
  column with `haze_column(k, c0, c1, c2, c3)` and keeps the hand-written
  loop's shape: its break, its continues and `float(k)`.
  - A captured struct of arrays, as the design had it, hit two gaps.
    Quote 0.824.0 names a struct's `vec4[4]` field `UNKNOWN[4]`, and a back
    end cannot read a struct's cell without the layout, which a tree does
    not carry.
  - `haze_screen`'s `out float w` is a `HazePoint` it returns.
- **Vulkan:** a quoted pass in the post pass. Its values are copied word
  for word from the scene program's block, as the hand-written shader read
  them (`vkframe.composite_values`, with the new `gpu.set_vec4_f32`), and it
  samples the light and the bloom. `AE3D_VK_SHOW_DEPTH` draws the depth
  through it as a capture, `capture_channel` 9.
- **OpenGL:** compiles the same tree's GLSL at start and sets its uniforms
  by name.
- **Generator:** writes `composite_quoted`. `test_quoted_hashes` holds its
  tree.
- **Tests:** `tests/test_gpu_composite.ae` has 24 checks. It holds the
  golden GLSL in both dialects, with glslang and spirv-val, and the block's
  layout. On the CPU, it holds the composite to the same shader written as
  plain Aether, for the light alone, with the bloom, under two columns and
  under four, and for a capture.
  - The grain and the haze's noise are hashes of a place:
    `fract(sin(...) * 43758.5453)`. f32 and doubles hash those apart, so the
    check is looser for them. A pixel is held to the reference but for the
    grain, which must be the same amount in every lane and within a step.
    A pixel under the hot air is held only to have rippled.
  - Scaling the exposure by 1.01 in the quote fails 6 of the checks. On the
    GPU it makes all 56 of test_backend_parity's frames differ, on both
    renderers.
- **The hand-written composite is gone,** with `VERTEX_SCREEN` /
  `screen_vk.vert`. The composite was the last pass that drew with them.
  - `vkpipes`' post pipelines go, and so do `vkframe`'s hand-written
    screen draw (`draw_screen`, `draw_screen_with`) and the sets it kept.
  - Six scene-block uniforms only the composite read go too:
    `frameExposure`, `enableBloom`, `bloomIntensity`, `hazeCount`,
    `hazeColumn` and `hazeShape`. The block now has 177 uniforms and 15808
    bytes, in 53 shaders.
  - The renderer writes the same 32-bit words into the composite's own
    words instead (`vkframe.set_composite_haze`, `setup_post_uniforms`), and
    the quoted composite copies from there.
