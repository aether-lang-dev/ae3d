### An instanced model's copies culled by cluster (#19, Hushlight)

- An instanced model was never culled: its copies were left to the GPU to
  clip, and a prop kind laid over a whole map drew every copy every frame.
- A still, opaque instance stream (not a crowd, points, or one that
  blends) of at least 128 copies is cut into clusters of about 32 nearby
  copies, a grid in Morton order with a bounding sphere each
  (`geometry.inst_cluster`, `core.instances_cluster`). It is sent once in
  that order: vkmesh packs through the order, and GL uploads gathered
  copies.
- The camera's opaque pass and prepass draw only the runs of clusters the
  frustum reaches (`core.instance_runs`), joined across the smallest gaps
  past 16. Vulkan draws from a first instance; GL 4.1 re-points the copy
  attributes for each run.
- A stream that changes is drawn whole in its own order until it is still
  again. Clustering it again is O(copies): 46 µs for 2,401.
- Copies keep their indices. A pick's place in cluster order is turned
  back into the copy (`core.pick_copy_of_place`, both renderers).
- `bench_instance_cull`, new, at a tile builder's scale (600 tiles of 16 m,
  five kinds): 13.92M triangles and 28.5–29.7 ms of scene pass drawn whole,
  against 2.32M and 12.1–12.3 ms culled.
- `test_instance_cull`, new, 20 checks: the partition, the spheres, no
  visible copy missed on a corner view and a wide one, the same picture
  with and without the culling on both renderers, and picks naming the
  copy.
- `docs/rendering.md`, "An instanced model's copies, culled by cluster".
