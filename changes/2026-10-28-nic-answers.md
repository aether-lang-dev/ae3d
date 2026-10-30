### Small items from Nic's answers on #872-#875

- **The upscaler turned off frees its two RGBA16F targets at once**, on both
  backends (they stayed until the frame was remade); `renderer_upscale_targets`
  reports how many are alive.
- **The draw count has one rule**: a full-screen pass of the frame's own is not
  counted. OpenGL no longer counts the upscaler's passes or the depth of
  field's two (Vulkan reads its count before the post chain, so it never did).
- **An environment map that is not twice as wide as it is tall is refused**
  (`.hdr` and `.exr`), the error naming its size; it was read and lit the scene
  wrongly.
- `test_vk_msl` draws `pick_quoted.frag` and `view_blit_quoted.frag` as MSL and
  holds them to their SPIR-V frames (`vkpipes.msl_made_for`).
- The critique holds the whole reflection under the zombie_street figure's feet
  (0.21 as drawn, 0.54 at four times the strength) as well as the figure's part
  of it, which barely moved.
- Comments: crowds are picked; the pick's exclusions are particles, surfaces
  added over the frame, water and world text. DoF values are pixels of a
  1080-line frame.
