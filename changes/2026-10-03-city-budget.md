### zombie_city at 20,000 held to a budget (#498)

- The local gate measures zombie_city with 20,000 figures, on Vulkan at a
  fixed tick held at frame 90, through `tools/ae3d_bench`: its draw calls,
  triangles and binds against the recorded figures exactly, and its passes'
  times on the card that recorded them. Twice: the default near band
  (`resources/zombie_city.vulkan.budget.json`: 285 draws, 316,996
  triangles, the scene pass 17.1 ms on an RTX 4070 Ti) and the 28 m one
  (`resources/zombie_city_near28.vulkan.budget.json`: the scene pass 28.7
  ms, the shadow pass 0.46). zombie_street's was the only scene held to
  numbers. Skipped on runners: 20,000 figures on a software rasteriser.
- `ae3d_bench --hold <frame>` waits for a scene held at that frame
  (AE3D_TICK, AE3D_HOLD) and measures that moment instead of pausing and
  parking the clip: a walking horde is only where it was recorded at the
  frame it was recorded at.
- The bench's allowance for timer noise is 0.2 ms, not 0.05: the post pass
  of the same held frame reads 0.09 ms on one run and 0.25 on the next,
  steady within each, with the eye's meter on or off.
