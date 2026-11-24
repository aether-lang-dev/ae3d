### A hidden window draws at the size asked

- On a display that scales (a Retina Mac), a hidden run drew at the
  display's pixels. `engine_set_size(e, 1280, 720)` with `AE3D_HIDDEN=1`
  wrote a 2560x1440 snapshot, four times the pixels a scripted shot or a
  CI frame meant to pay for, and `AE3D_WIDTH`/`AE3D_HEIGHT` changed
  nothing. Hushlight measured camera depth at 70 ms where the same frame at
  the asked size took 15.8.
- A window that is not shown, or any with `AE3D_PIXEL_SCALE=1`, is now
  drawn at its points:
  - GLFW's framebuffer-scale hint, by the name the running GLFW knows
    (`GLFW_SCALE_FRAMEBUFFER` from 3.4, `GLFW_COCOA_RETINA_FRAMEBUFFER`
    before);
  - on Vulkan, the Metal layer's contents scale, and the window's frame
    size as the platform reports it (`platform.window_scaled`). GLFW
    reports a context-less window at the display's scale whatever the hint
    says.
- `test_hidden_size`, new: a hidden window asked for 320x240 draws 320x240
  on OpenGL and Vulkan.
- `docs/building.md`: `AE3D_HIDDEN` and `AE3D_PIXEL_SCALE`.
