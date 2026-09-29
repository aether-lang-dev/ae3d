### The scenes a person looks at, drawn alike by both renderers (#494)

- `tools/scene_parity.ae`, run by `ci.sh` for `zombie_city` from each of
  its views 0 to 6, `zombie_street` and `street_drive`: each scene on
  OpenGL and on Vulkan at a fixed tick, held at the same frame (640 by 360,
  frame 90), compared region by region -- the sky, the facades, the road,
  the figures and the rest (whatever a model draws that no region names) --
  as the mean of a 32 by 18 grid's cell differences. The tolerances are
  written in the tool with what they were measured from: sky 2, facades 4,
  road 5.5, figures 8, the rest 2 (of 255), against the worst of the nine
  views at sky 0.6, facades 2.5, road 3.4, figures 5.3 and the rest 0.5,
  the same to the tenth over three runs. A view also fails on a hole: a
  cell where one renderer draws a model and the other shows the sky or the
  clear colour.
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
- `zombie_city`'s impostor tier is named for its figure
  (`Zombie_Body, impostors`), so the channel and the check find the
  horde's far band.
