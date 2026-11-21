# Physical animation

A figure's ragdoll following its animated pose, and how much of what is drawn comes from the bodies: the struck parts given to physics and eased back, a shove stepped out, a fall on the figure's own bodies, a get-up into a clip, a death. The modules are `ae3d.physics` (the ragdoll), `ae3d.physanim` (per-body modes and weights, #858) and the character's calls on them (`ae3d.character`, #859, #861). The program is [`examples/docs/physical.ae`](../../examples/docs/physical.ae).

Three parts of this layer are changing on other branches; each section says what is on this head and where the change is:
- **the physics asset** (bodies, joints, ranges, masses): #858;
- **balance** (a shoved figure correcting with its legs): #1025;
- **pair get-ups** (two figures getting up side by side): #835.

## The ragdoll

`physics.ragdoll_dress(r, skeleton)` builds aephysics's human (`aephysics.human`, Box3D's ragdoll in Aether) as the rig's own figure: every body's joint put at its rig bone's head, each capsule stretched along the rig's line, the feet fitted to the skinned mesh's soles where the skeleton carries it, the rig's bind pose the ragdoll's rest. Each fixed step the rig takes the bodies' turns, parents before children, so the skin stands, falls and lies as the ragdoll does. The construction and its history are [physics.md](../physics.md#ragdolls).

On this head a person is aephysics's twelve bodies (`Hips`, `Spine`, `Chest`, `Neck`, `ShoulderL`, `ElbowL`, `ThighL`, `KneeL` and the right's), and two fitted feet (`FootL`, `FootR`) on a world that gives its ragdolls ankles (`physics.physics_set_ankles`, or `AE3D_ANKLES=1` for every world; #709). Without them the shins end in capsules; ankles become the default once #858 lands. `character.physical(c)` puts them on a character (`physanim.attach` under it); `character.hit` and `knock` put them on at the first blow if not.

### The physics asset: masses and ranges

**Changing in #858.** On branch `agent/asset` (not on this head, opt in with `AE3D_ASSET_BONES=1` there) the asset gains clavicle and twist bodies, masses by segment from de Leva (1996, "Adjustments to Zatsiorsky-Seluyanov's segment inertia parameters", J Biomech 29(9)), and per-body joints; what follows is this head.

- **Mass.** A person's bodies weigh `physics.person_mass(height)`: a body-mass index of 23, the middle of the healthy range, at the figure's standing height. `physanim.set_mass` gives a game's own weight. `tests/test_physanim.ae` holds the bodies to that mass within 1%; dressed in place they had kept the reference human's densities, half a person.
- **Ranges** are `aephysics.human`'s, measured on the fitted shape (forward the way its toes point, up from the pelvis to the neck). The code names no published source for them; asking upstream for sourced values (AAOS 1965; Greene and Heckman 1994) is aephysics#201 and #205, raised from #858 and #1026.

| joint | range on this head (degrees) |
|---|---|
| shoulder | a 120 cone leaning forward, down and out; twist 60 either way |
| hip | flexion 125, extension 25, abduction 45, adduction 30 |
| knee | 0 to 150, twist 10 |
| elbow | 0 to 145, forearm twist 80 either way (aephysics#190) |
| ankle (fitted feet) | plantar 50, dorsal 35, 15 to either side, sole roll 15 |
| wrist | flexion 75, extension 65, deviation 27.5, twist 10 |
| head on neck | flexion 25, extension 35, tilt 20, turn 60 |
| clavicle (aephysics, used by the asset on `agent/asset`) | elevation 40, depression 10, protraction 20, rotation 20 |

The neck's stiffness against published head-neck data, and blows that land in one step, are #1023 (sources gathered there: McGill, Jones, Bennett and Bishop 1994; Fard, Ishihara and Inooka 2004; Siegmund, Sanderson, Myers and Inglis 2003; Portero et al. 2015; Happee et al. 2017).

## Drives: modes and weights

`ae3d.physanim` gives each body two numbers, as Unreal's Physical Animation component (profile strengths, physics blend weights) and PuppetMaster's pin and muscle weights do:

- **A mode**, what moves it: `MODE_KINEMATIC` (exactly where the animation has it; pushes what it meets, is not pushed), `MODE_DRIVEN` (pulled there by its anchor at a strength: hertz, force and torque), or `MODE_SIMULATED` (no anchor). The pelvis is never simulated while the figure stands.
- **A weight**, how it is drawn: 0 exactly as the animation has it, 1 wholly from its body, between that share of the way, eased (`set_weight(pa, bone, weight, seconds)`).

Underneath, `ae3d.physics` gives three drives. `ragdoll_follow(r)` drives each mapped bone's kinematic anchor to where the rig has it, the bodies following through their joints' springs (the pose drive); `ragdoll_release` lets the anchors go. `ragdoll_power(r, torque, assist)` plays the rig through the joints' motors within a torque budget instead. `ragdoll_aim(r, bone, rotation)` drives one bone to a rotation in the world from wherever its parent is, instead of to the rig's pose (`ragdoll_clear_aim`, `ragdoll_clear_aims`): what the protective fall's reach and tuck are made of.

`physanim.attach` begins the hips and legs kinematic and the rest driven, every body at weight 0 (the profile `animated`). The animator is set to evaluate before the physics (`animator.set_fixed`), so the anchors are driven toward this step's pose, and physanim's step after the graph (`animator.add_post`) draws the blend.

<!-- example: examples/docs/physical.ae#bodies -->
```aether
character.physical(hero)                               // its ragdoll on now: every body follows the animation, drawn at weight 0
pa = character.physanim_of(hero)
physanim.profiles_read(pa, PROFILES)                   // named sets of modes, anchor strengths and weights
physanim.apply_profile(pa, physanim.profile_find(pa, "loose_arms"), 0.3)   // eased in over 0.3 s
character.get_up_add(hero, "LayToIdle")                // a get-up take of the figure's file, and its mirror
```

A profile file (`tests/fixtures/physanim/people.profiles`, which the program reads) names sets of bodies' modes, anchor strengths and weights; a line sets one body (`body`) or it and every body below it (`below`):

```text
profile loose_arms
below ShoulderL driven hertz 2 weight 0.6
below ShoulderR driven hertz 2 weight 0.6

profile stiff_arms
below ShoulderL kinematic
below ShoulderR kinematic

profile soft_trunk
below Spine driven hertz 1.5
```

What `tests/test_physanim.ae` holds (the UE5 mannequin walking at 1 m/s beside a twin with no ragdoll; 18 checks on 2026-11-19 at `bea4c991`):
- its bodies weigh a person of its height: 69.7 kg at 1.74 m;
- every body at weight 0: every joint drawn exactly as the twin's (0 apart; held to 1e-6);
- struck in the chest with 40 N s from behind at a walk: the chest drawn 23.7 degrees off the twin's at most and back on it once eased out, the figure 0 mm off the twin's place, its toes not skating;
- easing back, the fastest joint 14.47 rad/s, the walk's own 14.47 plus the easing's 15.76;
- kinematic arms 2.3e-6 mm from where the step's animation puts them (driven at 5 Hz they trail 51 mm);
- struck alike, a firm chest's body 2.3 degrees off its animation and a soft trunk's 11.2.

## Hits

`character.hit(c, bone, point, impulse)` (or `physanim.hit`): a partial ragdoll. The body struck and its chain (up toward the hips and down to its ends) let go of their anchors, pushed, and drawn from their bodies at once, each by its share of the blow: the blow's newton seconds over the struck body's `give`, halved at each link away (`HIT_SPREAD` 0.5), bodies under a share of 0.2 (`HIT_LEAST`) left as they were. A body let go wholly hangs limp; one let go by less is on its own muscle, driven toward the animation at what its share leaves of its `muscle`. The hips are never let go and the chain does not pass them, so a walker struck in the chest, an arm or the head keeps walking on planted feet. After 0.15 s (`HIT_HOLD`) the chain is anchored again where it is and eased back to its weights over 0.6 s (`HIT_RECOVER`), as PuppetMaster's pin weight comes back after a blow. The chain is drawn onto its bodies over 0.1 s (`HIT_IN`): at once, a struck walker's forearm was drawn turning 57 rad/s in the step.

| body | give (N s: lets it go wholly) | muscle (N m) |
|---|---|---|
| spine, chest | 20 | 250 |
| neck | 8 | 40 |
| shoulder (upper arm) | 10 | 80 |
| elbow (forearm) | 6 | 60 |
| thigh | 25 | 300 |
| knee (shin) | 15 | 250 |
| foot | 10 | 120 |

The muscles are `ae3d.motion`'s torque budgets, an adult's peak joint torques rounded (the code names no study); the gives are the engine's choice, tuned so 10 N s on the forearm takes the arm and 40 takes the chest as well. Where the character's graph has a flinch for the part struck (layers `hit_head`, `hit_legs`, `hit_chest`), it is played from its start over the figure, as Unreal pairs a physical blend with an additive hit take.

<!-- example: examples/docs/physical.ae#hit -->
```aether
at = behaviour.object_position(o)
character.hit(hero, "Chest", core.vec3(at.x, at.y + 1.35, at.z - 0.1), core.vec3(0.0, 0.0, 30.0))   // 30 N s from behind
```

## Shoves

`character.shove(c, impulse, at)`: within what catch steps take (the speed the blow gives the whole body, no more than 1.5 m/s, `STAGGER_MOST`), the figure staggers: that speed asked of its mover on top of the game's, easing out over 0.4 s plus 0.4 s a metre a second of it (`STAGGER_BASE`, `STAGGER_PER`), held facing as it faced, so its gaits step it out, each step under where its body is going. The struck bodies sway with 0.35 of the blow (`STAGGER_SWAY`) and ease back, the trunk first and the feet after. Past `STAGGER_MOST` it is knocked down. Put on the mover's springs at once instead, the gaits' blend jumped, a calf turned 53 rad/s and a planted toe slid 7 mm (`test_balance`, #1000).

<!-- example: examples/docs/physical.ae#shove -->
```aether
at = behaviour.object_position(o)
character.shove(hero, core.vec3(60.0, 0.0, 0.0), core.vec3(at.x, at.y + 1.3, at.z))   // 60 N s from its left
```

### Balance

**Changing in #1025.** On this head a standing figure's balance under a shove is the stagger above (the mover stepping it out). The physical balance of a figure on its own bodies, correcting with its legs and ankles instead of rocking on its feet like a bottle, is on branch `agent/sway` (#1025): SIMBICON's torque split (Yin, Loken and van de Panne, "SIMBICON: Simple Biped Locomotion Control", ACM TOG 26(3), 2007), the ankle capped at what the sole holds (the zero moment point; Vukobratovic and Borovac 2004), and steps from the capture point (Pratt, Carff, Drakunov and Goswami, "Capture Point: A Step toward Humanoid Push Recovery", Humanoids 2006; Hof, Gazendam and Sinke, "The condition for dynamic stability", J Biomech 38(1), 2005). Related: #1015, #1016, #1019.

## Knockdowns

`character.knock(c, impulse, at, protect)` (#861): from whatever it was doing to a physical fall on its own bodies, powered as it goes down, its legs on 0.3 of their muscle (`FALL_LEGS`); with `protect`, its hands reach for the ground (0.7 down to 1 along the fall, `REACH_DOWN`) and its head tucks 0.8 rad (`TUCK`), over 0.15 s (`FALL_IN`). These are `ae3d.motion`'s protective fall's values, chosen over thirty falls each way (#479, below). It has landed once its pelvis is within 0.25 m of its lowest point for 10 steps (`GROUNDED`, `LAND_STEPS`), or caught on its hands with its trunk slower than 0.3 m/s for 20 steps; then its muscles ease out over 0.3 s (`KNOCK_EASE`) and it is a ragdoll until it lies still (`character.down`: pelvis and chest slower than 0.1 m/s for 10 steps). Its graph and mover stop where they are (the animator paused, reading the figure back as the bodies draw it) until it is up.

The protective reach is off by default. Over 24 blows (`test_balance`) it brought the head down at 1.44 m/s on average against 1.68 without it and 2.22 for a full ragdoll at once; but over `test_knockdowns`' 100 knockdowns one (seed 26) landed with a hand under its body, and the get-up's hand-over drew a finger 25.8 cm under the floor (#1001).

<!-- example: examples/docs/physical.ae#knock -->
```aether
at = behaviour.object_position(o)
character.knock(hero, core.vec3(0.0, 0.0, 0.0 - 300.0), core.vec3(at.x, at.y + 1.3, at.z), true)   // protected: hands out, head tucked
lay = until_down(e, hero, 8.0)
way = character.get_up(hero, null as *Motion, 0.4)     // chosen by how it lies, laid onto the body, played from the pose drawn
rose = until_up(e, hero, 8.0)
```

## Get-ups

`character.get_up_add(c, title)` makes a take of the figure's file one of its get-ups (up to 8), its root motion taken from its pelvis (`clips.root_under_pelvis`) so the capsule stays under the body, and its mirror too. `character.get_up(c, motion, blend)` (#859):
1. puts its object, capsule and mover upright on the ground under the pelvis;
2. chooses among them by how the body lies (face up, face down or on a side, then the nearest pose), each laid onto the body and turned about the pelvis, scored by how far its way up goes into what lies or stands near it;
3. lays the chosen take's first frame onto the body, so its pelvis and spine lie where the body's do, rooted as the get-up roots it;
4. reads the pose drawn back as the animator's last two frames, takes the bodies back (`physanim.retake`), and plays the take as an act from the pose drawn, inertialized over `blend` (longer where the drawn pelvis would go faster than the get-up's own), its root motion moving the capsule; at its end the stand takes over;
5. waits, lying, while every way up would cross another figure's way up or something that moves stands where it would rise (`room_to_rise`: a car stopped over it), looking again every `WAIT_LOOK` seconds.

Done by hand in another order, the drawn pelvis jumped 1.3 m.

`examples/docs/physical.ae` on 2026-11-19 at `bea4c991`: shoved with 60 N s it staggered and stayed up; knocked down with 300 N s it lay still 1.8 s on, got up by `LayToIdle` and was on its stand 1.68 s after `get_up`; dead, its ragdoll was at rest 4 s on.

Got up under the plaza's car before step 4, its capsule was pushed out 0.85 to 1.3 m in a step and threw the car off at 45 m/s (#982).

`tests/test_knockdowns.ae` knocks the mannequin down over 100 seeds and holds each get-up to the clip's own: up within 0.5 s of coming to rest, no joint past the clip's own fastest, no falling again, the capsule under the pelvis. Measured on 2026-11-06 (#859): up within 0.217 s of rest at worst (0.185 mean), 0 of 100 falling again; the capsule within 0.08 mm of the pelvis on 2026-11-09 (#859, commit `19a0c6da` on a branch since landed).

### Two figures getting up together

**Changing in #835.** On this head, two figures lying against each other get up one after the other: each way up is planned against what is near it, the clearer goes first, and the other waits while its way would cross the first's (`character.get_up`'s wait). `tests/test_get_up_pair.ae` on 2026-11-19 at `bea4c991`, gaps of 0.1 and 0.2 m, turned 0, a quarter and a half, told in either order: 0 s drawn inside each other in every layout (from 0.55 s and 7.3 cm before #835), up after 1.7 to 3.45 s (the get-up itself 1.53 s), the second waiting up to 1.77 s; planning 4.7 to 41 ms a figure on a shared machine. Taking the snapshot off the main thread, the riser pushing the lying ragdoll aside, and a time bound judged against each layout's physical minimum are on branch `agent/toes`.

## Deaths

`character.die(c, impulse, at, fall)`: the figure a ragdoll for good, as UE5's death ragdoll and PuppetMaster's dead state make it. Every body let go from the pose drawn and moving as the animation moved it (each body's velocity from its last two poses), its muscles holding that pose and easing out over `fall` seconds (0.3, `DEATH_FALL`) rather than dropping as a puppet whose strings are cut; then the blow. Its graph and mover stop; `get_up`, `act` and `resume` refuse it. Its capsule stays but no longer blocks others unless asked.

<!-- example: examples/docs/physical.ae#die -->
```aether
at = behaviour.object_position(o)
character.die(hero, core.vec3(0.0, 0.0, 0.0 - 50.0), core.vec3(at.x, at.y + 1.3, at.z))   // a ragdoll for good
```

`tests/test_deaths.ae` holds it.

## Injuries and joint failure

**Changing in #1026.** On this head a joint's limit is a constraint and nothing breaks. #1026 models breaking points and joint failure reported to the game; upstream, aephysics PR #208 fixed the twist reading that made a joint's angle jump between +2.5 and -2.6 rad on consecutive steps (the worst excursion over 16 throws 1.80 to 0.57 rad, 2026-11-19), and aephysics#204 tracks ankles 0.8 to 1.0 rad past their cone for 1 to 3 steps at landing.

## State

`physanim.state_write(pa, out, at)` writes each body's mode, weight and its easing (from, goal, time), its hit's share and hold, its give and muscle, and the figure's hit, limp and fall state. A character's snapshot puts it beside every body of its ragdoll and the ragdoll as its solver holds it (`physics.ragdoll_state_save`: its anchors, its joints' warm starts, its contacts with their caches), so a late joiner lays a fallen figure exactly ([networking.md](networking.md#what-a-snapshot-holds)).

## Costs

| | measured | where |
|---|---|---|
| eight people walking, a step with their ragdolls against without | 0.822 against 0.295 ms: 0.066 ms a figure (bound 0.5) | `test_physanim`, 2026-11-19, `bea4c991`, shared machine |
| a figure's physical animation, memory | 0.27 MB | `bench_animlod`, the same run |
| eight walkers a step with the asset off / on / on with twist bodies | 1.021 / 1.195 / 1.167 ms | #858 on `agent/asset`, 2026-11-18 (not this head) |
| a pair get-up's plan for one way | 3.7 ms; about 9 ways a look | #835, 2026-11-19, `agent/toes` |

## The frozen active ragdoll: `ae3d.motion`

`ae3d.motion` (#414) was the engine's first active ragdoll, written before the pipeline: a figure whose animation is played by joint motors within a torque budget, with balance, a protective fall, staggering, writhing, keyed get-ups, sitting, kneeling and eating. It is frozen (#854): only bug fixes go in, and #860 moves its users (the plaza, the motion showcase, the horde's hand-over) onto the layers above. The character's knockdown no longer uses it (`character.knock` carries no `ae3d.motion` state, #997). Its behaviours are the reference the new layer was tuned against, so the measurements are kept here, each with the test that holds it and the commit that wrote it into the docs. The full account of how each was reached, as it stood before this merge, is [docs/motion.md at `bea4c991`](https://github.com/aether-lang-dev/ae3d/blob/bea4c991/docs/motion.md).

**Modes.** `ANIMATED` (the animation drives, the bodies follow through anchors), `POWERED` (muscles: each joint's motor drives toward the animated pose within a budget, the pelvis held upright by an anchor capped at 1,200 N m), `LIMP`, and the got-to modes `GETTING_UP` and `ACTING`. Usage: `tests/test_motion_figure.ae` (`motion.on_figure`, `set_mode`, `set_get_up`).

**Torque budgets** (N m; an adult's peak joint torques, rounded; `18b6fd80`, 2026-09-24): hips 300, knees 250, lower back and chest 250, shoulders 80, elbows 60, neck 40. A motor asks for the velocity that closes the gap to the pose in 50 ms, capped at 20 rad/s. The pelvis anchor's 1,200 N m was measured: at 600 a figure could not hold itself up on its capsule feet; at 2,500 not even a 400 N s blow felled it.

**The protective fall** (#479; `test_falls`, thirty falls each way, a protected figure beside an unprotected twin; `ea733e38`, 2026-10-02):

| way | protected head slower | head, protected / twin (average) | a second head impact | still within 3 s of landing |
|---|---|---|---|---|
| over backwards | 30 of 30 | 0.10 / 3.63 m/s | 0 | 30 |
| forwards | 30 of 30 | 0.84 / 3.20 m/s | 0 | 30 |
| sideways | 30 of 30 | 0.18 / 3.29 m/s | 0 | 30 |

**Stepping and staggering** (`test_balance`, `test_stagger`; `908be0f5`, 2026-10-01): a foot swings under the capture point (the centre of mass carried on by its velocity times sqrt(height / g)) once it leaves the feet by 24 cm and the figure moves at 0.25 m/s or more. From behind, standing still gives out at 255 N s, stepping stands to 360 and falls from 390; from the side, 180 standing and 210 stepping.

**Writhing** (`test_writhe`; `3c6ab111`, 2026-09-28): down and hurt, the legs draw up and let down every 1.7 s and the arms fold toward the wound; the left hip swings 0.30 rad on its back and 0.43 on its face, the pelvis drifting 1.0 to 1.3 cm.

**At rest** (`test_motion_rest`; `b2314f9d`, 2026-10-03): at 4 sub-steps a step a powered figure trembled (every body 0.56 rad/s on average); a world holding a powered figure steps in 8, and it stands at 0.0035 rad/s.

**Cost** (`test_motion_cost`; `b2314f9d`, 2026-10-03): 4 figures 59 µs each, 16 figures 37 µs, 32 figures 34 µs a fixed step.

**Keyed ways** (#825): get-ups, sitting, lying, kneeling and eating are keyed on their contacts with the feet pinned, held by `test_get_up` (`530e81a1`, 2026-09-24: no drawn bone turns more than 4.6 degrees a step), `test_sit` and `test_lie` (`f432557a`, 2026-10-19: up from lying in 3.6 s), `test_kneel` (`056a8020`, 2026-10-21: comes to kneel in 2.95 s), `test_eat` (`6e9f264c`, 2026-10-20: each palm 0.05 cm off its grip). The pipeline's equivalents are usable slots with enter and exit takes (`character.use`, #949) and get-up takes (`character.get_up`).

**Body parts** (#573): a part's own mode and strength (`set_part_mode`, `set_part_strength`), a `POWERED` part on an `ANIMATED` figure (#658; `test_part_powered`, `010eb854`, 2026-10-07: jabbed 20 N s in the face, the head drawn back 3.3 cm with the pelvis on its clip). In the pipeline this is a physanim profile.

**The horde's hand-over** (`ae3d.handover`, frozen): a pool of a dozen figures the struck zombies of a pose-bank horde are handed to and taken back from (`test_handover`, `f11232df`, 2026-09-24: 0.007 mm at the hand-over, every bone; four struck at 400 N s back in the horde 7.3 s after the blow). On the network it is `ae3d.nethandover` ([networking.md](networking.md)). Its successor in the pipeline is `ae3d.animlod`'s hand-over by pose snapshot ([performance.md](performance.md#a-figure-between-the-crowd-and-its-graph)).

## Limits and known issues

- Anchored arm bodies trail the animated pose 24 to 48 mm at a walk (#936).
- Drawn feet off the pose after a hit on a walker, the toe skating (#1000).
- A hard shove spins a `POWERED` figure into a somersault (#1016); a `POWERED` figure walking in place falls (#968); one standing on a walk is turned 174 degrees by its own legs (#938).
- A dying walker's forearm pressed 29.5 mm into the floor by soft contacts (#993).
- An arm the protective reach leaves overhead is swept through the floor at a get-up's hand-over (#1001).
- Joint drives stiffer than published human data (#1023).
- Milestones: #858, #859, #861.
