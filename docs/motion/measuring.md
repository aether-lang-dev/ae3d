# Measuring motion

A change to motion is judged by numbers read off what is drawn, the same way in the suites, the showcases and a game's scorecard, and then by looking at the scene. This page is the meters (`ae3d.metrics`, #854), the suites that hold each layer, the tools that show it, and the order to judge a change in.

## The meter

A meter reads a figure's drawn skeleton every frame (`pose.read`), whoever wrote it: the animator, a ragdoll, a get-up, a hand-off between them. So every writer and every hand-off is held to the same definitions.

<!-- example: examples/docs/first_walk.ae#meter -->
```aether
m = metrics.meter_new(animator.rig(character.animator_of(hero)), o)
metrics.meter_ground_physics(m, physics.of(e))         // the soles read against the physics' static world
```

<!-- example: examples/docs/first_walk.ae#measure -->
```aether
metrics.meter_reset(m)                                 // a new window
k = 0
while k < frames {
    character.move(hero, velocity, facing)
    engine.engine_update(e, STEP)
    metrics.meter_take(m, STEP)                        // after the frame is drawn
    k = k + 1
}
return metrics.meter_worst(m, metrics.SKATE)           // the worst a planted toe slid, metres
```

`meter_worst(m, measure)` is the worst over the window, `meter_when` when it happened, `meter_joint` which joint. `meter_animator(m, a)` measures a drawing past what the animator's own pose does (what IK and hand-offs add); `meter_set_reference(m, fastest)` gives the take's own fastest joint turn a pop is judged against (`metrics.take_fastest(take, rig)`).

| measure | what it reads | the suites' usual bound |
|---|---|---|
| `POP` | the fastest any joint turned in a frame, rad/s | the take's own fastest, plus what the easing itself needs |
| `SKATE` | how far a toe's tip slid over the ground while its foot stood on it, metres a stance | 5 mm |
| `INTO_GROUND` | how far a sole (heel, pad or toe) went into the ground | 5 mm |
| `JERK_HANDS`, `JERK_PELVIS` | the third derivative of position, m/s^3 | |
| `LEGS_APART` | how close the legs came, shin to shin, thigh to thigh and across (the least) | 8 cm in the showcase |
| `KNEE_OUT`, `KNEE_IN` | a knee bent 6 cm off its leg's line pointing out off the hips' way, or in | 30 degrees in the showcase |
| `CHEST_TWIST` | the shoulders' line against the hips', level | 30 degrees at a run in the showcase |
| `FOREARM_ROLL` | a forearm's roll off its upper arm | |
| `FEET_CROSS` | how far a foot stood past the hips' middle (below 0: neither crosses) | never above 0 |
| `GOAL` | how far a joint was from a goal it was set (`meter_goal`) | per test |
| `FOOT_THROW` | how much faster a toe went than its clip has it go, m/s | |
| `FLICKER` | a leg joint turning one way and back within 4 frames past the animator's own detour | 0.1 rad (`FLICKER_ANGLE`) |

