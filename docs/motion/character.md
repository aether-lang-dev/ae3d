# The mover and the character

Where a figure goes, and the person built on every layer: `ae3d.mover` (#856) is the controller a game drives with a velocity; `ae3d.character` (#903) puts the figure, its animator, gaits, capsule, mover, feet, eyes and ragdoll together as a person; `ae3d.stance` (#988) adds crouching, crawling and cover. The one-call path is [getting-started.md](getting-started.md); this page is what is under it.

## The mover

A game asks for a velocity over the ground and, optionally, a way to face (strafing). The mover is Daniel Holden's simulation ("Spring-It-On: The Game Developer's Spring-Roll-Call", 2021): its velocity follows the one asked on a critically damped spring with a half-life of 0.27 s (`HALF_LIFE`), its facing on another (`FACING_HALF_LIFE`), and the figure's object goes where the springs take it, through its capsule where it has one. Each step it writes the graph's parameters:

| parameter | what it is |
|---|---|
| `vx`, `vz` | the velocity in the figure's own frame (x to its left, z ahead): a 2D blend's |
| `speed` | the velocity's size: a 1D blend's |
| `moving` | on while it moves or is asked to (above 0.1 m/s, `MOVING`) |
| `turning` | the facing's rate, rad/s, to its left |
| `go` | on while a velocity is asked for (and not into a wall the capsule is against) |
| `travelled` | metres since it last stood still: what a start is played by |
| `rest` | metres to where the springs bring it to rest: what a stop is played by |
| `stop_from` | the speed the stop under way began at: what a stop take is chosen by |

The gait is chosen by the graph from the real velocity, not by the mover. A standing figure asked to go more than 30 degrees off its facing (`START_ARC`) turns where it stands first, its feet stepping it round, then starts: started at once, a forward start played while the figure turned 90 degrees and its feet crossed 110 mm. Turning on the spot, the eyes, head and chest lead by 0.15 s (`TURN_LEAD`) and the body turns no further than its feet let it, as people move the eyes and head first and the pelvis 100 to 200 ms after (Hollands and Patla, as the code cites them). Through a curve past a right angle a walker keeps 0.6 of its speed (`CURVE_SLOW`, #969).

`mover.future(m, t)` and `path` give the springs' way ahead, which motion matching asks for and avoidance reads. `set_follow` turns it round: the figure goes by its takes' root motion, eased toward the springs' simulation over 0.3 s and kept within 0.15 m of it.

## Starts and stops

A start is played by the distance come and a stop by the distance left to rest (distance matching, [animator.md](animator.md#transitions)), so the feet plant where the takes planted them whatever the braking.

- **Starts.** The mover sets off no faster than 1.25 times the start take's own pace where it is (`mover.set_start_pace`, as UE5's distance matching clamps a start's play rate). At 1.0 a figure stood up from an act and asked to walk off to its side went 0.86 m in 2 s; at 1.25, 1.11 m, its fastest joint setting off 95% of the takes' own plus the easing's.
- **Stops.** The mover brakes at the stop take's own deceleration (`clips.braking`), entered from at most 1.25 times the speed the take brakes from (`STOP_SERVES`): faster, the figure slows on its springs through its gaits first (a run to a walk). Of a stop and its mirror the transition takes the one whose feet match. A stop on a gait's loop holds the gait's cadence and plants its last foot in the stand's stance, so the stand takes over with no foot left to step.

A walk's stop ends within one to two steps, as people's do (Jaeger and Vanitchatchavan 1992, J Biomech 25(10); Sparrow and Tirosh 2005, Gait & Posture 22(4); #1024). The library's stops, measured by `tools/measure_stops.ae` (#1024, 2026-11-18): 19 stops, none from a run, braking from 0.63 to 1.66 m/s over 1.0 to 2.95 s and 0.38 to 2.44 m; their peak deceleration over 0.2 s 1.1 to 4.3 m/s^2.

`test_stop_speeds` (the UE5 mannequin on 100STYLE's gaits, let go at each speed; 2026-11-19, `bea4c991`):

| from | at rest in | over | footfalls | peak braking over 0.2 s | a toe's skate | a foot after rest |
|---|---|---|---|---|---|---|
| 1 m/s | 0.78 s | 0.39 m | 2 | 1.27 m/s^2 | 3.01 mm | 2.93 mm |
| 2 m/s | 1.45 s | 1.44 m | 5 | 1.39 m/s^2 | 2.74 mm | 2.98 mm |
| 3 m/s | 1.60 s | 2.40 m | 9 | 1.87 m/s^2 | 0.0001 mm | 2.99 mm |
| 4 m/s | 1.50 s | 2.99 m | 8 | 2.67 m/s^2 | 0.03 mm | 3.01 mm |
| crouch walk, 0.72 m/s, five lengths | 1.12 to 1.95 s | 0.41 to 0.71 m | | | 0.35 to 1.15 mm | 1.76 to 4.12 mm |

The bounds are 5 mm. The braking stays under 4.26 m/s^2, the hardest stop in the library (100STYLE's Neutral_SR, `tools/measure_stops.ae`, #1024). Before #1024 a stop from 3 m/s took 2.07 s, braking at a walk's arrive rate for its last 1.7 s (`test_locomotion`, 2026-11-18, `1cd0d0db`).

## The character

`character.humanoid(e, name, path, gaits, scale)` ([getting-started.md](getting-started.md)), `character.graphed(e, name, path, graph, scale)` (a graph file instead of gaits, its blends driven by the mover's parameters), or `humanoid` with null gaits and a database given by `character.match_add` (motion matching over whole captures, #906, #935). Each part stays the game's to reach: `animator_of`, `mover_of`, `feet_of`, `physanim_of`, `object_of`, `idle_state`, `move_state`.

What it adds over the layers:
- **Every frame**: `move(c, velocity, facing)`, `look(c, point)` / `look_ahead` / `look_free`, `aim(c, target)` / `aim_off` over a file's aims (`aims`), `keep_place` (turns on the spot that keep the hips over their place).
- **Slots** (`use`, `leave`, `using`; `ae3d.usable`, #949): a spot to sit, work or stand guard. The character walks there (running when asked), stops on the point facing the slot's way, and plays the slot's enter, loop and exit takes (`USE_GO`, `USE_TURN`, `USE_ENTER`, `USE_LOOP`, `USE_EXIT`).
- **Acts** (`act`, `act_stop`, `swing`): a take played over everything, a swing of a held item.
- **Loads**: a load in its hands (`ikrig.hands_load`) leans its trunk away and slows it by half the load's share of its mass (`LOAD_SLOW`: 20 kg on a 75 kg person slows its walk by 13%; `laden_pace`).
- **Avoidance** (`set_avoidance`, #956): other characters' paths looked at 4 s ahead in 0.1 s steps (`AVOID_HORIZON`, `AVOID_DT`), 6 cm kept between capsules beyond their radii.
- **Ledges** (`set_ledges`), stances (`ae3d.stance`, below), and the physical calls: `hit`, `shove`, `knock`, `get_up`, `die` ([physical.md](physical.md)).
- **Scale**: made at `scale` of the file's size, its capsule, strides and feet at that size (#943).

What `test_humanoid` holds (the UE5 mannequin on 100STYLE's neutral gaits, 26 checks; 2026-11-19, `bea4c991`):

| | measured | held to |
|---|---|---|
| walking ahead 4 s at 0.8 m/s: its way; a toe's skate | 0 degrees off; 0.008 mm | 10 degrees; 5 mm |
| let go: three seconds on | 0 m/s, on its stand | under 0.05 m/s |
| turned round on the spot | 179.9 degrees in 1 step; a planted ball slid 3.06 mm | one pivot; 5 mm |
| to its left facing ahead (strafing) | 0 degrees off its way; its facing 0.0003 degrees off | 10 degrees |
| told to look 50 degrees aside | its head 0.46 degrees off the point | 3 degrees |
| aiming ahead and up on a file's pistol aims | the right hand 73 cm higher | 25 cm |
| up and down five 0.2 m stairs on its capsule: a sole into them; a planted toe | 0.001 mm; 0.08 mm | 5 mm; 5 mm |
| a 20 degree ramp: a sole into it; a planted toe | 0.001 mm; 4.00 mm | 5 mm; 5 mm |
| setting off from a stand: the fastest joint against the takes' own plus the easing's | 91% at most; no foot past the hips' middle | 100%; never |
| on a database (motion matching), turned on the spot and sat on a stool and back: the fastest joint; a toe | 17.7 rad/s (the takes' own 22.1); 2.74 mm | the takes' own plus the easing's; 5 mm |
| on a graph file at 1.2 to 8.5 m/s: a toe | 2.69 mm at worst | 5 mm |

`tests/test_locomotion.ae` holds the character to what the retired locomotion module was held to (13 checks; 2026-11-19, `bea4c991`): its speed changes at 4.53 m/s^2 at most (6 allowed) and its facing turns at 2.47 rad/s at most (4); let go from a run at 3 m/s it rests in 1.25 s; up a 0.2 m step the pelvis climbs at 1.07 m/s at most (1.2 over the walk's own bob of 0.23); 20 kg at its side leans it 0.2 rad away; laden, it walks at 1.017 m/s, the 1.2 asked less half the load's share of its 65.6 kg.

## Stances and cover

`ae3d.stance` (#988): stand, crouch and prone on a parameter `stance`, the game choosing which, as UE5's crouch and a cover system's take-cover, move, peek and leave read together. Crouch idles and walks come from a file's takes where it has them (Universal Animation Library's `Crouch_Idle_Loop`, `Crouch_Fwd_Loop`), and the ways it lacks are made from the standing gaits by lowering the pelvis with leg IK and leaning the trunk, by as much as the file's crouch is lower and leant than its stand: measured, not guessed. Prone and the crawl are made from the stand. The capsule follows the stance, raised only where there is room. Cover is a wall's face along the ground, its height and the way out; in cover the figure faces out with its back laid on the wall, moves along it, peeks past an end or over low cover and aims. `tests/test_stances.ae` holds it.

## State

`mover.state_write` (22 floats, `STATE_FLOATS`): the springs' velocity, acceleration and facing, what was asked, the distances come and left, the braking under way. `character.state_write` (`STATE_FLOATS`): what it was asked (velocity, facing, look, aim), what it is doing (paused, an act, a get-up and where it was laid, dead) and the way it last steered. Both go into a figure's snapshot ([networking.md](networking.md#what-a-snapshot-holds)).

## Costs

A full figure's frame by system on one thread (`bench_animlod`, #862, 2026-11-09 then 2026-11-10): the mover 2.5 µs, steering 1.35 ms for the people plaza's crowd (from 2.78), the whole figure 34.5 µs on one thread. Today's: [performance.md](performance.md).

## Limits and known issues

- Stops from a run (#1024, open): on this head 1.25 s from 3 m/s in `test_locomotion` and 1.60 s in `test_stop_speeds`, from 2.07 s before; the trailing heel drops 12 mm in a frame four frames after rest at 2 m/s (#1024).
- Limbs on the ground are not held when prone or crawling, so a crawl's stop slides its feet: 20.3 and 34.9 mm at 150 and 160 frames (#1031, moved out of `test_stop_speeds` at `bea4c991`).
- Turning stops are classed but never played (#1029).
- A runner asked to a goal inside its turning circle orbits it (#973); a sharp turn mid-walk crosses the feet up to 169 mm (#969).
- Walk and run as separate gaits with a timed change (#974).
- Stances and cover, what is left (#996). Traversal (jump, vault, mantle, ledges, ladders): #986.
- About 20 behaviour checks have no character-level twin yet (#903).
