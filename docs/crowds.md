# Crowds and navigation

How the engine carries a horde: a figure's walk baked once into a pose
bank, its instances kept in dense columns rather than objects, the
simulation's passes run over the job pool, the flow field the horde
follows, and the tiers the renderer sorts it into. The draw side -- the
pose bank sampled in the vertex shader, the impostors, the sort on the
device, the indirect draws -- is in [rendering.md](rendering.md); this page
is the simulation.

![Twenty thousand zombies filling the street from end to end, the near ones the full mesh, the far ones pictures](images/zombie-horde.png)

## The entity store

`ae3d.ecs` is the other shape a scene can take. A game object is a heap
block and a vtable of phases, the right shape for a handful of scripted
things and the wrong one for a million: an allocation and a virtual call
per entity per frame, and no two entities' data adjacent. In the ECS an
entity is an integer handle (a slot and a generation, so a handle kept
past its entity's death fails `entity_alive` instead of reading a
stranger's data), and component data lives in dense preallocated columns
a system walks front to back. Nothing is allocated per entity after the
world is built. Twenty-four index bits hold 16.7 million live entities.

## The pose bank

A skinned draw is posed by one bone palette. A crowd cannot be: a thousand
figures at a thousand points in the walk would be a thousand palettes.
`crowd.posebank_bake` samples a clip into a bank of `frames` poses, each a
full palette at one time in the clip; every instance carries a phase and
is posed in the vertex shader from the frame its phase picks. The bank is
fixed at `frames` poses however large the crowd grows, which is what lets
an animated crowd scale the way a static one does. `posebank_travel` and
`posebank_speed` say how far the clip's root moves in a cycle, so a
figure's feet plant: the step each frame is the bank's pace, not a number
chosen to look right. `gltf.bake_bank` strikes any glTF clip into a bank,
so a figure from a public pack is a horde in one call (`examples/gltf_crowd.ae`).

## The horde's passes

`ae3d.horde` is the crowd's simulation, in Aether over the columns and the
engine's pool. Each pass is the same few lines on every figure with nothing
shared but the arrays, run in blocks of a few thousand (`horde.GRAIN`):

- **The separation.** Pushing a crowd apart is the one super-linear pass:
  every figure against the neighbours in the nine cells around it, tens
  of millions of tests a frame at half a million. A counting sort packs
  the positions themselves cell by cell (a per-cell offset table over
  packed arrays), so the neighbour scan walks a cell's figures as one
  contiguous run; the only scattered access left is one write of the
  accumulated push to each figure's velocity. A cell keeps at most
  `per_cell` figures, so a jammed cell costs a bounded number of tests
  and the few not pushed this frame are a different few next frame.
- **The wander** (a heading drifted by noise) and **the step** (a figure
  along its heading at the bank's pace, its phase advanced).
- **The tiers**: the sort by distance from the camera into the full mesh,
  the stand-in and the impostor, over fixed runs (`jobs.parallel_for_fixed`)
  so every worker writes its own stretch of the compacted buffers and the
  order is the order one thread would have written.
- **The audit**: every figure against its last position, so a figure
  that teleported is a failed test and not a frame someone has to notice.

The trigonometry is approximate on purpose -- a facing needs to be right
to a degree, not to a bit -- and several times cheaper than libm's at
half a million a frame. Measured against the C it replaced, in the same
run on the same 24-thread machine: the separation of half a million on
one thread 51.4 ms against 51.5; the city's 200,000 over the pool
separate in 5.5 ms against 5.45, step in 0.92 against 0.80, wander in
0.18 against 0.26. With the sort on the device the whole simulation of
half a million is 8 ms of a frame at 79 fps ([performance.md](performance.md)).

`ae3d.crowd` wraps the passes for a scene (`crowd_wander`, `crowd_step`,
`crowd_tiers`, `crowd_audit`, `horde_separate` over a `CrowdGrid`) and
owns the device crowd (`device_crowd_new`, `device_crowd_update`), the
buffer the compute sort reads.

## Navigation

A path per figure is a search per figure; a hundred thousand of them want
one search. `ae3d.nav` is a flow field over the ground:

```aether
field = nav.flow_new(x0, z0, x1, z1, 1.0)            // the ground, metres, a cell a metre
nav.flow_block_mesh(field, fence, -0.3, 2.2, 0)       // what nothing walks through: its own triangles
nav.flow_block_model(field, bin)                      // or a compact thing's bounding square
nav.flow_clearance(field, 2, 30)                      // walls kept at a body's distance
nav.flow_build(field, core.vec3(px, 0.0, pz))         // the target: the player
nav.flow_steer(field, positions, yaws, count, 2.0 * delta)   // every heading toward it
```

The field is the price from every cell to the target, found by one flood
from the target outward over the cells nothing stands in: a Dijkstra
eight ways, a straight step 10 and a diagonal 14 (tenths of a cell, as
integers, so the frontier is a ring and not a heap), plus what the cell
stepped into costs, and no diagonal past a blocked corner so nothing is
told to walk through the edge of a wall. Each cell's direction is set with
its cost, toward the cell it was reached from, so it points along the walk
its cost was paid for; where two ways in tie, the one from nearer the
target. A figure reads the direction under its feet and turns toward it by
at most `turn` a step, so the horde swings round rather than snapping;
where the field says nothing it keeps its heading and the wander and
separation carry on.

### What blocks a cell

- `flow_block(f, x0, z0, x1, z1)` a rectangle, and `flow_open` the same
  rectangle open again (a wall torn down).
- `flow_block_mesh(f, model, low, high, grow)` the cells under a model's own
  triangles, each instance's for an instanced model, cut to the band of
  heights from `low` to `high` (where a body is, in the world's heights),
  then grown by `grow` cells. A 40 m fence 0.2 m thick blocks its 40 cells;
  its bounding square closed over 1,600. A shack keeps its doorway, a water
  tower blocks its legs and not the ground under its tank (#817). A cell is
  covered where the triangle's shadow is inside it by more than a
  ten-thousandth of a cell, and more where float32 is coarser, so a block
  a cell across placed on the cell's lines, by an instance matrix too,
  blocks its one cell. A face on a cell line blocks the cell behind it,
  into the solid (the faces wound counter-clockwise, as glTF and the
  loaders wind them), so a lone panel on a line blocks one row and leaks
  nothing. Growth is a disc by the flood's own measure: one cell round a
  row of 20 is 62 cells, and two round a single cell is 13. A skinned mesh
  and a model drawn as points block nothing.
- `flow_block_model(f, model)` the bounding sphere's square: cheap and
  right for something compact, wrong for anything long, thin or hollow.

### Dear cells and the clearance

Blocked is all or nothing. A field that kept bodies off walls by blocking a
margin closed every doorway narrower than two margins, and left whoever
stood in the margin on a cell with no direction (#819). A cell can be dear
instead: every step into it costs its price more, in tenths of a cell for
each cell crossed (a diagonal 1.4 times it).

- `flow_clearance(f, cells, extra)` prices the cells within `cells` of a
  wall: `extra` beside it, falling evenly to `extra / cells` at `cells` away.
  The field then leads round a wall at a body's distance, through a doorway
  when that is the only way, and out of the margin for anyone already in it.
  It stays with the field: as walls go up and come down, only the cells
  within reach of the change are priced again (a 20 m wall, 1.05 us; the
  whole million-cell field, 5.7 ms).
- `flow_cost_rect(f, x0, z0, x1, z1, extra)` sets an area's own price, for
  mud, a fire, a road the crowd keeps off; 0 takes it off.
- `flow_price(f, x, z)` reads a cell's price, `flow_cost` the walk's price in
  metres (its length plus what the dear cells on it add).

A price is at most `MAX_PRICE` (1000, a hundred cells' walk), and less on a
field of more than about 1.5 million cells, where the cap keeps every walk's
cost inside an int.

### What it costs

`benchmarks/bench_nav` on a field of 1024 x 1024 cells (a city of 24 m
blocks with gaps, 520,026 cells reached), best of nine on an M-series Mac:

| | ms |
|---|---|
| flood, every cell one price | 12.1 to 13.2 (16.2 before the directions were set in the flood) |
| flood, with a clearance of two cells | 14.7 to 16.4 |
| the clearance over the whole field | 5.7 |
| a 20 m wall up or down, clearance on | 0.001 |
| a 600-instance fence's footprint (7,200 triangles), grown by a cell | 0.35 to 0.40 |

A bucket queue (Dial's), which settles each cell once, was measured on the
same field at 19.7 and 15.9 ms: its lists cost more writes a step than the
second relaxations it saves (0.8% of cells at one price, 18% with the
clearance). The marks, prices and costs are ints and the direction one int
naming one of eight ways, 28 bytes a cell. The steer runs over the pool and
reads a cell's way and its heading from a table of eight. A cell points
one of eight ways, so the heading it asks for is one of eight constants,
not libm's `atan2`, which isn't the same function on every platform: a
horde stepped on every peer of a game
([networking.md](networking.md#the-horde)) turns by the same bits on each. The city's horde hunts the camera with it, so it fills the
view it is seen from (`AE3D_HUNT=0` lets it wander instead).

## What is checked

`tests/test_horde` starts a crowd in a wide ring and checks its mean
distance to the target collapses (a horde moves as one); `test_horde_separate`
starts 1,500 figures on one spot and checks the crowd's spread grows as they
shove apart; `test_horde_scale` runs the whole update over half a million
and fails if a step blows past real time; `test_nav` floods a field and
checks the directions and the headings turned by them, the footprints a
cube, a fence straight and on the diagonal, a shack, a water tower and a
lone panel take, by exact cell counts, the clearance's prices to the tenth,
every cell's way against its cost and the step it names, and prices kept
up as walls go up and down against prices made at once; `test_posebank`
checks each baked frame against the skeleton driven live to the same
time; `test_crowd_ecs` and `test_ecs*` the store; `test_device_crowd` the
device sort against the CPU's; `test_jobs` the pool's pass and block
counts at one thread and many; `test_net_horde` a horde stepped alone and
over four threads, compared bit for bit. Every pass but one gives the same
bits at any thread count: the separation with no pool visits each pair once
and pushes both, the same pushes added in another order than the pool's
gather, so its velocities can differ in their last bits (1,773 of the 4,500
velocity components of a knot of 1,500). `horde.separate_exact` gathers alone too, at twice the pair tests, and
is what a networked horde steps by. The tests run at one thread and many.
