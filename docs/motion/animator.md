# The animator and its graph

`ae3d.animator` owns a figure's joints. One animator a figure evaluates one pose a fixed step and writes it to the joints once; nothing else writes them. A game sets parameters (a speed, a switch, a trigger, a layer's weight, a point to look at) and never touches a bone. The program is [`examples/docs/graph.ae`](../../examples/docs/graph.ae). Issues: #856 (closed), #903, #911.

## What it evaluates, in order

1. **The current state**: a take (looping or not, with or without its root motion), a blend space along one parameter or over the ground's two directions, a motion matcher, or a held pose.
2. **The transition into it**, inertialized: the new state plays from where it enters, under an offset that decays.
3. **Layers** over it: a take blended over a mask of joints, or added as its difference from its first frame.
4. **Aim offsets**: poses aiming at their yaw and pitch, blended at the aim asked and added over a chain.
5. **Breathing and the face**: a standing figure's breath and weight shift; blinks and saccades (#910).
6. **IK** (`ae3d.ikrig`, [ikrig.md](ikrig.md)): feet, the trunk's aim, the whole body, hands, look.
7. **Root motion**, when it is on: the state's travel and turn moved onto the figure's object, or through its capsule.
8. **Secondary motion** (`ae3d.springs`): spring chains and jiggle on what the takes do not drive.
9. **Steps after the graph** (`add_post`), in the order added: what they draw is shown (`show`, `pose_shown`), while the graph goes on from its own pose (`pose_now`). `ae3d.physanim` is one ([physical.md](physical.md)).

