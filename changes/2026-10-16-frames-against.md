### Frames held to another commit's, with a tolerance where a scene is not the same twice

- **`scripts/frames_against.sh [ref]`** builds `test_backend_parity` and
  `zombie_city` here and in a worktree of `ref` (default `origin/main`),
  draws the same frames in both and compares them with the new
  **`tools/frame_diff`** (channels that differ, and by how much at the
  most): every case `test_backend_parity` dumps, both renderers, and
  zombie_city held at frame 90 at one sample on Vulkan and OpenGL and at the
  default on Vulkan. This is how a shader moved to `quote` is held to the
  frames it drew before.
- Byte for byte, except the two scenes that are not the same twice on one
  commit: **the clouds over the skybox (#793)**, held to 40 steps on at most
  4,000 channels (main against itself: 2,016 to 2,066, worst 25 to 33), and
  **zombie_city (#794)**, multimodal at one sample, drawn five times on each
  side with the closest pair held to 4 steps on at most 400 channels (main
  against itself, near mode: 58 to 104, worst 4).
- Run against its own commit on the M6: 59 frames, none differ.
