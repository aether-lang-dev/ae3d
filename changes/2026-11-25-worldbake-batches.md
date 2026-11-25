### A world baked in batches, and a city streamed from it (#917)

- `ae3d.worldbake` bakes in batches: `begin`, `add` for each part of the
  world, `finish`. A caller holds one part's models at a time, not the
  world's. `bake` is the three in one. A cell takes its models from one
  batch: a later batch with a model in a cell already written is refused,
  since the file would lose the first batch's models.
- A model off the grid was left out of the bake with nothing said. A
  batch with one is now refused whole, naming the model and where it
  stands, before anything is written.
- `add` buckets the models by cell in one pass (a count, a running start,
  a place each), where it walked every model for every cell.
- A texture's mean colour, which a stand-in is painted with, is read once
  a bake instead of once a model. 96 cells baked in 65 s before this and
  2.6 s after.
- `ae3d.stream` counted a cell's decoded textures for as long as the cell
  stayed. Once the cell is resident they are the renderer's, so
  `resident_bytes` now lets them go then (`CellData.image_bytes`).
- `examples/open_world`, new: the street's block laid out as a city, its
  pavements dressed by `ae3d.scatter`, built and baked a row at a time and
  streamed around a car driving the middle street. `AE3D_CITY` sets the
  size: 8x6 blocks by default (96 cells, 9 s, 2.6 s of it the bake), or
  16x12, the README's (1,344 by 528 m, 36,879 models, 372 cells). The
  16x12 city builds and bakes in 33.7 s at 274 MB peak RSS (M1 Pro), where
  the whole city built in one batch was killed for memory. Its stream holds
  about 60 cells and 220 MB at peak. The kit's road texture
  averages 0.2% albedo, so by day the road is lifted to dark asphalt.
- `test_stream`: a world baked in two batches loads as one, and a second
  batch into a cell already written is refused, as is a batch with a model
  off the grid. 23 checks.
- README "Worlds" section and picture; `docs/streaming.md` covers baking
  in batches and the city.
