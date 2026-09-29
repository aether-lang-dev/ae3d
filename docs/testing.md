# Testing and verification

How the engine is held to what it claims: a suite a subject, each a
program that prints its own verdict; benchmarks with no window; a critique
that judges a scene by number; a frame budget that fails on one extra
triangle; and a way of looking at a scene that does not trust one still.

## The suites

`tests/` is one program a suite, built and run like any example
(`./build.sh tests/test_physics.ae && ./build/test_physics`). Each prints
a line per check and ends with `<name>: all checks passed` or a list of
what failed, and exits accordingly. There are seventy-odd; the rule for a
new one is that it says what it measured and what it wanted, in numbers:

```
  ok   the crate fell onto the slab and rests on it
  ok   the sprung ragdoll is still standing after four seconds (1.593)
  ok   the car drove forward on its wheel joints (-31.2)
physics: all checks passed (240 fixed steps)
```

Most suites are headless: the math, the loaders, the ECS, the horde, the
flow field, the pose bank, the physics, the scene files, the undo history,
the input, the agent protocol. The rendering suites draw through the
offscreen target on both backends and read the pixels back
(`test_render`, `test_shadows`, `test_ray_shadows`, `test_ssr`, `test_taa`,
`test_fog`, `test_lights`, `test_impostor`, `test_skinned_render`, ...);
`test_backend_parity` draws one scene through Vulkan and OpenGL and holds
them to 0.7% of channels differing. A suite that needs a device skips
itself with a message where there is none, and says so rather than
passing.

Every suite that spreads work over the job pool runs at one thread and at
the machine's count, and the answer has to be the same.

## Benchmarks

