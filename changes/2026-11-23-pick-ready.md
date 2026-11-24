### Picks read without stopping the program

- `engine_pick_ready(e, k)` (and `core.backend_pick_ready`): whether a pick's
  answer can be read without waiting for the device. Read in the frame that
  asked, a pick waited for that frame's whole work on the device: a
  visible hitch each time a hover picked, in a frame of 30 ms of GPU work.
  A game asks, then reads on the first frame the answer is ready:
  - Vulkan, two frames later, once a later frame's start has waited for
    the answering one (`vkframe.frame_serial`);
  - OpenGL, the next.
- A read once the answer is ready does not wait for the frame slot. By
  then the slot may be a newer frame's, still on the device.
- The pick pass draws only the box round the pixels asked, a pixel spare
  each side, on both renderers. Measured, the ID pass itself was cheap;
  the wait was the cost.
- Measured (Vulkan, M1 Pro, a light scene): 1.70-1.77 ms a frame with no
  pick, 2.8-3.0 ms reading at once, 1.73-1.77 ms reading when ready.
- `test_engine_view`: a pick asked is not ready before its frame is drawn,
  and read once ready it names the red sphere (Vulkan after 2 frames,
  OpenGL after 1).
- `perf transparent_cover` leaves out a model off the view and an emitter
  with no live particle. Both counted as their bounds, and a mist of
  eighty emitters read 36 screens with its stage at 0.3 ms
  (`test_transparent_cover`, 6 checks).
