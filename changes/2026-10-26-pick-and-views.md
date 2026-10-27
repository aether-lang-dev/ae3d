### What is at a pixel, and several cameras

- **Pixel picking with an ID buffer** (#865). `core.backend_pick` /
  `backend_pick_ask` + `backend_pick_read`, `engine_pick`, `engine_pick_ask` +
  `engine_pick_read`: the scene drawn again into a target of ids by quoted
  shaders (`ae3d.shaders.lit`'s `pick_vertex`, `pick_plain_vertex`,
  `pick_pixel`; `ae3d.shaders.throng`'s `crowd_pick_vertex`), with the MSL, on
  Vulkan and OpenGL. Right for skinned, instanced, alpha-tested and cut
  geometry, wounds, and crowds (instanced or sorted on the device); a device
  crowd's figure from the columns it holds, which are read and not changed. Only
  a frame that is asked draws the pass: every existing frame is unchanged.
  `Draw.pick` is a new field of the draw block (`pickId`), in padding: the
  blocks are the sizes they were. `ae3d.gpu` gains `instance_index()`.
- **The agent's `frame.pixel`** carries `pick`: the model (id, index, name,
  asset), instance, depth, world position, and a device crowd's figure; its
  colour and its pick are one frame's.
- **The editor selects by it** (a click on the viewport); the cursor's ray at
  bind-pose triangles stays as the fallback where a backend would not take the
  ask.
- **Several cameras and render-to-texture** (#866). A view is a camera drawn
  into a texture of its own: `backend_view_new/render/texture/pixels/free/
  set_exposure/blit`, the engine's `engine_view_*`, `material_set_texture_id`.
  Its own targets, temporal history, camera depth, clouds' history, shadow
  atlases, clusters and exposure; shown by a material or drawn into a rectangle
  of the frame (picture-in-picture, split screen). Vulkan draws it as a frame of
  its own in its own frame slot, with the frame's variables swapped
  (`scripts/gen_view_swap.py`, `tests/test_view_swap`); OpenGL swaps the
  renderer's camera fields. `ae3d.shaders.viewrect` (quoted, with the MSL) draws
  the rectangles.
- **Tests**, each with a control that fails the other way: `test_gpu_pick` (no
  GPU), `test_pick`, `test_pick_crowd`, `test_agent_pick`, `test_view`,
  `test_view_swap` (no GPU), `test_engine_view`, and the editor drive's click
  on the viewport; the pick and view suites run under the Khronos validation
  layer with the synchronization checks.
