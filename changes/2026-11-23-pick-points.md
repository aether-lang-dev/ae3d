### Picking on a display that scales, and OpenGL's frame after a view

- **`engine_pick`, `engine_pick_ask` and `engine_pick_read` take a window
  point.** That is the cursor's space, so `engine_mouse_x`/`engine_mouse_y`
  go in as they are. The engine takes the point to the frame's pixel. On a
  Retina Mac a point had been read as a pixel, so every pick read a spot
  halfway to the frame's top left corner and missed (Vulkan's
  `test_engine_view` failed on main). A game that scaled the cursor by the
  content scale and the render scale itself should now pass the cursor as
  it is: the backend applies the render scale.
- **OpenGL drew the frame after a view at the view's size.** A view's
  render left the GL viewport at its own size, and the next frame takes
  its size from it (`begin_post_processing`). A program showing a 48x36
  view drew its window's frame at 48x36, stretched. Its picks read that
  picture. The view now puts the frame's viewport back.
- **OpenGL maps a pick from the frame's size**, as Vulkan does, not from
  the size the renderer started at.
- `test_agent_pick` asked about pixels computed at the window's size where
  `frame.pixel` addresses the captured frame. 6 of its 11 checks failed on
  a Retina Mac, on main as well. It computes them at the frame's size now.
- `test_engine_view` and `test_agent_pick` pass on both renderers
  (macOS, Retina). `docs/rendering.md`, "What is at a pixel".
- The editor drive's divider check held a 120-point drag to a 120 drop in
  the viewport's size. That size is in pixels over a GPU view, so on a
  Retina Mac the drop was 240 and the check failed, on main as well. It now
  scales by the viewport's pixels per point (`viewport_scale`).
