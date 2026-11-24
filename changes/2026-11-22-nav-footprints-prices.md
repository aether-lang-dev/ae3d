### Flow fields: footprints from triangles, dear cells, a clearance, one pass

- **`nav.flow_block_mesh(f, model, low, high, grow)`** (#817): the cells under
  a model's own triangles (each instance's when instanced), cut to a band of
  heights and grown by a disc of `grow` cells. A 40 m fence blocks its 40
  cells where its bounding square closed over 1,600; a shack keeps its doorway;
  a block on a cell's lines blocks that one cell, by an instance's float32
  matrix too; a lone panel on a cell line blocks one row and leaks nothing.
  0.35 to 0.40 ms for a 600-instance fence of 7,200 triangles.
- **Dear cells** (#819): `flow_cost_rect` sets an area's price, `flow_clearance(f,
  cells, extra)` prices the margin round every wall, nearer dearer, so a field
  keeps bodies off walls without closing doorways and gives a way out to anyone
  standing in the margin. Kept up as walls change: a 20 m wall up or down
  re-prices its neighbourhood in 1.05 us, against 5.7 ms for the whole
  million-cell field. `flow_price` reads a cell's price; `flow_open` unblocks a
  rectangle. Prices are capped where a walk could pass an int.
- **Directions set in the flood.** Each cell points back along the step that
  gave it its cost, so its way is a cheapest walk's: before, it pointed at its
  lowest-cost neighbour whatever the step there cost, which could leave the
  cheapest walk. The second pass over the field is gone: a million-cell flood
  is 12.1 to 13.2 ms (16.2 before), with a two-cell clearance 14.7 to 16.4
  (`benchmarks/bench_nav`, best of nine, M-series Mac). A bucket queue was
  measured at 19.7 and 15.9 ms and not kept. The direction is one int a cell
  now, not two doubles: 28 bytes a cell, not 32.
- `test_nav` holds the footprints to exact cell counts, the prices to the tenth,
  every cell's way to its cost, and incremental prices to prices made at once.
