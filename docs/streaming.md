# Streaming a world

A world can be larger than what the engine holds. `ae3d.worldbake` cuts a
scene into a grid of cells, each with a cell file and a far stand-in.
`ae3d.stream` then loads the cells around the camera and the players and
lets them go once they are behind.

## Baking

```
err = worldbake.bake(models, flags, 64.0, x0, z0, nx, nz, "build/world/")
```

Each model goes into the cell its bounds' centre stands over. `flags`, an
`int[]` beside the models or null, marks what each model is to the world
besides being drawn: `cellfile.FLAG_COLLIDER` or `cellfile.FLAG_NAV`. The
bake writes, under the directory:

- `cell_<x>_<z>.aecell` for every cell with a model in it. This is the
  cell's models as the renderer takes them: vertices, indices, instances,
  materials as JSON, world transforms and flags (see `ae3d.cellfile` for
  the layout).
- `cell_<x>_<z>.far.aecell`, the cell's stand-in, built as follows:
  - Every model drawn once is merged into one mesh. Instanced props are
    left out, since they are under a pixel at that distance.
  - The mesh is simplified to the coarsest cut of its cluster graph
    (`ae3d.clusterlod`). The vertices that two materials share are held,
    so no crack opens between them.
  - Each material's texture is replaced by the texture's mean colour (in
    linear light) baked into its diffuse. A stand-in holds no texture.
- `world.json`: the cell size, the origin, the size in cells, and each
  cell's two files.

`worldbake.last_stats()` reports what the bake wrote.

## Loading around a focus

```
st = stream.open("build/world/world.json")
stream.set_engine(st, e)
stream.set_radius(st, 160.0, 32.0)        // loaded within 160 m, let go past 192
stream.set_far(st, 600.0)                 // stand-ins out to 600 m
stream.set_budget(st, 4 * 1024 * 1024)    // bytes of geometry into the renderer a frame
...every frame
stream.focus_clear(st)
stream.focus(st, cam.position.x, cam.position.z)   // and one for each player a host keeps
stream.update(st)
```

Each cell moves through these states:

| State | What it means |
|---|---|
| unloaded | Nothing of it is held. |
| loading | A worker (`std.worker`) is reading its file, building its meshes, reading its materials and decoding the textures it names that no resident cell holds. |
| leaving | It was loading but is no longer wanted. It is freed the moment its load arrives. |
| loaded | Decoded, waiting for the frame's budget. |
| attaching | Its models are going to the renderer, as many each frame as the budget allows, and at least one, so no cell waits for ever. |
| resident | Every model is in. |

A cell is wanted when its square comes within the radius of any focus. It
is kept until it is past the radius plus the margin, so a focus pacing
along a border does not load and free the same cell over and over. Cells
are loaded nearest first, a few at a time (`set_loads`). A cell's stand-in
is loaded within the far radius and drawn only while the cell itself is
not resident.

The loop thread does only cheap work. A decoded model becomes the engine's
by being handed its mesh, and the decoded textures are offered to the
renderer (`core.offer_preloaded_image`), which takes them as the models
reach it.

### What the game does with it

`event_count`, `event_kind` and `event_cell` report each cell that arrived
(`ARRIVED`, all its models in) or is about to leave (`LEFT`, said before
its models are freed). `cell_models` gives the cell's models, so the game
can add and remove colliders and nav blockers. Call `events_clear` once the
events have been read.

### What it holds

`resident_bytes` and `peak_bytes` count what the cells' decodes made: their
geometry, and the textures they decoded. A cell counts from the moment it
arrives until it is freed. `missing(st, metres)` counts the cells within
that distance of a focus that are not resident.

A load takes time. The radius should be the distance a cell must be ready
by, plus what the fastest focus covers while a cell loads. The test drives
at 30 m/s and allows a lead of 32 m.

### On the agent channel

`stream.cells` answers with every open stream: its grid, its radii, the
bytes it holds and its peak, how many loads are in flight, how many cells
within the radius are missing, and every cell that is not unloaded with its
state, its stand-in's state, its distance and how many times it has loaded.

## Textures

A renderer holds a texture while a model it draws uses a material that
names it, and lets it go with the last such model (`Material.renderer_users`).
A world streamed past therefore keeps only the near cells' textures in
memory, and a cell that comes back reads its textures again.
