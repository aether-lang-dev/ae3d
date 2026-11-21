### Depth of field: the gather's spiral turned at every texel, 48 taps (#881)

- `ae3d.shaders.dof.dof_gather` turns its golden-angle spiral by an interleaved-gradient noise of the texel (the
  occlusion's `dither`, the texel counted from the same corner on both renderers) and takes 48 taps where it took 32.
  A fixed spiral read the same places at every texel, so the blur of a wide disc showed the spiral's structure; turned,
  the same taps are grain. The radii are where they were (the innermost a half texel's falloff out), so a texel in
  focus still takes nothing; the alpha's share of the widest near disc is of 48 taps.
- `tests/test_gpu_dof`: an edge under a disc wider than the gather reaches, on the CPU. Its rows must differ, and
  their mean across the edge must be an even disc's blur of it (worked out by a dense disc) within 0.015: turned,
  0.0077. Negative controls: main's gather (32 taps, unturned) is 0.029 out and fails both checks, 48 taps unturned
  0.026 and fails both.
- Measured on the M6 (Vulkan on MoltenVK and OpenGL), against main: `frames_against` 81 frames, the four depth of
  field frames differ (the change) and every other is byte-identical (the clouds and the city within #793, #794).
  `test_backend_parity`'s depth of field, OpenGL against Vulkan: at one sample 0 of 147,456 channels differ on both
  focuses, as on main; at 4x 2,115 and 1,969 (main 1,991 and 1,989). Cost at the widest disc (100, aperture 100),
  zombie_city at 1280x720, the post chain's GPU time with depth of field against without: Vulkan 0.27 ms (main
  0.12), OpenGL 0.35 ms (main 0.18); no budget pins depth of field, which is off by default.
