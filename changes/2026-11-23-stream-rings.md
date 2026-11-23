### Instance streams that grow, and freed meshes, no longer wait for the whole device

- **A ring grows by doubling.** An instance stream's per-frame ring was
  remade at exactly the size asked, behind `vkDeviceWaitIdle`, every time
  the stream reached a new most. An emitter one particle fuller each frame
  did that every frame; a game of about 200 small emitters (Hushlight's
  ground mist) spent about 40% of its frame there. A stream creeping from 1
  to 256 instances now remakes its ring 9 times, where it remade it 255.
- **Retired, not waited for.** What a ring outgrew, the first upload's
  device-local buffer, and a freed mesh's or stream's buffers are retired
  (`ae3d.vkmesh`). Each is destroyed once every frame that could have drawn
  it has passed its fence (`vkmesh.frame_begun`, called by the frame's
  start). A mesh with a ray-tracing structure still waits as it is freed:
  its structure goes with it.
- `benchmarks/bench_streams.ae` (200 streams, each one instance fuller a
  frame, M1 Pro, Vulkan): 20.3–20.6 → 3.10–3.13 ms a frame. Streams that
  move without growing are unchanged (4.84–5.06 → 4.82–4.86).
- `test_vk_rings`, new: the ring made at most 9 times from 1 to 256, every
  frame's newest instance drawn, and nothing retired left frames after the
  growth stops or a stream is let go of. 0 leaks.
- `docs/performance.md`: "Streams that grow, and buffers let go of".
