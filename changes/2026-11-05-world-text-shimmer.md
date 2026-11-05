### World text: a far, small label no longer shimmers as the camera moves (#892)

- `ae3d.shaders.lettering.world_text`: where a pixel spans more than one of the glyph atlas's texels (`dFdx` and
  `dFdy` of the atlas place, times the atlas's size), the pixel is covered by the mean of a grid of reads of the field
  over its footprint on the atlas, `ceil` of the texels a pixel up to 4 by 4, each read's coverage a pixel's share of
  the width wide, faded in from one texel a pixel to two. A field read at one point a pixel found a stroke one frame
  and the gap beside it the next. No mips: as #892 has it (Nic, 876-3), mips would make the two APIs' frames differ by
  the driver's mip filter, so the fix is the shader's and the same on both. The grid is symmetric about the pixel's
  centre, so OpenGL's y running up turns it into itself. Neither renderer's atlas changed (#894 is not touched).
- `tests/test_world_text`: the camera slides a fifth of a world unit a frame for 24 frames past a grey label 5 to the
  em and one 9, over the clear; each frame's coverage (each pixel's light taken back through the display's curve,
  moved from what is under the label toward the label's own, summed) is held within 2% of its mean and of the frame
  before, on both renderers, and the two renderers' frames to under 1% of channels. Main: the far label 4.2% from its
  mean and 6.7% from one frame to the next, the nearer 1.9% and 3.6% (4 of the checks fail); now 1.3% and 1.5%,
  0.74% and 0.76%, at 4x and at one sample, the renderers' moving frames 0 channels apart. The suite's other
  Vulkan-against-OpenGL comparisons are what main draws (108 and 51 channels where main had 108 and 51).
- Cost (`bench_world_text`, 1280x720, M6): 500 labels over everything add 207 us to OpenGL's GPU scene pass (main
  184) and 108 us to Vulkan's (main 182); the runs are within the benchmark's noise.
