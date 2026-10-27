### A spatial upscaler and depth of field (#867, #870)

- `engine_set_upscaler(e, UPSCALER_SPATIAL, sharpness)` (`AE3D_UPSCALER=1`,
  `AE3D_UPSCALE_SHARPNESS=50`) makes a scene drawn below the window's size
  (`engine_set_render_scale`) the window's by two quoted passes, an edge-adaptive
  upscale and a sharpen (`ae3d.shaders.upscale`), on Vulkan and OpenGL and with
  the MSL: the vendor-neutral upscaler MoltenVK, an Intel iGPU and a Pi 5 lacked.
  Bilinear stays the default and the fallback. At half scale on a sphere and a
  cube it lands at 67 against bilinear's 124 (mean distance from the full-size
  frame, hundredths of a step), identical on both renderers at one sample.
- `engine_set_depth_of_field(e, on, focus, aperture, max_radius)`
  (`AE3D_DOF=1`, `AE3D_DOF_FOCUS/APERTURE/MAX`): a circle-of-confusion pass over
  the scene's depth and a gather blur at half size, mixed in by the composite
  beside the bloom (`ae3d.shaders.dof`, quoted). Off by default and then every
  existing frame is byte for byte what it was. The two backends agree to the byte
  at one sample.
- The composite takes a third texture and a flag (`dof`, `dof_on`); its block
  gains an int and the generated files are regenerated.
