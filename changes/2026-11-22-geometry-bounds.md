### Mesh and instance stores: bounded growth, sizes in longs, a removal that moves every stream

- **Bounded growth** (#899): a mesh grows to at most `MAX_MESH_VERTICES` (2^27)
  vertices and `MAX_MESH_INDICES` (2^30) indices, an instance store to
  `MAX_INSTANCES` (2^27). Doubling stops at the bound instead of passing it;
  `mesh_reserve`, `mesh_append_raw`, `inst_resize`, `inst_enable_colors`,
  `inst_enable_phases` and `skinrows_create` refuse a request past it and
  change nothing. The bound is where the widest stream's last float index
  still fits an int: 2^27 vertices are 1.6 billion skin floats, where the
  2^28 first proposed would have been 3.2 billion and wrapped.
- **Byte sizes and offsets in longs.** Every realloc, memset, memcpy and
  memmove of the stores was sized `(n * width) as long`, an int product that
  wraps before the cast: a vertex store's bytes past 59 million vertices, an
  instance store's matrix offsets past 33 million instances.
- **`mesh_append_raw`** refuses negative counts (a negative memcpy) and sums
  past the bound; **`mesh_clone`** returns null instead of copying into a
  failed allocation, freeing what it made.
- **`inst_remove` moves the phases and the points** with the matrices and
  colours: a crowd or a point cloud that lost an instance drew every one after
  it with its neighbour's phase, or, as points, at its neighbour's place.
- `test_geometry` (39 checks, from 25): past-bound requests refused with the
  store unchanged, a skinned mesh with a second UV set grown from one vertex to
  a million read back as unwritten vertices, and a removal on phases and
  points. The suite run against the old store dies with a bus error.
