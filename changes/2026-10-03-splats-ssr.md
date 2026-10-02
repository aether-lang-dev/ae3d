### Splats on the skin (#546), the wet road on OpenGL (#491)

- `core.model_set_splat(m, index, centre, radii, rotation, opacity)`: blood
  on a model's skin in an ellipsoid of its bind space, carried by the skin as
  it moves, its edge ragged, fading with `opacity`. Splats and wounds share
  32 slots now (it was 16 wounds); the Vulkan block is 11,152 bytes.
- Screen-space reflections run on OpenGL, from the same shader as on
  Vulkan, reading OpenGL's scene depth (the stored depth goes to clip z
  through a helper the generator rewrites for Vulkan, as the occlusion's
  does). `engine_set_ssr` reaches both renderers.
- Measured: street_drive's road band 0.34 of 255 apart across the renderers
  with reflections on (#491 measured 10 to 15 with OpenGL dry); the pass costs
  0.12 ms on OpenGL and 0.11 on Vulkan at 1280 by 720. test_backend_parity
  has a wet-ground case, and tools/scene_parity compares the scenes with
  their reflections on.
