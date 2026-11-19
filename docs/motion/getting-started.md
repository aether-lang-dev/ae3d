# Getting a figure moving

From a skinned figure and a handful of motion captures to a person that walks, turns on the spot and stops, its feet planted while they stand. The program is [`examples/docs/first_walk.ae`](../../examples/docs/first_walk.ae); everything below is a region of it.

What you need:
- **A figure**: a glTF file with a skin whose bones are named in any humanoid naming the engine knows (UE5, Rigify, Mixamo, Xsens; [clips.md](clips.md#rigs-and-poses)). The fixture is the Quaternius UE5 mannequin, `tests/fixtures/people/mannequin.glb` (CC0).
- **Takes for its gaits**: motion captures in BVH, named by a prefix: `_fw`, `_bw`, `_sw` (walks ahead, back and to the side), `_fr`, `_br`, `_sr` (the same run), `_start` and `_stop`. The fixtures are cuts of the 100STYLE dataset (Ian Mason, CC BY 4.0) in `tests/fixtures/people/100style`. The figure and the captures need not share a skeleton: they are retargeted ([clips.md](clips.md#retargeting)).

## A world

A character walks on whatever the physics world has under it. Without `physics.attach` it has no capsule and walks on its object's height.

<!-- example: examples/docs/first_walk.ae#world -->
```aether
e = engine.engine_new()
engine.engine_set_fixed_step(e, STEP)
physics.attach(e)
floor = engine.object(e, "Floor", null)
behaviour.object_set_position(floor, core.vec3(0.0, 0.0 - 0.5, 0.0))
physics.box_collider(floor, core.vec3(40.0, 0.5, 40.0), physics.material(0.8, 0.0))
```

## A person in one call

<!-- example: examples/docs/first_walk.ae#person -->
```aether
gaits = character.gaits(CAPTURES)                       // CAPTURES_fw.bvh, _bw, _sw, _fr, _br, _sr, _start, _stop
character.gaits_set(gaits, character.GAIT_STOP, STOP)   // a straighter stop than the style's own
character.gaits_set(gaits, character.GAIT_START, START)
hero = character.humanoid(e, "Hero", FIGURE, gaits)
if hero == null {
    println("first_walk: ${character.error()}")
    exit(1)
}
```

`character.humanoid` builds every layer a person needs and keeps each one reachable (`character.animator_of`, `mover_of`, `feet_of`, `physanim_of`):
- the figure (`ae3d.figure`) and its animator, the one writer of its joints;
- each capture read, retargeted onto the figure with its feet kept on their contacts, its root motion taken out, and straightened onto its axis; the side walk and run mirrored for the other side;
- a graph: a stand, the six gaits as one 2D blend by velocity, a start played by the distance come, a stop and its mirror played by the distance left (distance matching, [character.md](character.md#starts-and-stops));
- a capsule (`physics.character_controller`) where the engine has physics;
- a mover: the velocity and facing the game asks for, followed on springs;
- feet locked on the ground, on the physics' static world, stepping as the body turns on the spot;
- eyes ahead where it goes.

The takes are made once per figure file and shared by every character of the same gaits and file (#944: a camp of 20 settlers had read and retargeted every capture 20 times).

The neutral style's own stop is cut from its idles and slides its planted foot 17 cm, so the program gives the straight stop of the same style's arrival and the StartStop style's start (`gaits_set`). Several stops can be given (`gaits_add_stop`); the one whose hips turn least as it comes to rest is the straight stop.

## Walk, turn, stop

Each frame the game says only what it wants: a velocity over the ground, and a way to face (zero: the way it goes).

<!-- example: examples/docs/first_walk.ae#walk -->
```aether
from = behaviour.object_position(o)
walked = steps(e, hero, m, 240, core.vec3(0.0, 0.0, 1.2), still)    // 4 s ahead (+z) at 1.2 m/s
went = core.v3_len(core.v3_sub(behaviour.object_position(o), from))
```

`steps` calls `character.move(hero, velocity, facing)` and `engine.engine_update(e, STEP)` once a frame. The mover's springs bring the figure up to speed (from standing, through the start take), the graph picks the gaits' weights from the real velocity, and the feet lock where each take plants them.

<!-- example: examples/docs/first_walk.ae#turn -->
```aether
turned = steps(e, hero, m, 180, core.vec3(1.2, 0.0, 0.0), still)    // the same pace to +x: it turns as it goes
```

<!-- example: examples/docs/first_walk.ae#stop -->
```aether
stopped = steps(e, hero, m, 180, still, still)                     // let go: it brakes, steps to a stand and stands
```

Let go, the mover brakes at the stop take's own deceleration, the graph enters the stop when the distance left fits it, and the stand takes over where the stop's feet came down.

<!-- example: examples/docs/first_walk.ae#face -->
```aether
faced = steps(e, hero, m, 120, still, core.vec3(0.0 - 1.0, 0.0, 0.0))   // no velocity, a facing: it turns on the spot
```

A facing with no velocity turns it on the spot: the eyes lead, then the chest, then the hips, and the feet step round in one pivot for up to about 180 degrees (#984).

## What it did

The program prints what `ae3d.metrics` read off the drawn skeleton ([measuring.md](measuring.md)). Run on 2026-11-19 at `bea4c991`:

| | measured | the suites' bound |
|---|---|---|
| walked 4 s at 1.2 m/s asked, from standing | 4.24 m | |
| a planted toe's slide, walking | 1.7e-13 mm | 5 mm |
| the same, turning a quarter as it walks | 9.2e-13 mm | 5 mm |
| let go: standing after 3 s; a planted toe's slide through the stop | yes; 2.92 mm | 5 mm |
| turned round on the spot: a planted toe's slide | 2.79 mm | 5 mm |

The 4.24 m includes the start: the mover sets off no faster than 1.25 times the start take's own pace where it is (`mover.set_start_pace`), as UE5's distance matching clamps a start's play rate.

## Freeing

<!-- example: examples/docs/first_walk.ae#free -->
```aether
metrics.meter_free(m)
character.character_free(hero)
character.gaits_free(gaits)
physics.physics_free(physics.of(e))
figure.figures_free(e)
engine.engine_free(e)
```

A character is freed before the gaits it was made on; `gaits_free` lets go of the shared takes once their last character is freed.

## Next

- To build the same graph by hand, or from a file: [animator.md](animator.md).
- To give it a ragdoll that takes blows: [physical.md](physical.md).
- To play it on every peer of a session: [networking.md](networking.md).
- To change it and know whether the change is better: [measuring.md](measuring.md).
