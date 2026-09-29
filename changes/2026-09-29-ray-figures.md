### Skinned figures and the crowd's near band in the rays; the map goes (#492)

- A skinned figure -- anything drawn by its own skeleton -- is posed into
  the rays each frame: a compute pass (`skin_vk.comp`) skins its bind pose
  by the palette its draw is posed by into a buffer of its own, and its
  bottom-level structure is refitted from that (built afresh every sixteen
  frames, the figures taking turns), every figure in one build call, the
  nearest within the shadow distance up to a budget
  (`engine_set_ray_skinned`, `AE3D_RAY_SKINNED`, 32 by default; 0 leaves
  them to the map). In the street, posing the zombie and its clothes
  (30,364 triangles) costs the device 0.12 ms a frame and the CPU 0.02 ms;
  with the rays on it cast no shadow from the key lamp before, being in
  neither the rays nor a map. A figure whose palette has not changed since
  it was last posed is not skinned or refitted again. In street_drive the
  thirteen bystanders (26 skinned models) all go in and the map is not
  drawn: 2.28 ms of device time a frame against 2.29 ms with them in the
  map.
- The crowd's near band in the rays as the mesh it is drawn with
  (`crowd.device_crowd_rays_near`): the near mesh baked at every frame of
  the bank, and the sort points a near figure's instance at those, where
  the far tier's 168-triangle stand-in cast its shadow before. The pose
  structures are built to be compacted and compacted, and their posed
  vertices let go once built: the city's zombie takes 35 MB a figure with
  its far mesh (94 MB uncompacted with the vertices kept).
- Where the rays hold everything that casts, the key light's cascades are
  not drawn at all: the city draws no map (0 of 590 frames at 400 figures
  and at 20,000), and the frame's shadow stage is the crowd's sort, the
  structure's build and any lamp's own faces. `perf rays` in the
  `AE3D_PERF` report says how many frames drew the map and how many
  skinned figures the rays took.
- `tests/test_ray_shadows`, reading each shadow as what its caster's
  casting darkens: a skinned slab whose top a bone carries twenty metres
  sideways throws a shadow by ray within 8 pixels of its map shadow's
  footprint (measured 0 of 635), 295 pixels from the bind pose's; posed
  again it follows (0); with no skinned budget the map keeps it (0 apart);
  with the slab, the ball and the ground in the rays the map is not drawn.
  A crowd figure drawn near the camera by a quad twice its far mesh's
  width: 1,760 pixels off the map's 4,251 with the stand-in, 1 with the
  near structures.
- The city, alternating with the tree before, the median of three runs
  at 720p on an RTX 4070 Ti: 400 figures stay at the display's 144 fps,
  the device's time 6.60 to 6.43 ms; 20,000 with a 28 m near band go from
  18.4 to 19.05 fps, 54.2 to 52.4 ms. The 139 and 54 fps docs/rendering.md
  gave were measured on 18 September; the tree before this change draws
  the same city at 144 and 18.4 today (#498; at 20,000 the 28 m near band now
  holds some 4,500 whole figures).
- A crowd none of whose models casts writes nothing into the rays, as it
  draws nothing into the map. The sort's copy of its counts waits for its
  writes as a write, which sync validation found once the sort's layout
  grew a binding. And a crowd's descriptor sets go back to the pool when
  it is freed: a program that made and freed crowds as it went could make
  seven more after its first and no more (`test_device_crowd` now makes
  twenty, one after another).
