### Vulkan: an opaque depth prepass, so each pixel is lit once

- **Why.** The lit pixel shader can discard (cutouts, cuts, wounds). On a
  tiled GPU a pipeline that can discard and writes depth loses
  hidden-surface removal and early depth testing. Every opaque surface
  drawn over another was lit in full at every pixel it covered.
  Hushlight's isometric town spent 25-30 ms of a frame there, at about 16
  ns a pixel, against about 1.8 for one plain layer.
- **What.** The opaque surfaces' depth first, through the casters' depth
  shaders. The camera's view-projection goes into every program's
  light-space slot for this, and each program's own matrix goes back
  after. Then their lit draws test against that depth and write none
  (`vkpipes.prepass`, `scene_after`).
  - Left to draw as before: surfaces with a cutout, impostors, crowds,
    cluster cuts and points.
  - The prepass's depth is one step farther than the surface's. A slope
    term at silhouettes let the surface behind win the edge samples.
- **Measured** (M1 Pro, Vulkan):
  - 120 opaque layers at 640x360, 4x MSAA: 20.3 -> 2.48 ms
    (`test_vk_stages`);
  - 60 layers at 480x270: 2.7-4.2 -> 0.28-0.83 ms (`test_vk_prepass`).
- **The same picture.** `test_vk_prepass`, new, renders overlapping cubes,
  a batch, an instanced model, a cut cube, a cutout and glass with and
  without the prepass: 0 channels differ by more than 2 of 73,504 lit.
- `AE3D_PREPASS=0` or `vulkan.renderer_set_prepass(r, false)` turns it off.
- `docs/rendering.md`, "The opaque depth prepass".
