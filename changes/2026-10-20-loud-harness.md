### A stale quoted shader ends the program; a failing suite exits non-zero

- **A quoted shader whose tree no longer hashes to what ae3d.vkspirv's
  SPIR-V was made from ends the program that draws it**, exit 1, naming
  the shader, both hashes and how to regenerate (rebuild
  `tools/generate_shaders` first: the trees are compiled into it). It was
  one line on stderr and the pass left out of the frame, so a quoted shader
  edited with the generator not rebuilt drew the frame without it, and a
  negative control on the shader -- or a real bug in it -- could pass
  unseen. Every way in holds to it (`vkquote.fresh`): `pass_new`,
  `pair_new` (and so `mesh_pair_new`), `vertex_ring_new` and `set_shader`.
  There is no fallback, opt-in or otherwise: the trees and the words are
  compiled into the same program, so no build that differs is a released
  one. OpenGL has no such path: it writes its GLSL from the tree it runs.
  - `tests/test_quoted_stale` runs itself as a child handing each of the
    four a hash its shader was not made from, and holds the child to a
    non-zero exit and the message. On main it fails 20 of 25: every child
    exits 0 after the one line.
  - The case it is for, measured: throng's crowd vertex edited and the
    generator not rerun, `test_crowd_render` exited 0 on main (printing
    "2 failure(s)"); it now exits 1 with the shader's name and hashes.
- **Every suite that printed FAIL or a failure count now exits non-zero
  with it.** 132 of the 206 under `tests/` never did: their last lines
  printed `N failure(s)` and returned, and so did early returns after a
  failed check (a backend that would not start, a load that came back
  null). ci.sh judged them by "all checks passed", so CI was not fooled,
  but a lane script, a helper or a person reading `$?` was: lessons from
  the quoted-shader work (test_heat_haze, test_impostor, test_cluster_cut)
  found them. Each now ends with `exit(1)` where it reports a failure, the
  pattern the other 73 already had; "all checks passed" is unchanged.
