# Motion

How a figure in ae3d moves: from a rig and its takes to a person that walks, turns, stops, is struck, falls, gets up, and is seen the same way on every peer of a game. This folder is the whole of it, for two readers: the engine user who has to build a character with it, and the engineer who has to change it. The epic is #853.

Every number on these pages is dated and names the test or commit it came from. Unless a line says otherwise, a number was measured on 2026-11-19 at commit `bea4c991` of PR #939 (branch `feat/motion-next`), on Windows 11 on an Intel Core i7-13700K (24 hardware threads) with Aether 0.925, by the test it names. Every code block is a region of a program under [`examples/docs/`](../../examples/docs), which `ci.sh` builds and runs; `scripts/check_doc_examples.sh` fails the build when a block and its program differ.

## The pages

| Page | What it answers |
|---|---|
| [Getting a figure moving](getting-started.md) | From a rig and takes to a person that walks, turns and stops, in the fewest calls |
| [Clips and retargeting](clips.md) | Rigs, poses, takes, motion capture, retargeting, root motion, contacts, compression (`ae3d.pose`, `ae3d.bvh`, `ae3d.clips`, `ae3d.retarget`) |
| [The animator and its graph](animator.md) | The one writer of a figure's joints: states, blend spaces, transitions, layers, aim offsets, motion matching, graph files, secondary motion (`ae3d.animator`, `ae3d.animgraph`, `ae3d.springs`, `ae3d.matching`) |
| [IK: ikrig](ikrig.md) | Feet on any ground, stepping on the spot, limbs, chains, the whole body, aim, look, hands (`ae3d.ikrig`) |
| [The mover and the character](character.md) | The controller a game drives with a velocity, and the person built on it: starts, stops, turns, stances, slots (`ae3d.mover`, `ae3d.character`, `ae3d.stance`) |
| [Physical animation](physical.md) | The ragdoll, the physics asset, drives and profiles, hits, shoves, knockdowns, get-ups, pairs, deaths, injuries (`ae3d.physics`, `ae3d.physanim`, and the frozen `ae3d.motion`) |
| [Networking motion](networking.md) | Inputs instead of poses, snapshots, late joins, determinism (`ae3d.netanim`, `ae3d.nethandover`) |
| [Performance](performance.md) | Budgets per figure, the job pool, the LOD tiers, measured costs (`ae3d.jobs`, `ae3d.animlod`) |
| [Measuring motion](measuring.md) | The metrics, the suites, the probes, and how to judge a change (`ae3d.metrics`) |
| [Engine and game](engine-and-game.md) | What the engine decides and what the game decides |

## The layers

Each layer owns one thing and hands the next a pose or a parameter. No layer writes another's state; a game sets parameters and never writes a bone.

