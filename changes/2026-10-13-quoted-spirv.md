### The quoted shaders' SPIR-V, made from their trees and held to their hashes

- `tools/generate_shaders.ae` writes the shaders written with `quote` too:
  for each (FXAA, `fxaa_quoted`), ae3d.gpu's GLSL from the tree and the
  full-screen vertex shader beside it into `src/ae3d/vkspirv/glsl`, their
  SPIR-V into ae3d.vkspirv as the other shaders' (`FXAA_QUOTED_FRAG`,
  `FXAA_QUOTED_VERT`), and the tree's hash (`quote.hash`) beside the words
  (`FXAA_QUOTED_HASH`), which a renderer holds its tree to before drawing.
- The `Params` block's offsets are asked of glslang, as the scene block's
  are: every member reported, each where ae3d.gpu put it (texel 0,
  edge_min 8, edge 12, subpixel 16).
- `--check` (ci.sh's "Vulkan shaders regenerated") fails when a quoted
  shader's GLSL is not what its tree writes, and when its tree no longer
  hashes to the one its SPIR-V was made from: a changed constant in FXAA
  fails both, and a hash edited in ae3d.vkspirv fails the second.