It runs at the fixed step (#985), in `engine.FIXED_POSE` after the physics, or in `FIXED_ANIMATION` before it with `set_fixed` (what `physanim.attach` sets, so the bodies chase this step's pose). The frames between two steps draw between the steps' two poses. Every animator of a step group is evaluated on the job pool ([performance.md](performance.md#the-job-pool)).

## A graph, call by call

The Rigify mannequin on its own idle, walk, jog and sprint: a stand, and the three gaits blended by speed.

<!-- example: examples/docs/graph.ae#graph -->
```aether
o = figure.figure(e, "Runner", FIGURE)
a = animator.attach(e, o)                              // the figure's joints are the animator's now
r = animator.rig(a)
idle = animator.add_state(a, "idle", animator.take(a, "Idle_Loop", false), true)
move = animator.add_blend(a, "move")                   // one parameter: the speed
names = ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]
k = 0
while k < 3 {
    t = animator.take(a, names[k], false)              // read once, freed with the animator
    animator.blend_add(a, move, t, clips.speed(t))     // each gait at its own measured speed
    k = k + 1
}
animator.bind(a, move, "speed")                        // the mover writes "speed"
go = animator.add_transition(a, idle, move, 0.35)
animator.transition_when(a, go, "speed", animator.ABOVE, 0.25)
halt = animator.add_transition(a, move, idle, 0.4)
animator.transition_when(a, halt, "speed", animator.BELOW, 0.1)
animator.play(a, idle, 0.0)
```

A mover drives it ([character.md](character.md#the-mover)). The game's side of a mover is stepped in the scripts' group of the fixed step, before the animators read the parameters it writes:

<!-- example: examples/docs/graph.ae#fixed -->
```aether
// The game's side of a mover: what it asks, stepped at the fixed step in
// the scripts' group, before the animators read the parameters it writes.
struct Walker {
    m: *Mover
    asked: Vec3
}

walker_fixed(state: ptr, e: *Engine, dt: float) {
    w = state as *Walker
    mover.ask(w.m, w.asked)
    mover.step(w.m, dt)
}
```

<!-- example: examples/docs/graph.ae#mover -->
```aether
w = heap.new(Walker)
w.m = mover.mover_new(a, o)
b = engine.behaviour_new("walker", w as ptr)
b.fixed_update = walker_fixed
engine.engine_add_behaviour(e, b)
```

Asked 3 m/s, the graph plays `move` at 2.999 m/s; let go, it plays `idle` (`examples/docs/graph.ae`, 2026-11-19, `bea4c991`).

What goes over it, set once:

<!-- example: examples/docs/graph.ae#over -->
```aether
animator.set_feet(a, ikrig.feet_new(r, o))             // feet locked on the floor while the take plants them
animator.breathe_on(a, 1)                              // breath and weight shift while it stands
flinch = animator.add_layer(a, animator.take(a, "Hit_Chest", false), 0 - 1, true, false)   // additive, once
aim = animator.add_aim(a, pose.human(r, pose.SPINE_01))   // an aim offset over the spine
animator.aim_add(a, aim, animator.take(a, "Pistol_Aim_Neutral", false), 0.0, 0.0)
animator.aim_add(a, aim, animator.take(a, "Pistol_Aim_Up", false), 0.0, 0.7)
animator.aim_add(a, aim, animator.take(a, "Pistol_Aim_Down", false), 0.0, 0.0 - 0.7)
```

And driven each frame, by parameters only:

<!-- example: examples/docs/graph.ae#each_frame -->
```aether
animator.layer_weight(a, flinch, 1.0, 0.1)             // a flinch over the run
animator.set_aim(a, aim, 0.0, 0.3, 1.0)                // aimed a little up
animator.look_at(a, core.vec3(3.0, 1.6, 8.0), 1.0)     // the head on a point
```

## A graph from a file

`ae3d.animgraph` reads the same graph from a file, call for call, as Unity's Animator Controller and UE5's state machines are assets rather than code:

<!-- example: examples/docs/graph.ae#file -->
```aether
o = figure.figure(e, "Filed", FIGURE)
a = animator.attach(e, o)
g = animgraph.load(a, GRAPH)                           // the same states, read from a file
animator.set_feet(a, ikrig.feet_new(animator.rig(a), o))
m = mover.mover_new(a, o)                              // writes "speed", which the file's blend reads
```

`tests/fixtures/graphs/gaits.graph`, which the program reads:

```text
take idle Idle_Loop
take walk Walk_Loop
take jog Jog_Fwd_Loop
take sprint Sprint_Loop
state idle idle loop
blend move speed
  walk measured
  jog measured
  sprint measured
end
transition idle move 0.35
  when speed above 0.25
end
transition move idle 0.4
  when speed below 0.1
end
play idle
```

The file's statements: `take` (a take of the figure's file, or `from` another file, retargeted; `root` takes its root motion out), `capture` (a BVH, retargeted, with `straighten` and `cut_loop`), `mirror`, `state`, `blend` and `blend2` (one or two parameters, each take `measured` or at a value), `matcher`, `transition` (`when` a parameter is `above`, `below`, `is`, `is_not`, `triggered`, or `when ended`; `crossfade`, `synced`, `match`), `layer` (`additive`, `loop`, `from` a joint), `aim`, `play`. Joints are named as UE5's mannequin names them or by the rig's own names. The full grammar is the header of `src/ae3d/animgraph/module.ae`. A game finds the parts by name (`animgraph.state_of`, `layer_of`, `aim_of`, `take_of`) and drives them by parameters (`animator.set_float`, `set_bool`, `trigger`). A file's takes are made once for a figure file and its skeleton and shared by every figure loaded on them (#992).

## Blend spaces

- **One parameter** (`add_blend`, `blend_add`): each take at a value, usually its measured speed. The blend picks its weights from the parameter and bends its pace so the feet carry the ground at the speed asked, within 0.5 to 1.75 times each take's own (`PACE_LEAST`, `PACE_MOST`); past that the next gait up should be playing.
- **Two directions** (`add_blend2`, `blend_add2`, bound to `vx`, `vz`): weighted by polar gradient bands, a radian of turn counting as two of the speeds' relative difference (`TURN_WEIGHT`, after Rune Skovbo Johansen, "Automated Semi-Procedural Animation for Character Locomotion", MSc thesis, Aarhus University, 2009, as Unity's freeform directional blend).
- **In step.** A blend's takes share a phase from each take's left footfall (0) to its right (0.5), as Unreal's sync groups keep markers: every left foot comes down together.
- **Orientation warp** (`orient_warp`): the feet turned up to 15 degrees (`ORIENT_MOST`, eased over 0.1 s) onto the velocity where a blend by direction is off its way; UE5's default cap is 90 degrees.

Measured (`test_anim_pipeline`, 2026-11-19, `bea4c991`): the 1D blend's feet carry the ground at the speed asked within 0% from 1 to 8 m/s; the 2D blend at 8 directions and 0.6, 1.0 and 1.3 m/s slides a planted toe 0.49 mm at worst (held to 5 mm), its speed 2e-14% off the speed asked; idle, walk, jog, sprint and back, in step, turned no joint faster than 35.80 rad/s against the takes' own 35.54 (held to the takes' own plus 2%).

## Transitions

`add_transition(a, from, to, seconds)` with conditions (`transition_when`: a parameter `ABOVE`, `BELOW`, `IS`, `IS_NOT` a value, `TRIGGERED`, or the state `ENDED`). `from` may be `animator.ANY`.

- **Inertialized** by default (David Bollo, "Inertialization: High-Performance Animation Transitions in Gears of War", GDC 2018). At a change the new state plays from where it enters; the offset from the pose drawn the frame before, and the speed it was changing at, decay to nothing along a quintic over the transition's time. Only one clip plays, so no foot is dragged between two strides. A joint's offset takes 31 floats: its axis and four quintics (`INERTIA_FLOATS`).
- **Cross-faded** (`transition_crossfade`): halfway through a 0.6 s cross-fade from the idle to the walk, two poses 83 degrees apart, the pose drawn was 42 degrees from one and 43 from the other (`test_anim_pipeline`, 2026-11-19, `bea4c991`).
- **Synced** (`transition_synced`): the next gait taken at the stride's phase.
- **Whichever's feet match** (`transition_or`): of a stop and its mirror, the one whose feet are where the walk's are.
- **Matched** (`transition_match`): entered at the time in the target whose feet best match the pose drawn.
- **Played by distance** (`clock_by`, `clock_from`, `clock_pace`): a start played by the metres come since the figure stood, a stop by the metres left to rest, so its feet plant where the clip planted them whatever the braking. This is distance matching as Epic showed it for Paragon (GDC 2016); the code and the issues name no paper. A start counts from its take's move-off (`clock_from(clips.moving_at(...))`), and the mover holds the start's pace to `set_start_pace` times its own: counted from its first frame and outrun by the springs, 100STYLE's StartStop start raced up to 28 times its pace (#937).
- **Stops that rest** (`transition_rests`, `hold_cadence`): a stop on a gait's loop holds the gait's cadence and weights and plants its last foot in the stand's stance ([character.md](character.md#starts-and-stops)).

## Layers, aims, events, poses held

- `add_layer(a, take, from, additive, loop)`: masked under joint `from` (-1 the whole figure), blended or added; `layer_weight(a, layer, weight, seconds)` eases it. A layer that plays once eases out over its last 0.25 s (`LAYER_OUT`). The chest hit added over the idle turned a joint 8.5 degrees at most, none at its first frame (`test_anim_pipeline`, 2026-11-19, `bea4c991`).
- `add_aim(a, from)`, `aim_add(a, aim, take, yaw, pitch)`, `set_aim(a, aim, yaw, pitch, weight)`: a pistol aimed down, level and up put the right hand at 0.90, 1.40 and 1.80 m; aimed level, the pose is the idle's within 2.4e-6 degrees (same run).
- Events: each footfall (`clips.FOOT_LEFT`, `FOOT_RIGHT`) and a program's own (`clips.add_event`) fire as the clock passes them, a blend's from its heaviest take. A game asks `animator.fired(a, "cue")` after the pose phase: over three cycles of the walk, a cue at 0.25 s fired 3 times (same run).
- `snapshot(a, title)`: the pose drawn now as a state, what a get-up blends out of. A pose held for a second stayed within 1.7e-6 degrees of the pose taken (same run).
- `pause` and `resume`: the figure handed to another writer (a ragdoll, the frozen `ae3d.motion`), the animator reading it back while paused, then taking it back inertialized: from 61.8 degrees off the walk, the fastest joint turned 9.3 rad/s over 0.3 s, against 60.9 rad/s taken at once (same run).

## Breathing and weight shift

`breathe_on(a, seed)` adds a standing figure's breath and shifting weight before the feet, so planted feet stay put and the legs take the sway. The chest pitches back 2 degrees at the top of each breath (`BREATH_PITCH`), about every 4.2 s (`BREATH_SECONDS`), the pace drifting 15% either way over a 23 s cycle; the hips sway 2.5 cm (`WEIGHT_SHIFT`) over 7.3 s (`WEIGHT_SECONDS`), a period that never falls in step with the breath. Both fade with ground speed and are gone at 0.4 m/s (`BREATH_STILL`). These values are the engine's choice; no source is named in the code. `tests/test_idle.ae` holds 30 s of the box man's idle beside a twin without it: 7 breaths of 3.7 to 4.9 s, the hips' sway within 2.5 cm, the breath and the sway correlated 0.009, and a walking figure at 1.0 m/s drawn as its twin within 3e-8 (as written into the docs at `3cf26060`, 2026-10-03).

## Motion matching

A state can be a matcher (`add_matcher`, `matcher_add`, `matcher_build`; in a graph file, `matcher`): every frame of its takes known by its feet's places and velocities, its hips' velocity, and where its root will be and face a third, two thirds and a whole second on (Simon Clavet, "Motion Matching and The Road to Next-Gen Animation", GDC 2016). Every 0.1 s the frame nearest the pose drawn and the way ahead the mover predicts is played, changing only for a clear gain and only to a frame that keeps each planted foot planted. With `mover.set_follow`, the figure goes by its takes' root motion and the mover's springs are a simulation it is eased toward. `character.match_add` builds one from whole captures ([character.md](character.md)).

Through a stand, a walk, a side step, a turn and a stop (`test_anim_pipeline`, 2026-11-19, `bea4c991`): 144 searches, 23 changes, a planted toe's slide 1.22 mm at worst, the fastest joint 14.8 rad/s against the takes' own 17.6. The search over 1,655 frames: 2,000 searches in 1.44 ms against 22.8 ms by brute force, and the same frame as brute force in all 110 checked.

`ae3d.matching` is the older matcher that drives an `ae3d.figure` directly (#586), still used by figures without an animator. Its database, spring (a 0.27 s half-life after Holden) and bounded search are the header of `src/ae3d/matching/module.ae`; `tests/test_matching.ae` holds it on the Fox (2,000 searches over 316 frames in 0.83 ms against 7.8 by brute force, as written into the docs at `72a58615`, 2026-10-03), and its 18-float state, written by a host and read by a client, keeps all 24 bones of two Foxes equal to the bit over 240 frames (`bab87c1e`, 2026-10-03).

## Secondary motion

`animator.springs(a)` (`ae3d.springs`, #989): spring chains and jiggle for hair, a ponytail, a tail, straps, a held lantern, as UE5's AnimDynamics and VRM's spring bones. Each joint aims at a point mass pulled toward where the pose puts it, by semi-implicit Euler with damping and drag taken implicitly (no setting is unstable), held at the joint's length and put out of the chain's colliders. A free chain comes within e^-1 of rest in 2 / (damping + drag) seconds. Run after the IK, on the job pool, the same to the bit run to run and on every platform (core's fdlibm math). At a slower rate (`set_every`) the chains are off, each tail following its pose. A VRM file's own spring bones are read with `springs.from_scene`. `tests/test_springs.ae` holds it.

## The figure's own player, below the animator

A figure with no animator plays clips through `ae3d.figure` itself: the crowd's handed-over figures and the frozen modules use it. Its behaviour, kept here because those users remain until #860 retires them:

- `figure.play_blended(f, clip, rate, loops, seconds)` inertializes a change of clip (Bollo 2018, #574). On the Fox, a cut from Walk to Run jumps a bone 59 units (centimetres) and turns one 89 degrees in a frame; inertialized, the largest step in any frame is 6.7 units and 12.5 degrees, inside the clips' own 8.4 units and 25 degrees (`tests/test_blend.ae`, as written into the docs at `142dcc5d`, 2026-10-02).
- `figure.layer_play(f, clip, bone, weight, additive, loops)`: masked and additive layers; on the Fox, a layer under `b_Spine01_02` poses 10 of its 24 bones and leaves 14 as the walk beneath (`test_blend`, same date).
- `figure.add_clip(f, animation, clip, node)`: a clip made at run time, named `"<animation>:<node>"` as the file's are (#645); `tests/test_runtime_clip.ae` blends one in from Walk and from rest to within 1 mm of its pose (`010eb854`, 2026-10-07).
- Several writers on one node (#673): each takes its own last move off before the next, and `figure.put_back` says whether the figure put a node back this frame. Under a lift that differs each frame, the box man's hips do exactly what they do with no lift, to 1e-4 m; before, they stepped 5.6 cm in a frame (`tests/test_blend_writers.ae`, `0a828d7a`, 2026-10-08). With the animator the question does not arise: it is the one writer.

## State

`animator.state_write(a, out, at)` writes everything the animator carries from one step to the next, so a copy on another peer draws as this one does from there ([networking.md](networking.md#what-a-snapshot-holds)): the poses it drew and eases from (nine of them, including the frame shown and the two steps it is drawn between), every joint's inertialization (31 floats a joint), each state's clock and blend weights, its layers, parameters, fades, lift and warp, and its feet, look, aims and springs whole. Its graph, takes and rig are not in it: each peer builds them the same way. `state_size` gives the floats it needs; for the UE5 mannequin that is a few thousand floats, most of them poses.

## Costs

| | measured | where |
|---|---|---|
| one figure's graph evaluation (states, blends, transitions), UE5 mannequin | 6.3 µs | `benchmarks/bench_animlod.ae` at -O2, #862, 2026-11-09 |
| a whole figure every step: graph, feet, look, mover, pose write | 27.0 µs | the same |
| 2,000 motion matching searches over 1,655 frames | 1.44 ms | `test_anim_pipeline`, 2026-11-19, `bea4c991` |
| a graph's cost as the budget sees it | `animator.graph_cost(a)`, measured each evaluation | [performance.md](performance.md) |

## Limits and known issues

- Legs flicker between steps beyond the takes' own: through the starts and stops a leg flickered 0.20 rad past its takes' own at most, the bound 0.1 held only under `AE3D_FLICKER_ALL=1` (#1012; `test_anim_pipeline`, 2026-11-19, `bea4c991`).
- Starts: a clocked start raced up to 25 times real time before `set_start_pace` (#937).
- Walk and run as separate gaits with a timed change, not mixed by weight (#974); orientation warping for figures that face freely (#971).
- Matching near a looping take's end (#998); turning stops never played (#1029).
- Milestone: #856 (closed); the review of the motion code against Aether's design: #1028.
