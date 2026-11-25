### Clustered copies culled in each shadow tile; clusters of 8 (#19, Hushlight)

- A sun cascade draws only the clusters of a still instance stream over its
  box, and a lamp's face only those it casts onto
  (`core.instance_runs_by`, both renderers). Before, every copy on the map
  was drawn into every cascade. These are the same tests that already culled
  whole casters, applied cluster by cluster. Turning off `frustum_culling`
  draws everything, as for the camera.
- Clusters hold about 8 copies, not 32. A 50-tile view of a 600-tile map
  drew 1.35M triangles where it drew 2.32M, in the same five runs. A stream
  is clustered from 32 copies.
- `bench_instance_cull` now draws the sun's cascades out to 110 m. Drawn
  whole: scene pass 29.6–30.7 ms, shadow pass 19.1–19.4 ms. Culled: 7.4–7.8
  ms and 1.9–2.6 ms.
- `test_instance_cull` turns shadows on over a ground plane. It checks that
  the shadows fall (twice the dark channels of the same frame without
  them) and that the culled picture, shadows included, is the whole
  draw's, on both renderers. With the cascades' runs cut, 4,108 channels
  differ.
- `docs/rendering.md` updated.
