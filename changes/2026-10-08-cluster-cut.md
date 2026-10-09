### Rendering: big meshes drawn at the detail their distance needs (#536)

- **A cluster graph of every big mesh, cut on the device each frame.**
  `ae3d.clusterlod` builds a Nanite-style graph of a mesh of 8,192
  triangles or more (clusters of 128 triangles, groups of 16 simplified to
  half with their shared vertices held, down to one cluster), and
  `ae3d.vkclusterlod` picks the clusters whose error is under a pixel each
  frame, for each instance on its own, by three compute passes; the scene's
  own pipelines draw them through one multi-draw indirect call a material.
  In zombie_city the stone trim of the 15 nearest blocks draws 36,194 of
  its 217,860 triangles, and the scene and shadow passes fall from 109.18
  to 108.64 ms (M1 Pro, 2560x1440). `AE3D_CLUSTERS=auto|on|off`; `auto` on
  any device with `multiDrawIndirect` and `drawIndirectFirstInstance`.
  Skinned and crowd meshes, the shadow pass and OpenGL draw meshes whole.
  - `tests/test_clusterlod.ae`: on a sphere, a plane, two materials, the
    zombie's body and a street block's trim, every cut at every threshold
    closes the surface and covers it once.
  - `tests/test_cluster_cut.ae`: 25 spheres of 65,536 triangles draw 18,906
    of their 4.9 million indices, the frame with the cut differs from the
    frame without it only along the silhouettes (46 of 9,836 pixels), and
    the cut follows the camera's distance and view.
- **`loader.sphere` closes at its seam and its south pole.** `sin(pi)` and
  `sin(2 pi)` are not 0 in floating point, so the seam's two columns and the
  south pole's vertices never met: a hairline open edge from pole to pole.
