### Rendering: a crowd's figures each at the detail their distance needs (#536)

- **A crowd's near tier is drawn by a cluster cut, figure by figure, in one
  draw.** The cut runs over the figures the device sort kept, reading their
  count where the sort wrote it, and writes each index as the figure's slot
  above the mesh's vertex; `crowd_pull_vk.vert` reads the vertex, its skin
  and the figure from storage. In zombie_city (400 figures of 30,364
  triangles up close) the horde and the trim draw 380,703 triangles a
  frame, and the scene and shadow passes fall from 109.17 to 53.56 ms on an
  M1 Pro at 2560x1440, 8.8 to 17.1 fps.
  - `tests/test_cluster_cut.ae`: sixty skinned figures of 65,536 triangles
    from 8 to 448 m draw 28,380 of their 11.8 million indices; the frame
    differs from the uncut one along the silhouettes and in 3 of 13,431
    pixels inside, and covers the same area within 2%.