| Layer | Modules | Owns |
|---|---|---|
| Rigs and poses | `ae3d.pose`, `ae3d.bvh` | A rig: joint names, parents, parents-first order, rest pose, and a map onto one humanoid layout (the UE5 mannequin's 53 slots). A pose: ten floats a joint, flat. |
| Clips and retargeting | `ae3d.clips`, `ae3d.retarget` | Takes resampled for a rig, and what a take knows about itself from import: root motion, foot contacts, speed, heading, footfalls, events. A take made on one humanoid carried onto another, feet kept on their contacts. |
| The animator and its graph | `ae3d.animator`, `ae3d.animgraph`, `ae3d.springs`, `ae3d.face` | The figure's joints. One pose a step from states, blends, inertialized transitions, layers, aim offsets and a matcher; written once. |
| IK | `ae3d.ikrig` | The last word on that pose before it is drawn: feet, aim, the whole body, hands, look, in that order. |
| The mover and the character | `ae3d.mover`, `ae3d.character`, `ae3d.stance` | Where the figure goes: a velocity and a facing on springs, a capsule, and the graph's parameters. The character puts every layer together as a person. |
| Physics and physical animation | `ae3d.physics`, `ae3d.physanim` | The ragdoll's bodies and joints, and how much of the drawn pose comes from them: per body, a mode (kinematic, driven, simulated) and a weight. |
| Networking | `ae3d.netanim` | What crosses the wire for a figure: its inputs a tick, its events, a compact state to find drift, and a whole snapshot for a late joiner. |
| Jobs and LOD | `ae3d.jobs`, `ae3d.animlod` | Where the work runs (the engine's one job pool) and how often: every step, one step in 2, 4 or 8, or a crowd instance posed on the GPU. |

## A frame, through the layers

The engine's loop is [architecture.md](../architecture.md#a-frame). Animation runs in the fixed step, not the frame (#985): a figure's clocks, transitions, feet and capsule all move in the step's time, and the frames between two steps draw between their two poses. Each fixed step runs four groups in order (`engine.FIXED_SCRIPTS`, `FIXED_ANIMATION`, `FIXED_PHYSICS`, `FIXED_POSE`):

```
input (a peer: netanim.play puts the owner's inputs for this tick on its figures)
  |
  v
FIXED_SCRIPTS      the game's fixed_update: character.move / mover.ask
                   the character's step: the mover's springs, the capsule moved,
                   the graph's parameters written (vx, vz, speed, go, travelled, rest, ...)
  |
FIXED_ANIMATION    animators set_fixed (every figure with a ragdoll, physanim.attach), on the job pool:
                   graph -> layers -> aim offsets -> ikrig -> springs = this step's pose,
                   which the ragdoll's anchors are driven toward
  |
FIXED_PHYSICS      the physics world steps: bodies follow their anchors or fall
  |
FIXED_POSE         every other animator, on the job pool: the same evaluation,
                   its feet tracing the world the step just left
  |
  v
pose phase (once a frame)
                   steps after the graph (animator.add_post): physanim draws each body
                   between the animated pose and its body by its weight (pose_shown);
                   the joints written once, between the last two steps' poses
  |
  v
draw; then netanim.sent closes the tick and streams its inputs
```

Why this order:
- **The bodies chase this step's pose, not the last one.** With the physics first, a held forearm's bodies trailed the drawn hand 4.9 cm mid-bite (#845, measured by `test_eat` when the groups were introduced).
- **The graph advances by steps.** Posed once a frame with the frame's length while the capsule moved at the step, a figure on a display whose frame rate varied had its toes skate up to 43 mm, against 3 mm on a fixed tick (#985, `people_plaza`). `tests/test_frame_rates.ae` now holds every rate within 0.5 mm of the tick: at commit `e051a089` (2026-11-19, on this head) the tick and 1/30, 1/45 and 1/60 s all skated 3.10 mm, 1/144 s 3.12 mm, a seeded mix 2.99 mm.
- **One writer.** Before the pipeline, seven modules wrote the same bones and found each other by comparing floats; a walker standing in its idle had its hips 28 cm up and its legs folded under it (the plaza, #673). The animator is now the only writer of a figure's joints; `ae3d.physanim` draws through the animator (`add_post`, `show`), not around it.

## What is old, and what is changing

- **Retired** (#860): `ae3d.idle`, `ae3d.lookat`, the feet module and the locomotion module. `ci.sh`'s "retired motion modules stay retired" step fails on an import of one. Their behaviour lives in the layers above: breathing in the animator, the look and the feet in ikrig, a player's figure in `ae3d.character`.
- **Frozen** (#854, retired by #860): `ae3d.motion` (the first active ragdoll), `ae3d.posing`, `ae3d.anim` and `ae3d.handover`. Only bug fixes go into them; a capability they have that the pipeline lacks is built in the pipeline. They are documented in [physical.md](physical.md#the-frozen-active-ragdoll-ae3dmotion) while users remain.
- **Changing on other branches**, documented here as they are on this head with a note where they appear: the physics asset (#858), balance (#1025) and pair get-ups (#835).

## Where the older pages went

`docs/animation.md`, `docs/animation-pipeline.md` and `docs/motion.md` were merged into these pages (#1027); each is now a short pointer for links that land on it. The motion parts of [physics.md](../physics.md) (the active ragdoll's drive, aims and hand-over) are in [physical.md](physical.md); physics.md keeps the ragdoll's construction and points here.
