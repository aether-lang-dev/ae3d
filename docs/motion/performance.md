# Performance

What a figure costs, where that work runs, and how a scene of many figures stays within a frame: the job pool (`ae3d.jobs`), the levels of detail (`ae3d.animlod`, #862), and the numbers. The program is [`examples/docs/lod.ae`](../../examples/docs/lod.ae).

## Budgets per figure

The plan for a scene, from #853's road to the merge (2026-11-09):

| tier | what runs | target |
|---|---|---|
| full figures near the camera | the graph, IK and physical animation every step | 100 to 200 figures under 2 ms, on the job pool |
| graph figures further off | the graph and the feet, one step in 2, 4 or 8, no physical animation | thousands under 4 ms |
| crowd instances | a position, a heading and a phase, posed on the GPU from a pose bank | 100,000 to 1,000,000, the CPU's share near zero (#991) |

A game's own plan was 2 ms for the 100 nearest figures and 2,000 in the crowd. On 2026-11-10 (#862, `bench_animlod`): 100 full figures and 2,000 crowd instances 3.85 ms on one thread and 1.18 ms on a 24-thread job pool.

## Measured on this head

`benchmarks/bench_animlod.ae` on 2026-11-19 at `bea4c991`, with the machine shared with other builds (its numbers are the fastest of its blocks, but a busy machine still reads slower), beside #862's run on a quiet machine on 2026-11-09 and 2026-11-10:

| | this head, shared machine | #862, quiet |
|---|---|---|
| a full figure, graph every step | 113 µs a frame | 27.0 µs |
| the graph one step in 2 / 4 / 8 | 80.6 / 66.5 / 57.0 µs | 17.7 / 13.7 / 11.1 µs |
| a crowd instance's step and sort, one thread | 411 ns | 201 ns |
| 2,000 figures as crowd instances | 0.82 ms | |
| the 100 nearest full figures and 2,000 in the crowd, one thread | 12.1 ms | 3.85 ms |
| the same on the 24-thread job pool | 7.57 ms | 1.18 ms |

A full figure's frame by system on this head (one thread, profiled): the graph 6.6 µs, inertialization 0.03, layers and aims 0.86, the pose to rig space 1.2, the feet (ikrig and their ground rays) 27.7, the look and eyes 4.2, the pose written 6.3, the mover 11.9, steering 9.5, the skinning palette 7.6. The feet are the largest share, as they were on #862 (20.7 of 34.5 µs). The ratio between levels holds on either machine: one step in 8 costs about half a figure every step.

The plan's 2 ms for 100 near figures and 2,000 in the crowd was met on the quiet machine on 2026-11-10 (1.18 ms) and is to be measured again on a quiet machine before the merge (#853's road to the merge, phase D).

## The job pool