`benchmarks/` measures per-frame cost with no window and no driver, so
the cost and the allocation behaviour are the engine's own:
`bench_frame` (the heaviest scenes' per-frame work), `bench_scene`,
`bench_shadow`, `bench_readback`, `bench_black_hole`. `AE3D_PERF=1` on any
program prints the device's timestamps around each stage of the frame and
the CPU's time in building it ([performance.md](performance.md));
`scripts/perf.sh` takes the best of three hidden runs of each scene and
prints the table that page keeps.

`scripts/validate.sh [scene ...]` rebuilds each example and runs it on
Vulkan under the Khronos validation layer, printing its error count and the
distinct VUIDs of any that has one, and exits non-zero if any had one.
Every example runs clean, so a new error is the change that made it. The
hosted runners' software Vulkan traces no rays and has none of the
DLSS, meter or crowd paths a GPU takes, so this runs on a GPU before a
renderer change is pushed -- and once more on Mesa's lavapipe
(`VK_DRIVER_FILES=<its lvp_icd json> scripts/validate.sh`, `AE3D_VALIDATE_FRAMES=8`
since it is slow), which takes the paths a device without ray queries
takes and has the smaller limits many real devices have. `AE3D_VALIDATE_SYNC=1`
adds the layer's synchronization validation, and every example is clean
under it too: a hazard is ordering a GPU forgives today and a driver that
overlaps more will not.

The examples draw to a window and read nothing back, so the readback's
ordering is held by `ci.sh` instead. It runs the suites that copy frames out
(`test_fog`, `test_overlay`, `test_backend_parity`) under the layer, with
synchronization validation on, wherever the layer is installed. A validation
error fails that suite. A run the loader did not insert the layer into is
reported as a skip, not a pass (#458).

A number in a document is quoted with its pair from the same run on the
same machine, because two runs on a shared GPU differ by more than most
optimisations gain.

## The critique and the budget

A program that renders can be checked for not crashing and for the number
of draws it issued. Neither says what it drew. Two programs run on every
build over the agent channel ([agent.md](agent.md)) against the measuring
rig `tools/zombie_street.ae` -- one block, one zombie:

- **`tools/critique_scene.ae`** asks whether the scene is any good, with the
  standards a real art review applies and the number each of them is:
  texel density (no surface softer than a texel every four millimetres),
  a normal map on every surface big enough to stand next to, the figure's
  triangle count, the street lit in pools rather than flooded flat, no
  foot through the road, a planted foot staying planted, the strike
  reaching past the walk, the head following the body. Each constant
  carries the reason for its value beside it.
- **`tools/ae3d_bench.ae`** records what a frame costs -- draws, triangles,
  program and material binds, GPU pass times -- in
  `resources/zombie_street.<backend>.budget.json`, and a build that draws
  one more triangle than the record fails until the record is deliberately
  re-taken with `--record`.

Both run on both backends in `ci.sh`, and both exit 3 rather than 1 where
the frame cannot be read back (software Vulkan on a headless runner has no
swapchain), which is a skip and not a judgement.

## The scenes on both renderers

`test_backend_parity` holds the renderers to each other on test scenes of a
few models. Nothing held them to each other on the scenes a person looks at,
which is how `zombie_city` came to draw garbage on OpenGL at 3397101 (the
scenes pack's merge) with every suite passing (#494).
`tools/scene_parity.ae` does, in `ci.sh`, for `zombie_city` from each of its
views 0 to 6, `zombie_street` and `street_drive`:

- Each scene runs on OpenGL and on Vulkan at a fixed tick and holds at the
  same frame (`AE3D_TICK=60 AE3D_HOLD=90`, 640 by 360), so the horde, the
  car and the clouds stand in the same place on both.
- On a shared runner (`CI` set) both renderers are software rasterisers
  (llvmpipe and lavapipe on Linux) and the job has minutes left, so the
  same check is made lighter: 320 by 180, held at frame 12, the city's
  horde a hundred strong with a 12 m near band (still all three tiers;
  400 drawn whole to 600 m were 19 s a frame on llvmpipe), and four of its
  seven views -- 0 (the street and the horde), 2 (the near band up close),
  4 (the wet road at a grazing angle) and 5 (the sky and the skyline). A
  view took 53 to 68 s there on a 24-thread machine; the step prints its
  total.
- What the two do not both do is off, by name: the ray-traced shadows and
  occlusion (`AE3D_RAYS=0`), the eye's adaptation (`AE3D_EYE=0`, it meters
  each renderer's own frame), the temporal pass (`AE3D_TAA=0`, it folds in
  however many frames the hold drew) and the screen-space reflections (the
  tool turns them off through `render.set`; Vulkan's alone until #491).
- The frame is read as a 32 by 18 grid (`frame.grid`), then again with
  every model hidden and with each region's models alone
  (`scene.isolate matching=[...]`): the sky, the facades, the road, the
  figures, and the rest -- whatever a model draws that no region names --
  so nothing drawn goes unjudged. Each region's mean difference between the
  renderers is held to 2 of 255: the worst measured and half again, never
  under 2. The worst were, on an RTX 4070 Ti (nine views, three runs, the
  same to the tenth), sky 0.2, facades 0.7, road 0.8, figures 1.2, the rest
  0.5; on Mesa 26's llvmpipe and lavapipe (nine views, the runner's
  settings, two runs), sky 0.6, facades 0.8, road 1.1, figures 0.7, the rest
  0.4, and road 1.3 with the horde a hundred strong as the runner has it. The verdict names both devices. What is left under 2 -- the
  occlusion's grain and the wet road's far streaks, a unit apart -- is
  #503.
- A hole fails the view: a cell where one renderer draws a model and the
  other, differing there by more than 12, shows its own sky or the clear
  colour. The first three are printed with what each renderer shows.

At 3397101 every `zombie_city` view fails -- its facades and road 17 to 55
apart, its figures 10 to 31, 16 to 197 of the 576 cells holes -- and
`zombie_street` and `street_drive`, which it drew right, pass. The check
has found three real differences:
- the lamp's haze in the fogged air was Vulkan's alone, and `zombie_street`
  drew a fifth brighter there (mean red 92 against 74);
- Vulkan turned every normal map inside out: the tangent frame is solved
  from the screen's derivatives, the solve dropped the sign of its
  determinant, and the screen's y runs up on OpenGL and down on Vulkan.
  The wet road's ripples turned the other way, 2.2 and 5.3 apart on the
  street's road and figures on a GPU and 6.4 and 14.7 on a runner's Mesa;
  now 0.0 and 0.1 (`test_backend_parity`'s bricks under a raking light:
  33,506 channels apart before, 852 now);
- a crowd sorted on the device is one model whose bounds are one figure's
  at the origin, and a lamp's face asked by those drew the crowd only where
  it held the origin: in the city a lamp's pool in the horde was lit on
  Vulkan with no figure's shadow in it (view 3's road 3.3 apart, now 0.8;
  `test_ray_shadows` holds a figure 212 m out under a lamp of its own).

## Looking at a scene

One still hides most of what goes wrong in a scene: a figure that
teleports, one that vanishes on a zoom, a seam that shows from a grazing
angle, a shadow that slides with the camera. So a scene is verified from a
sweep, and by number:

- `AE3D_CAMERA_WANDER=n` flies the camera at random through any scene for
  `n` frames and measures every move against the drawn triangles
  themselves: the nearest it came to anything, to what and where, and the
  frames it ended inside a solid or under the ground.
- The edge of the world, counted: `zombie_city` with `AE3D_SKY=0` draws
  nothing where nothing is -- black, which no surface is in a frame drawn
  as normals (`AE3D_CAPTURE=2`) -- and logs the row the horizon crosses;
  `tools/probe_image.ae frame.png --key 0 0 0 ROW` counts the black pixels
  from that row down, which is none where the world has no edge in view.
  `AE3D_HORDE_ONLY=1` draws the horde alone, and the same count is the
  share of the frame it takes.
- `AE3D_VIEW=n`, `AE3D_CAMX/Y/Z` and `AE3D_AIMX/Y/Z` place the camera by
  number in the scenes that take them; `scripts/contact_sheet.sh <scene>
  out.png` renders the default view, a low grazing view and a view toward
  the sun on both backends and lays the six out as one picture
  (`tools/montage.ae`).
- A detail is judged at full size with `tools/crop.ae`, and in numbers with
  `tools/probe_image.ae`: the mean colour and greyness of each band of a
  frame, and what moved between two. A thumbnail is not evidence; a
  sampled pixel with its four channels is.
- The scenes log what they decided (`zombie_city[diag]`, `AE3D_DIAG=1` in
  the street): the tiers and their triangle counts, every light, each
  material's texture and the GPU id it resolved to, and a periodic check
  that no figure ever moved further than it can walk. A clean position
  check can still miss animation-driven "teleporting", which is why the
  audit runs every frame over the pool.
- `tools/ae3d_view.ae` prints a frame the channel answered with as
  characters, one cell a mean, so a run on a machine without a screen can
  still be looked at; `tools/measure_scene.ae` asks the engine what each
  model is made of, where it landed on screen, what colour it arrived at,
  and whether the picture is stable under a movement too small to change
  what is in it.

## Leaks and platforms

On macOS `ci.sh` runs the headless programs under `leaks --atExit` and
fails on a lost allocation whose stack is the engine's; a system retain
cycle from a GPU context is reported apart (`AE3D_SKIP_LEAKS=1` skips it). The three runners (Linux with GTK 4
and a software Vulkan, macOS with MoltenVK, Windows under MSYS2 UCRT64)
build every C file alone with warnings as errors, because every
Windows-only assumption in the tree survived exactly as long as there was
no Windows runner.

## Writing a test

A test states what it wanted and what it got, in the unit the reader
thinks in (metres, frames, milliseconds, channels), on the line it fails.
It drives the engine for a bounded number of frames or steps, never "until
it settles". It reads the engine's own numbers -- transforms, counters,
pixels through the offscreen target or the channel -- rather than a file
written by another tool. And where it measures time it prints the pair:
what it took and what the previous implementation took, in the same run.