What "standing" means for `SKATE` decides what it reads, and each rule came from a false reading (constants in `src/ae3d/metrics/module.ae`): a stance begins when the pad is within 1.5 cm of the ground (`CONTACT`) and the toe's tip moves slower than 0.5 m/s (`STANCE_SPEED`; a swing skimming the floor at 3.5 m/s read as a 57 mm slide); a foot that stays within `CONTACT` longer than 0.05 s (`SKIM_TIME`) stands after all (#927: a walker carried off at 18 m/s along the ground began no stance and read 0 mm); a stance ends once the foot's lowest point is 5 mm above the lowest it was in that stance (`LIFT_OFF`; by the pad alone a foot pitched up off the ground read a 10.5 mm skate, #926).

The ground is the figure's floor unless a physics world is given (`meter_ground_physics`), whose static geometry is read by a ray under each sole point. The soles are ikrig's: heel, pad and toe found from the rig, or from the flesh where a foot has no toe joint.

Known meter defects: the skating meter reads a take's swing as stance where its soles sit under the floor (`anim_viewer` shows 102 mm on a clean walk) and the knee meter misreads a rig whose toes point against its hips (#1022); a sole beside a 0.6 m deck reads 600 mm into the ground (#978); a foot thrown faster than its clip reads as nothing (#972).

## The suites, by layer

Each suite prints its measurements and its verdict; `ci.sh` builds and runs every `tests/test_*.ae` ([testing.md](../testing.md)).

| layer | suites |
|---|---|
| rigs, clips, retargeting | `test_anim_pipeline` (125 checks on 2026-11-19 at `bea4c991`), `test_runtime_clip`, `test_skinned_render`, `test_anim_memory` |
| animator and graph | `test_anim_pipeline`, `test_animgraph`, `test_blend`, `test_blend_writers`, `test_idle`, `test_face`, `test_springs`, `test_orient_warp`, `test_matching`, `test_matching_db` |
| ikrig | `test_ik_constraints`, `test_feet`, `test_feet_edges`, `test_feet_steep`, `test_feet_overhang`, `test_hips_writers`, `test_lookat`, `test_items` |
| mover and character | `test_humanoid`, `test_locomotion`, `test_stop_speeds`, `test_stop_settle`, `test_go_to`, `test_use`, `test_stances`, `test_character`, `test_character_walls`, `test_characters_meet`, `test_characters_avoid`, `test_frame_rates`, `test_ledges` |
| physical animation | `test_physanim`, `test_hit_reaction`, `test_balance`, `test_knockdowns`, `test_get_up`, `test_get_up_pair`, `test_deaths`, `test_ragdoll_fit`, `test_character_bodies`, and the frozen `ae3d.motion`'s `test_motion`, `test_falls`, `test_stagger`, `test_writhe`, `test_crawl`, `test_sit`, `test_lie`, `test_kneel`, `test_eat` |
| networking | `test_net_anim`, `test_net_handover` |
| LOD and jobs | `test_animlod`, `test_jobs`, `benchmarks/bench_animlod.ae`, `benchmarks/bench_motion_matching.ae`, `benchmarks/bench_skin.ae` |

A suite that runs seeds (`test_knockdowns` takes 100) prints its worst seed, so a failure replays with that seed alone.

## The tools a person watches

- **`tools/anim_showcase.ae`**: the pipeline's figures for a person to watch (`AE3D_WATCH=1` to `8` follows one: the runner, the female, the hit figure, the captured walker, the figure on a stick, the climber, the rifleman, the swordsman). `AE3D_METRICS=1` prints each figure's meters each cycle. `ci.sh` builds and runs it with the examples.
- **`tools/anim_viewer.ae`** (#854): one clip at a time on its own figure and retargeted onto another (`AE3D_TARGET`), side by side, the skeleton drawn over each and its meters on screen; Up and Down step through the clips, Space plays, Left and Right step a frame.
- **`tools/people_plaza.ae`**, **`tools/plaza_showcase.ae`**, **`tools/motion_showcase.ae`**: people in a scene, struck by a car, getting up; the acceptance scene for a change.
- **`tools/measure_stops.ae`** (#1024): every stop in the take library measured, the speed it brakes from, its time, way and deceleration, and how far its hips turn.
- **`tools/bvh_cut.ae`**: frames cut from a capture unedited, for a fixture.

## How to judge a change

1. **Measure before changing.** Run the suite that holds the layer on the base (the PR's head, in a worktree of its own) and keep its output. A number without its base is not a result.
2. **Sweep before tuning to a check.** A flaky check is swept on the base first (seeds, frame rates: `test_frame_rates`, `AE3D_SEED`); a bound met on one seed and missed on another is a finding, not a pass.
3. **Change one thing, with knobs as environment variables**, so a grid of values runs from one build.
4. **Hold it to the meters**, past the animator's own pose (`meter_animator`), against the take's own fastest joint plus the easing's need: what the change adds, not what the clip already does.
5. **Look.** Run the showcase and the plaza hidden for 120 frames and look at what they drew (`AE3D_HIDDEN=1 AE3D_FRAMES=120`, a snapshot, and a camera sweep: one still hides defects). A meter can pass a pose a player would call wrong; the owner's reviews (#1011, #1012, #1013) came from looking.
6. **Then the gate**: every motion suite, chosen from what imports the modules changed (a hand-kept list of 80 missed about 55 of CI's suites, and #1002 went red on three of them), not a list kept by hand.

A number in a commit message or a doc names its test, its commit and its date, as on these pages.