`ae3d.jobs` is the engine's one scheduler: aephysics's (Box3D's `scheduler.c` in Aether: threads made once that wait on a semaphore, tasks claimed by compare-and-swap, the calling thread helping while it waits), lent to the physics world too, so the engine has one set of worker threads ([architecture.md](../architecture.md#the-job-pool)). `AE3D_JOBS=n` sets the count; the default is the machine's.

Each step group's animators are evaluated on it (`animator.on_pool`, on by default), as UE5's and Unity's animation runs on worker threads. It is safe because a figure's evaluation reads only its own state and the static world, by rays that only read it (no physics runs inside a group); the pose is written to the joints at the figure's own turn, on the main thread. So the poses are the same to the bit whatever the pool's size, and with no pool. Not on the pool: a paused animator (another writer's), one moved by its root motion (its capsule moves in the physics world as its graph is evaluated), and one between evaluations at a slower rate.

Rays from many threads contend: on 2026-11-10 a ray at 24 threads cost 994 ns against 87 on one, `ground_below` 2,726 ns against 254 (#862). The feet's ground reads were cut from 97 to 53 a figure a frame for that reason.

A pair get-up's planning runs on the pool as a job of its own; on branch `agent/toes` (#835, 2026-11-19) 900 of 1,000 such jobs ran on the pool in `test_jobs_async`, and the snapshot it takes left the main thread (median 1.47 to 0.005 ms).

## Levels of detail

A figure's motion at three levels, the same clip data at each:

1. **The graph every step**, for the figures that matter most.
2. **The graph one step in 2, 4 or 8** (`animator.set_every`), each step drawn between its last two evaluations, for the ones further off. Their spring chains are off and their feet unlocked.
3. **A crowd instance**: a position, a heading and a phase, posed on the GPU from a pose bank baked from the figure's own graph, so a crowd figure is the cheap level of the very motion the full figure plays, not a clip imported a second time.

### The budget

<!-- example: examples/docs/lod.ae#budget -->
```aether
b = animlod.budget_new(e, 0.001)                       // the graphs' share of a step, seconds
i = 0
while i < PEOPLE {
    animlod.budget_add(b, character.animator_of(people[i] as *Character))
    i = i + 1
}
animlod.budget_view(b, core.vec3(0.0 - 2.0, 1.6, 0.0), core.vec3(1.0, 0.0, 0.0), 0.8)   // the eye, its way, its half angle
```

The program then sets the budget to less than its figures need, from what each graph was measured to cost:

<!-- example: examples/docs/lod.ae#tighten -->
```aether
whole = 0.0
i = 0
while i < PEOPLE {
    whole = whole + animator.graph_cost(character.animator_of(people[i] as *Character))   // measured each evaluation
    i = i + 1
}
animlod.budget_set_seconds(b, whole * 0.4)             // 40% of what every graph every step costs
```

As Unreal's animation budget allocator: each figure ranked by its significance (its distance, more off the view), and each given the rate (1, 2, 4 or 8) that keeps a step's graph evaluations within the seconds asked, measured from each figure's own `animator.graph_cost`. A frame that runs two steps spends it twice. `tests/test_animlod.ae` holds sixteen walkers within a budget of 35% of their cost, the nearest every step, each no faster than one nearer: on 2026-11-19 at `bea4c991`, sixteen graphs at 420 µs a frame, the budget of 35% planned at 146 µs, the nearest every step and the farthest every 8.

### The bank

<!-- example: examples/docs/lod.ae#bank -->
```aether
walker = people[0] as *Character
bank = animlod.bake(character.animator_of(walker), character.move_state(walker), 64)   // its move blend as it plays now
```

`animlod.bake` samples a state of the figure's graph (its takes, blended as the graph blends them at the parameter it plays at) into a pose bank of `frames` palettes, the layout `ae3d.crowd`, `gltf_crowd` and the horde draw. `test_animlod`: the bank walks at 1.199 m/s like the graph, 0.036 rad off its pose (#862, 2026-11-09).

### A figure between the crowd and its graph

<!-- example: examples/docs/lod.ae#handover -->
```aether
stood = people[PEOPLE - 1] as *Character
animlod.enter_character(bank, stood, 0.37, core.vec3(0.0, 0.0, WALK), STEP, 0.3)   // from the instance at phase 0.37
k = 0
while k < 60 {
    character.move(stood, core.vec3(0.0, 0.0, WALK), core.vec3(0.0, 0.0, 0.0))
    engine.engine_update(e, STEP)
    k = k + 1
}
phase = animlod.leave(bank, character.animator_of(stood))   // the phase the instance goes on from
```

Handed to the graph (`enter`, `enter_character`), the graph takes over from the bank's two poses about the instance's phase and eases the difference out as a transition does; handed back (`leave`), the pose it draws is matched against the bank's frames for the phase the instance goes on from. On 2026-11-09 (#862, `test_animlod`): the first frame after entering turned a joint 8.2 rad/s against the walk's own 10.56, and a figure handed back matched the bank to 3e-8 rad within a second.

### The crowd's own feet and heading

A crowd instance's bank is baked in place, so its feet move back under its root at exactly the root's travel (#575; `tests/test_crowd_feet.ae`): its speed is the root's travel over exactly the stretch the step plays; a speed limit slows the walk by the same share; a standing instance's walk stops; a clip made in place takes its travel from the foot on the ground. The heading turns toward the way an instance goes at no more than 3.5 rad/s (`TURN_RATE`), so a neighbour's shove turns it over a few frames, not one; walked into an edge, it turns back by no more than the cap a frame (3.34 degrees, as written into the docs at `5f00ce2b`, 2026-10-02).

## Memory

A UE5 mannequin's animation held about 59 MB on 2026-11-09 (#990). Takes are now made once per figure file and skeleton and shared (`animator.share_take`, `character.gaits`, graph files, #944, #992), and compressed within 0.1 mm of the skin ([clips.md](clips.md#compression)). `tests/test_anim_memory.ae` holds what the first figure makes for all and what each holds. `bench_animlod` on 2026-11-19 at `bea4c991`: shared once a file and skeleton, the mannequin file's parse 51.7 MB (its 43 animations and 0.84 MB of meshes) and the gaits' 14 takes 0.55 MB compressed; each figure's own 0.34 MB (its scene of the file 0.18 MB; figure, animator, graph, mover, feet and capsule 0.16 MB); its physical animation 0.27 MB more; 100 figures 85.9 MB on the heap. The file's parse keeps every animation the file has, used or not (#992).

## Limits and known issues

- Crowd instances stepped on the GPU, for a million figures with the CPU's share near zero: #991. On the CPU an instance's step and sort cost 201 ns (#862, 2026-11-09), 200 ms at a million.
- Animation memory, the rest: #992. Shared meshes' bounds and the job pool: #999.
- The plaza on characters: 24 mannequins took the frame from 6.9 to 9.7 to 15.7 ms mean (#980).
