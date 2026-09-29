### The scenes a person looks at, drawn alike by both renderers (#494)

- `tools/scene_parity.ae`, run by `ci.sh` for `zombie_city` from each of
  its views 0 to 6, `zombie_street` and `street_drive`: each scene on
  OpenGL and on Vulkan at a fixed tick, held at the same frame (640 by 360,
  frame 90), compared region by region -- the sky, the facades, the road,
  the figures and the rest (whatever a model draws that no region names) --
  as the mean of a 32 by 18 grid's cell differences, each region held to 2
  of 255. The tolerances are written in the tool with what they were
  measured from: the worst of the nine views was sky 0.2, facades 0.7, road
  0.8, figures 1.2 and the rest 0.5 on an RTX 4070 Ti (three runs, the
  same to the tenth), and 0.6, 0.8, 1.1, 0.7 and 0.4 on Mesa 26's llvmpipe
  and lavapipe; each tolerance is the worst and half again, never under 2.
  A view also fails on a hole: a cell where one renderer draws a model and
  the other shows the sky or the clear colour. What is left under 2 is
  #503.
- On a shared runner, where both renderers are software rasterisers and
  the job has minutes left, the same check is made lighter: 320 by 180,
  held at frame 12, the city's horde a hundred strong with a 12 m near band
  (all three tiers still drawn), and views 0, 2, 4 and 5 of its seven, each
  kept for a region at its largest. The step prints its total.
- What the two renderers do not both do is off by name: the rays
  (`AE3D_RAYS=0`), the eye's adaptation (`AE3D_EYE=0`), the temporal pass
  (`AE3D_TAA=0`) and the screen-space reflections (Vulkan's alone until
  #491).
- The reproduction: at 3397101, the scenes pack's merge that drew garbage
  on OpenGL, every `zombie_city` view fails -- its facades and road 17 to
  55 apart, its figures 10 to 31, 16 to 197 of its 576 cells holes -- and
  `zombie_street` and `street_drive` pass. At this change all nine pass.
- A frame that is the same on every run and either renderer:
  `AE3D_TICK=60` advances the world by exactly 1/60 s a frame and the
  renderers' clock (`platform.scene_time`, what the clouds, the water and
  the caustics animate by) with it; `AE3D_HOLD=90` holds the engine at
  frame 90 as `frame.pause` would. `frame.stats` reports the clear colour,
  and `scene.isolate` takes `matching` (the models whose names hold one of
  the strings) and `none` (the sky alone). `tests/test_scene_hold` holds
  all of it on both renderers (11 checks).
- The first run found a real difference: the lamp's haze in the fogged air
  was Vulkan's alone, and `zombie_street` drew a fifth brighter there
  (mean red 92 against 74). It is on OpenGL too now, from the same numbers
  (`rendering.HAZE_SHARE`, `HAZE_STEPS`, `HAZE_SCATTERING`); the street's
  facades agree to 0.3. It costs OpenGL's scene pass about a quarter of a
  millisecond in the street (the median of three runs each, alternating:
  1.25 ms with it against 1.00 without, 1280 by 720 on an RTX 4070 Ti),
  and the street's frame budget still passes.
- And a second, in both renderers: a draw whose settings differ from the
  one before is wiped back to the defaults, and the defaults had the haze
  off, so every model that asked for nothing lost it once a model with
  settings of its own drew beside it. The defaults carry the frame's haze
  now (`rendering.set_frame_haze`); `test_fog` holds a ground beside a
  configured slab to its haze on both (it lost all of it before: 701456
  against 827234).
- The check found two more, both fixed in the renderers:
  - Vulkan turned every normal map inside out. The tangent frame is solved
    from the screen's derivatives, the solve dropped the sign of its
    determinant, and the screen's y runs up on OpenGL and down on Vulkan:
    the wet road's ripples ran the other way, zombie_street's road and
    figure 2.2 and 5.3 apart on a GPU and 6.4 and 14.7 on a runner's Mesa;
    now 0.0 and 0.1. `test_backend_parity` lays bricks under a raking light
    (33,506 of 147,456 channels apart before, 852 now).
  - A crowd sorted on the device is one model whose bounds are one figure's
    at the origin; a lamp's face, and a cascade, asked by those drew the
    crowd only where they held the origin, and a lamp's pool in the city's
    horde was lit with no figure's shadow in it (view 3's road 3.3 apart,
    now 0.8). It is bounded by its figures now, as OpenGL's crowd is by its
    instances; `test_ray_shadows` stands a figure 212 m out under a lamp of
    its own (497 against 675 casting nothing; 675 before). Drawing it there
    costs the city at 20,000 figures (rays on) 19.05 fps to 17.5, the shadow
    stage 2.3 ms to 9.6 with the crowd's depth shader dropping figures past a
    lamp's reach (10.9 without); each lamp's faces drawing only the figures
    within its reach is #505. At 400 it stays at 144 fps, 6.55 to 6.68 ms
    of device time.
  - And the occlusion's normal took its upward neighbour from the screen's
    y, which runs the other way on Vulkan; it takes the one above on both.
- `zombie_city`'s impostor tier is named for its figure
  (`Zombie_Body, impostors`), so the channel and the check find the
  horde's far band.
