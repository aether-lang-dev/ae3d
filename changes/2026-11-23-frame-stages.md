### The Vulkan frame's stages charged with their own work

- **`camdepth` was the opaque draws, and `occlusion` the transparent
  ones.** The stamp that closes each stage was written beside the next one,
  so `AE3D_PERF`, the editor's stats bar and the agent's `frame.stats`
  reported a game's glTF props as "camdepth 31 ms" and its particles as
  "occlusion 34 ms". The scene pass now writes camera depth's two stamps
  together, since there is no such pass any more, and the depth resolve
  writes its own closing stamp (`vkframe.mark_occlusion_done`).
- **On a device layered over Metal**, a stamp written between two draws
  came back as the frame's end, so the opaque stage was charged with
  everything drawn after it. Such a device (`vkdevice.portable()`) now has
  its marks inside the scene pass written at the pass's next edge, where
  they are true.
- `test_vk_stages`, new: an opaque-heavy scene is the opaque stage's with
  camera depth at nothing; a transparent-heavy one is the transparent
  stage's. On an M1 Pro: 18.4 ms opaque against 0.12 camdepth, and 210 ms
  transparent against 0.07 occlusion.
- `docs/performance.md`, "Measuring": what each stage holds, and what a
  Metal-layered device can tell apart.
