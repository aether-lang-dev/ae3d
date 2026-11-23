# Props placed by rule

`ae3d.scatter` fills a district with props (street clutter, vegetation,
debris) from rules: tagged areas, roads, places kept clear, and palettes
that say which props go where, how densely and how far apart. The same seed
and rules place the same props on every machine, and the result is one
instanced model per prop, so a district of thousands of props draws once per
prop.

## The pieces

- **The ground**: `ground_new(models, cell)` samples the ground's models into
  a height field, one cell every `cell` metres, keeping the highest surface
  and its normal. `ground_height`, `ground_normal_y` and `ground_covers` read
  it. A place with no surface under it gets no props.
- **Areas**: `add_area(s, xz, count, tags, wealth)`. A polygon on the ground
  plane (`count` x,z pairs), its tags comma-separated (`"industrial,
  rundown"`) and a wealth from 0 to 1.
- **Roads**: `add_road(s, xz, count, width)`. A polyline with a width. No prop
  is placed on a road, or within half its palette's spacing of the edge.
- **Exclusions**: `add_exclusion(s, x, z, radius)`. A circle kept clear, such
  as a doorway or a corridor the navigation needs.
- **Palettes**: `palette_new(name, density, spacing)` gives props per square
  metre and the minimum distance from every prop placed before, in any
  palette. The setters narrow it down:
  - `palette_slope(p, min, max)`: the slope range in degrees.
  - `palette_height(p, low, high)`: the height range.
  - `palette_tags(p, require, exclude)`: an area must have every required tag
    and none of the excluded ones.
  - `palette_wealth(p, low, high)`: the wealth range.
  - `palette_align(p, ALIGN_NONE | ALIGN_SURFACE | ALIGN_ROAD)`: turned at
    random about the vertical, stood on the ground's normal, or facing along
    the nearest road.
  - `palette_scale(p, low, high)`: the scale range.
  - `palette_prop(p, model, weight)`: a prop, chosen in proportion to its
    weight. The model is the caller's and serves as the prop's template.

  `add_palette(s, p)` hands the palette to the scatter, which frees it.

```
s = scatter.scatter_new(seed)
scatter.add_area(s, block, 4, "residential", 0.6)
scatter.add_road(s, street, 2, 6.0)
clutter = scatter.palette_new("clutter", 0.05, 2.0)
scatter.palette_tags(clutter, "residential", "")
scatter.palette_slope(clutter, 0.0, 20.0)
scatter.palette_align(clutter, scatter.ALIGN_ROAD)
scatter.palette_prop(clutter, barrel, 2.0)
scatter.add_palette(s, clutter)

n = scatter.run(s, ground)          // how many props were placed
models = scatter.build_models(s)    // one instanced model per prop: add them to the engine
...
scatter.models_free(models)
scatter.scatter_free(s)
```

`run` places palette by palette and area by area. Each area gets
`density x area` props, or fewer where the rules leave no room after 30
tries per prop. Running again starts over from the seed. `placement(s, i)`
gives each placement's position, up vector, facing, scale, palette and prop.

## The same on every machine

The random numbers are integers (splitmix64). A direction is drawn by
rejection inside a ring instead of from an angle. The slope limit's cosine
comes from the module's own series, not the C library's. Everything else is
IEEE arithmetic and square roots, which every platform rounds the same way
because the engine is built with `-ffp-contract=off` (see
`scripts/native.sh`). Each candidate draws its prop, direction and scale
whether it is kept or not, so a rule that rejects one candidate does not
shift the numbers of any other.

`hash(s)` fingerprints the placements. `tests/test_scatter.ae` holds its
district to a single value. If that value changes, the placements changed.

## A scatter file

`load(path)` reads the same rules from JSON so the pipeline can write them
from a district's tagged areas. The props are OBJ files, which the scatter
loads and frees itself. On failure it returns null and sets `last_error()`.

```
{"seed": 7,
 "areas": [{"points": [x, z, ...], "tags": ["residential"], "wealth": 0.4}],
 "roads": [{"points": [x, z, ...], "width": 6}],
 "exclusions": [{"x": 0, "z": 0, "radius": 2}],
 "palettes": [{"name": "clutter", "density": 0.05, "spacing": 2,
               "slope": [0, 20], "height": [-10, 50],
               "require": ["residential"], "exclude": [], "wealth": [0, 1],
               "align": "road", "scale": [0.8, 1.2],
               "props": [{"model": "resources/obj/Cube.obj", "weight": 1}]}]}
```

`tests/fixtures/scatter/district.json` is the test's district written this
way, and it places exactly what the code-built district does.

## What it costs

Measured with `benchmarks/bench_scatter.ae` on an M1 Pro, best of five: a
512 m square sampled at 0.25 m (2048 x 2048 cells), with sixteen districts,
two palettes and a road along every row and column.

| Step | Time |
|---|---|
| Sampling the ground | 32 ms |
| Placing 9,216 props | 4 ms |
| Building the 3 instanced models | under 1 ms |

Ground sampling grows with the number of cells, so a coarser `cell` makes it
cheaper. Placement grows with the number of props, because spacing is
checked against a spatial hash of the props already placed.
