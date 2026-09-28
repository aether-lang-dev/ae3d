# Natural motion

`ae3d.motion` is an active ragdoll (#414): a figure whose animation is played by its muscles rather than pasted onto its bones. It's what GTA IV and V get from NaturalMotion's Euphoria. Hit it, and it gives where it was hit and comes back; hit it harder than it can take, and it falls. It's an option on the engine's own motion system, a component on any ragdoll that wears a skinned figure (`physics.ragdoll_dress`), and off unless asked for.

It has muscles, balance, reactions to hits, a protective fall, steps and staggers that catch it, writhing on the ground, and getting up again.

## A figure

```aether
import ae3d.motion

r = physics.ragdoll(e, "Zombie", position, 8.0, 8.0, 1.0)
physics.ragdoll_dress(r, rig)                       // the skinned figure it wears
body = motion.active_ragdoll(r)                     // ANIMATED to begin with
motion.attach(e, body)                              // its recovery stepped every fixed step
motion.set_mode(body, motion.POWERED)               // the muscles play the animation
motion.hit(body, human.BONE_SPINE_03, point, impulse)
```

| Mode | What drives the figure |
|---|---|
| `ANIMATED` | The animation, position and all. The bodies follow it through strong anchors and collide as they go, so what they strike is pushed aside and the figure isn't. |
| `POWERED` | Muscles. Every joint's motor drives it toward the pose the animation gives it, within a torque budget. Nothing holds the figure up but its own feet and a balance the pelvis keeps within a budget of its own. The figure is drawn as its bodies are. |
| `LIMP` | A ragdoll. The animation follows the bodies. |
| `GETTING_UP` | Not set but got to: `get_up(body)` from the ground. A way up keyed on the rig, the bodies following it as an `ANIMATED` figure's do. |

**Two poses.** A powered figure has two poses: the animation's, which its muscles track, and its bodies', which is what gets drawn. The rig is where an animation writes a pose and where the skin is drawn from, so the physics module keeps the animation's pose beside it. Before each step it takes whatever the animation has written to the rig since the bodies last did, bone by bone, and drives the joints toward that. After the step it writes the bodies' pose into the rig for drawing. A clip that moves one bone leaves the rest of the pose where the animation last put them, not where the bodies fell. Until this, a powered figure was drawn in its animation's pose whatever its bodies did: knocked down, it was drawn standing.

## Muscles

A joint's muscle is its motor. Each fixed step the motor is asked for the relative angular velocity that would close the gap between the joint's pose and the animation's in 50 ms, capped at 20 rad/s. It may use no more torque than its budget:

| Joints | Budget (N·m) |
|---|---|
| hips, knees | 300, 250 |
| lower back, chest | 250 |
| shoulders, elbows | 80, 60 |
| neck | 40 |

These are an adult's peak joint torques, round. A motor is a hard constraint within its budget, so the figure carries its own weight on its knees and gives only when what pushes it is more than they have.

The first version drove joint springs instead. A spring's stiffness is relative to the two bones' own small inertia, so at any stiffness the figure sagged to the ground.

**Balance.** The pelvis alone is held upright from outside, by an anchor capped at 1,200 N·m. This is the balance a standing figure keeps, and what a blow past it overcomes. It holds the figure upright but lets it turn about the vertical. The value was measured: at 600 N·m the figure couldn't hold itself up on its capsule feet, and at 2,500 N·m not even a 400 N·s blow felled it. The balance controller that steps to catch a fall replaces this in a later slice.

**Strength and hits.** `set_strength(body, s)` scales every budget (0 is limp, 1 full strength). `hit(body, bone, point, impulse)` applies the blow and takes 95% of the struck bone's budget and half of its neighbours'. It comes back over `set_recovery` seconds (0.8 by default), so a shoulder shot drops the arm and the arm comes back up.

## The protective fall

A `POWERED` figure that leans more than 0.35 rad (20°) from its pose is falling (`falling(body)`), and it protects itself, as a person does (`set_protective(body, false)` turns this off):

- it stops fighting for a balance that is lost: the pelvis's assist goes to 0;
- its arms reach toward where it is falling, 0.5 down to 1 along the fall and as far out to each side, so the hands land wide of the chest rather than under it, and as straight as the elbow lets them, since a straight arm takes the landing through its joints where a bent one folds on its elbow's muscle;
- its trunk curls away from the fall, 0.5 rad at each joint of the spine, and its head tucks 0.5 rad: the rounded back and tucked chin of a breakfall, which keep the head off the ground as the trunk lands.

Every one of these is built from the limb's rest place under its parent, as the parent is now, and kept 0.05 rad inside its joint's limits: a shoulder's 45° cone, a hip's 30°, the spine's 35°, the neck's 30°, and an elbow's or knee's hinge. A target past a limit only saturates the motor, and its torque, against the limit, turns the whole body instead of the limb.

If it catches itself (leans less than half the threshold again), the reach and the curl let go and the balance comes back. Once it has landed, meaning it leans past 1.2 rad (69°) and its centre of mass comes down slower than 0.3 m/s, the reach and the curl let go, their work done; renewed on the ground, they pushed the figure along it and rolled it. Once it holds still there for ten steps, it lies (`lying(body)`): the muscles keep 15% of their budget, so it lies instead of holding a pose on the ground.

**In the street.** `street_drive`'s bystanders are active ragdolls. The ones that stand hold themselves up on their muscles, and the walkers walk by their animation until struck. The car's blow is about 60 N·s per m/s it was closing at, along its heading. Past 4 m/s it lands on the pelvis, which takes the balance with it, and the figure goes down reaching for the road. Below that it lands on the spine, and the figure is knocked back and recovers. On the autopilot's run the three bystanders in the road are struck at 7 to 10 m/s and all three go down. Before this they went limp the moment they were touched.

The reach and the curl are **aims** (`physics.ragdoll_aim(ragdoll, bone, rotation)`): a bone's joint drives it to a rotation in the world, from wherever its parent is, instead of to the animation's pose. The bones below it keep the animation's pose relative to it. Any controller can aim a bone this way, for example to turn a head toward a threat. `ragdoll_clear_aim` and `ragdoll_clear_aims` hand the bones back to the animation. A limb's direction is its capsule's (`physics.ragdoll_bone_axis`): the reference ragdoll's limbs are mirrored, the left thigh and calf along their bodies' -x and the right along +x, the arms the other way about.

**Which way it falls** is where its pelvis's up leans to: the world's up, turned as the pelvis is turned from the reference's pose. It is not the pelvis body's +y. The reference ragdoll's trunk bodies are made upside down (half a turn about x), so their +y points at the ground, and until this the arms reached away from the fall and the head tucked into it.

The settings were chosen by measurement: thirty falls each way (blows of 376 to 424 N·s to the chest, a step or two apart in time), each against a twin that does not protect itself, measuring the head's speed as it met the ground. The one chosen did better in all three directions, and so did its neighbours:

| | from behind (forwards) | from the front (over backwards) | from the side |
|---|---|---|---|
| protected, the head's speed, mean | 1.18 m/s | 0.33 m/s | 0.61 m/s |
| its unprotected twin | 3.46 m/s | 2.41 m/s | 1.68 m/s |
| protected slower, of 30 | 30 | 30 | 23 |
| the hands down before the head, of 30 | 30 | 30 | 30 |
| lying still within three seconds of the blow, of 30 | 27 | 30 | 24 |

From the side, the seven not slower met the ground with the head one to one and a half seconds after they landed, rolling over on the ground, not in the fall; in most of the others the head never touches it. Before the fall's way and the limbs' axes were set right, the protection did no better than the twin on average, in any direction. Softening the legs in a fall, tried, left the figure crumpled on its knees rather than lying.

## Stepping to catch itself

Pushed, a `POWERED` figure steps to catch itself (`set_stepping`, on by
default; `steps_taken` counts them). Every fixed step it watches its
capture point: the centre of mass carried on by its velocity times
√(height / g), where it would come to rest over a foot. When that point
leaves the ground the two feet cover (heel under the ankle, toe 0.2 m
ahead) by more than 24 cm, as far as the balance the pelvis keeps brings
back without a step, and the figure is moving over the ground at 0.25 m/s
or more, a foot swings to put itself under it. The thigh reaches toward
the spot, within the hip's cone, with the knee bent 0.5 rad for the first
0.12 s so the foot clears the ground, then the leg straightens onto it;
the whole step takes 0.3 s. It lands 5 cm past the capture point, and at
most half a metre from under the hip.

Which foot moves:
- **Pushed forward:** the foot further behind swings through.
- **Pushed sideways:** the foot on that side steps out. Swinging the other
  across it only tangled the legs.
- **Pushed back:** it doesn't step. The reference ragdoll's hips hardly
  extend (their cone sits forward of the leg), so a step back was too short
  to catch anything and took a foot from under a figure its balance would
  have held.
- **A push past a stride and a half:** that's a fall, and the protective
  fall has it. A leg swinging as the figure goes over only took the fall
  from the arms.

The feet are where the calves' own capsules end. A calf body carries its
foot as a second capsule, and the first a body lists is the last it was
given: taken for the calf, the foot put the ankle at the toe, 13 cm too
far forward, and aimed the shin along the foot, 50° off. The margin was
8 cm while the feet were measured from the toes.

`tests/test_balance.ae` pushes figures at the chest, each push with and
without stepping:

| push | without stepping | stepping |
|---|---|---|
| 60 N·s from behind | stands | stands, no step |
| 270 N·s from behind | falls | stands, 2 steps |
| 180 N·s from the side | stands | stands, 1 step |
| 150 N·s from in front | stands | stands, no step |

Over thirty runs of each push (the push 5% and 10% either way, a step or
two later), the nudge is held without a step, the push from behind caught
and the push from the side stepped out from every time, and the push onto
the heels held without a step in 29; the thirtieth, 165 N·s, is past
what the pelvis holds backwards, and falls either way.

How far each way holds:
- **Forward:** 240 N·s without stepping, 340 N·s staggering.
- **Sideways:** 210 N·s either way; stepping moves the feet rather than
  holding the pose.
- **Backward:** 150 N·s either way.

## Staggering

A shove one step does not catch, the figure staggers from
(`staggering(body)`): once a step has been taken and the capture point is
still off the feet, the steps come in a run, each to where the capture
point is by then, quicker than the first (0.22 s each, 0.03 s apart), for
as long as the capture point is within three strides. While it staggers,
the protective fall waits until the figure leans past 0.8 rad (46°) rather
than 0.35: a figure still catching itself is not yet falling. It ends
standing, or falls into the protective fall.

`tests/test_stagger.ae` shoves figures from behind, each with and without
stepping, and runs the whole twice:

| shove | without stepping | stepping |
|---|---|---|
| 330 N·s | falls | staggers 3 steps (0.03, 0.37 and 0.63 s after the shove) and stands |
| 360 N·s | falls | staggers 2 steps (0.17 and 0.5 s), then falls into the protective fall |

It holds two or more steps for the 330 N·s shove, none more than 0.4 s
after the last, the stagger over once it stands, and the same steps at the
same fixed steps, and the same end to the bit, on the second run. Across
330 N·s shoves a step or four apart in time, it staggers two to four steps
and stands every time; from 290 to 340 N·s, thirty runs, it stands in
every one, where stepping without the stagger's quicker steps two of them
fell. At 350 N·s it stands in three of five, and from 360 it falls.

## Writhing

Down and hurt, a `POWERED` figure writhes (`set_writhing(body, seconds)`,
off by default; `writhing(body)` says it is): for the seconds it is given
after it lands, then it lies still and settles, so `set_get_up` counts from
then. A `LIMP` figure is past it.

- **The legs** draw up together and let down, once every 1.7 s: the hips
  bend forward 0.6 rad and the knees 0.2 at the top. The knees bent less
  than the hips lift the feet off the ground; a foot dragged along it,
  the legs half a cycle apart, pushed the figure across the ground.
- **The arms** fold over its front, toward where it was last struck: the
  shoulders forward 0.7 rad and in 0.3, the elbows 0.6, rocking 0.12 rad
  every 1.1 s. The reference ragdoll's shoulders and elbows turn too little
  for a hand to reach its own chest, so the fold is as far as they go.
- **It fades:** full for the first half of its time, then less and less.
- **Face down**, it turns over onto its back first, and again whenever it
  rolls onto its front: the arm on the side that is higher already pushes
  the ground away, driven back to its rest at the figure's side with its
  full muscle, the leg on that side draws up (the hip 0.5 rad, the knee
  0.8), and the other arm and leg let go so the body rolls over them.
  Writhing face down, the arms folding toward a wound under the body
  pressed into the ground and pushed the figure up onto them.
- **A limb a blow left weak**, or the struck arm, doesn't take part: shot in
  the arm, it clutches with the other, and it turns over on the other side.

Limbs that writhe have 45% of their muscle, turning over all of it; the
rest keep the 15% lying leaves them, since a limb not aimed drives toward
the standing pose and, strong, would push the body over. Every bend is
from the limb's rest place under its parent, within its joint's limits.

`tests/test_writhe.ae` knocks three figures down with 450 N·s from behind:
one writhes for three seconds, a twin lies still, and a third is struck
on the right forearm once down. They land face down.

| | Measured |
|---|---|
| the left hip's swing, 0.5 to 2.5 s after landing | 1.18 rad writhing, 0.006 still |
| the left upper arm toward the chest's front (cosine) | 0.47 writhing, -0.01 still, 0.52 struck on the right forearm |
| the pelvis's drift from 1.5 s down to the end of writhing | 0.25 m (the still twin's, over three seconds, 0.08) |
| it stops | 3 s after landing, down 0.15 s later |
| the struck arm | never aimed |
| the same run twice | the same to the bit |

Across twenty shoves from behind, 420 to 515 N·s, every one of them passes
all of these.

## On a figure

`motion.on_figure(e, object)` gives an animated figure (`ae3d.figure`,
#439) an active ragdoll:

```aether
zombie = figure.figure(e, "Zombie", "assets/zombie.glb")
figure.play(figure.figure_of(zombie), "Walk", 1.0, true)
body = motion.on_figure(e, zombie)           // ANIMATED: the clip plays, the bodies follow
motion.set_mode(body, motion.POWERED)        // the muscles play the clip
motion.set_get_up(body, 3.0)
```

The ragdoll is made where the object stands. It is turned to face the
way the figure's feet point before it is dressed, so the figure keeps the
turn the scene gave it. The figure's bones are found by name, in whichever
humanoid naming they follow: the engine's pipeline's (`Hips`, `Spine`,
`Chest`, `ThighL`...) or Mixamo's (`mixamorig:Hips`, and without the
prefix, as most packs that follow it write them), whose top spine bone,
`Spine2`, is the ragdoll's chest. A rig that is neither gets no ragdoll
(`physics.humanoid_scheme` is -1). `motion.on_skeleton(e, object,
skeleton)` does the same for a skeleton that is not a figure's.

The scene file carries it as the `motion` record of the figure's group:
`{"mode": "powered", "strength": 0.8, "protective": false, "get_up": 3}`.
`motion.from_record(e, object, spec)` puts it back on a figure a scene
read in. A figure getting up is written as the mode it gets up to.

`tests/test_motion_figure.ae` checks two humanoid rigs, one in each
naming, each turned a quarter turn by its object, and a two-bone rig:

- both humanoids are known, and the two bones are not;
- dressed, each faces within 3.7° of its object's turn;
- `POWERED`, both stand on their muscles for two seconds, the pelvis at
  1.0 m and leaning at most 1°;
- the scene file brings back each one's mode, strength, protection and
  get-up.

## Getting up

`get_up(body)` gets a figure on the ground back on its feet, whatever mode it is in, and `set_get_up(body, seconds)` has it do so by itself once it has lain still that long (0, the default, never). On the ground is leaning past 1 rad, or the pelvis within 0.45 m of the figure's lowest point, which covers a figure that crumpled where it stood. Lain still is the pelvis moving less than 2 mm a step for ten steps. `down(body)` says it is.

The way up matches how it lies. The chest's front says which: to the sky is face up, to the ground face down. The chest, not the pelvis, because a figure propped on its arms can have its pelvis pointing anywhere.

- **Face up**, it sits up with its knees drawn in and its hands behind it, crouches over its feet, and stands, facing where its feet lay.
- **Face down**, it pushes up onto its hands and knees, brings its feet under it, and stands, facing where its head lay.

Each is three stages of 0.7 s, eased in and out: the pose it lies in, the first key, a crouch, and the animation's own pose. The last key is moved to where the figure stands (its feet where the sitting feet or the kneeling knees were) and turned to face the way it rose, so the animation takes over with nothing to jump. Each key between is the figure's reference bones, bent in its own frame from standing: a lean in degrees for each bone about the axis across the figure, placed bone by bone through their joints from the pelvis out and set down with its lowest point on the ground. The axis across comes from the knees: the reference's figure faces the way its knees don't bend. Its toes splay 23° from that, and a bow about an axis that far off bent the knees sideways.

The way up is the rig's, drawn exactly, and the bodies follow it through the anchors an `ANIMATED` figure's follow, so it collides as it rises. It can't be played by the muscles: the reference ragdoll's hips have a 30° cone and its knees 60°, too little to sit or crouch.

A figure that was `POWERED` is `POWERED` again once up; any other ends `ANIMATED`.

**Blends.** Two hand-overs used to jump.

- **`POWERED` to `ANIMATED`.** The figure blends over a quarter second from its bodies' pose to the animation's.
- **Into `POWERED` from a rig that drove it.** This covers a walker struck, and a figure that has just got up. The drawing goes from the rig's pose to the bodies' over a quarter second. The bodies follow a rig of other proportions only so closely, about 10° on each limb, and a figure drawn first one way and then the other popped by that much.

`tests/test_get_up.ae` holds it to numbers. Four figures take part:

- one knocked over backwards;
- one tripped, its shins swept back and its chest pushed on, which lands face down;
- one limp from the start, crumpled where it stood;
- one standing and powered, set `ANIMATED`.

| | face up | face down | limp |
|---|---|---|---|
| gets up by itself, half a second after it settles | yes | yes | yes |
| the worst turn of any drawn bone in one step | 4.6° | 3.5° | 4.1° |
| the worst move of the drawn hips in one step | 20 mm | 20 mm | 20 mm |
| the hand-over to the animation | 0°, 0 mm | 0°, 0 mm | 0°, 0 mm |
| the lowest any body goes on the way up | 2 mm into the ground | 7 mm | 2 mm |
| up, the most it leans in the next second | 1.1° | 1.1° | 1.7° |
| facing, against where its feet (head) lay | 16° | 12° | |

The blended figure takes 15 steps, a quarter second, and no drawn bone turns more than 1.3° in a step. The limits the test holds are 6° a step, 40 mm a step for the hips, 1° and 5 mm at the hand-over, 3 cm into the ground, 10° of lean afterwards and 30° of facing.

## What it costs

An active ragdoll is for the figures a player is close to, not the horde:
the horde hands the dozen nearest over when they are struck.
`tests/test_motion_cost.ae` measures what that costs. It steps 0, 4, 16
and 32 `POWERED` figures standing on one ground, each figure's chest
bowing so it stays awake, for 120 fixed steps once they have settled:

| figures | the step | a figure | in a millisecond |
|---|---|---|---|
| 0 | 0.2 µs | | |
| 4 | 142 µs | 35 µs | 28 |
| 16 | 330 µs | 21 µs | 49 |
| 32 | 636 µs | 20 µs | 50 |

A figure standing still falls asleep and costs nothing, which is why the
figures bow: an awake figure is what the step pays for. A dozen awake
figures cost about a quarter of a millisecond a step. The test holds a
figure under 80 µs, a dozen within a millisecond, and every figure still
standing at the end.

## Handing over from the horde

A horde can't be active ragdolls. Its thousands of zombies are instances posed from a pose bank: a position, a heading and a phase each, and no bodies. An active ragdoll costs 20 to 40 µs a fixed step. So `ae3d.handover` keeps a pool of a dozen figures and hands the few zombies that are struck to them, and takes them back when they recover.

```aether
import ae3d.handover

pool = handover.pool_new(e, "zombie.glb", "Walk", 12)   // the horde's file and the clip its bank was baked from
handover.set_horde(pool, pos, yaw, phase, count)       // the horde's columns
handover.set_facing(pool, facing)                      // the turn the horde's draw adds to a heading
handover.set_colors(pool, tint)                        // optional: each figure wears its zombie's tint

// every frame, the horde's step passes by the zombies handed over
crowd.crowd_step_out(pos, vel, yaw, phase, handover.outs(pool), 0, count, delta, ...)

handover.strike(pool, zombie, point, impulse)          // POWERED, hit: falls, gets up, goes back
handover.kill(pool, zombie, point, impulse)            // LIMP: lies, and is despawned
```

- **The pool.** Each figure is made from the horde's own file with `figure.figure`, and given an active ragdoll with `motion.on_figure`. Then it is parked: hidden, its clip stopped, and every body and anchor taken out of the physics world (`physics.ragdoll_park`). Twelve parked figures cost under 2 µs a frame.
- **Handing over.** `strike` sets the zombie's `out` flag, which the horde's step (`crowd.crowd_step_out`, `horde.step_out`) passes by. It parks the instance a million metres off, past every cull and the far plane, so both the CPU sort and the device's drop it without a change to either. A free figure is stood where the instance was drawn, turned as it was turned, its clip at the time the phase is at. Its bodies are put where its rig is (`physics.ragdoll_to_rig`), rather than dragged there by their anchors. Then it is `POWERED` and hit at the bone nearest the point. `kill` sets it `LIMP` instead.
- **Taking back.** Every fixed step the pool looks at its figures. One that is back on its feet stands `POWERED`, not falling, lying or getting up, leaning under 0.2 rad, with every muscle back from its blow. After `set_settle` seconds of that (0.5 by default), its animation is moved to where its bodies stand and it is set `ANIMATED`, which blends it into its clip over a quarter second. Blended, its zombie goes back to the horde where the figure stands, facing as it faces, at the phase its clip is at. The figure is then parked. `set_on_return` is told just before.
- **The dead.** A killed figure lies `LIMP` and is never given back. It is parked after `set_despawn` seconds (10 by default; 0 leaves it lying). Its zombie stays out of the horde (`is_dead`).
- **A full pool.** A strike takes the figure farthest from it that is not mid-fall: a killed one lying, or one standing over its blow. That figure is given back, or despawned, first. When every figure is falling, lying or getting up, the strike is refused (-1) and the zombie stays in the horde.

**No pop.** The pose bank is the clip struck in place: the root's travel over the ground is taken out of every bone (`crowd.posebank_bake_in_place`). So a figure playing the clip at time t, turned as the instance is, with its hips over the instance's position plus their bind offset, is the instance's pose at phase t / duration. Read backwards, the same relation puts a figure's pose back into the horde. Before each hand-over, the figure's nodes are put back as the file has them. Dressing a ragdoll poses the rig as the ragdoll stands, and a figure that lay limp last time would otherwise be stood in the pose it lay in.

`tests/test_handover.ae` holds it to numbers. The horde is 48 of the box man fixture, baked from its Idle. The pool is four of the same figure. No window is needed.

| | Measured |
|---|---|
| handing over: every bone against the pose bank's pose on the instance | 0.007 mm |
| handed over: the instance out of every tier of the sort, and not moved by the step | yes |
| four struck at 400 N·s: the lowest pelvis | 0.15 m |
| each gets up by itself and is back in the horde | all four, 7.3 s after the blow |
| giving back: every bone against the instance's pose | 5.2 mm: the figure stands 5 mm lower than the horde's road, the rest 0.007 mm |
| the zombie given back, from its figure's pelvis | 14 mm |
| a fifth strike while all four fall | refused |
| a killed one | down and kept for 2 s, despawned at 3 s, its zombie out of the horde |
| four shoved at 40 N·s and standing: a fifth strike | reuses the farthest, given back first |
| the whole run twice | the same to the bit |
| a frame of 400 zombies: no pool, twelve parked, twelve handed over | 2.7 µs, 4.3 µs, 290 to 400 µs |
| so a figure handed over, a frame | 24 to 33 µs: its motion, its physics, the pool |

The limits it holds are 2 mm at the hand-over, 10 mm at the giving back, 12 s to come back, 0.3 ms a frame for twelve parked and 3 ms for twelve handed over.

`examples/horde_strike.ae` is a field of 300 of any humanoid glTF (the box man by default), with a pool of twelve. A left click strikes the zombie under the cursor, and a right click kills it. With no one clicking, a timer strikes the zombie in the middle of the view every second and a half, and every third blow kills.

The networked horde (`ae3d.nethorde`) keeps its own columns and hands nothing over yet.

## What it is held to

`tests/test_motion.ae` runs eleven figures on one ground, each dressed in a humanoid rig:

| Figure | Measured |
|---|---|
| the tracker, its rig bowing the chest 15° forward and back | the chest within 1.6° of its pose; the figure never leans more than 0.7° |
| the shoved, 60 N·s to the chest | knocked 28.7° off its pose, back within 0.1° and upright three seconds later |
| the felled, 400 N·s to the chest | down |
| the struck, 8 N·s to the right upper arm | its muscle at 5% (the forearm's at half), then back to full |
| the limp | down |
| three protected fallers, felled by 400 N·s from behind (forwards), from the front (over backwards) and from the side | the hands reach the ground first each time (26 and 40 steps before the head, and the head never does from the side); the head meets it at 1.04 and 0.83 m/s |
| their unprotected twins | the head meets it at 1.95, 3.68 and 2.19 m/s |
| the protected fallers, landed | each lets go and lies |
| the felled, as drawn | its drawn hips at 0.19 m, with its pelvis body (a standing figure's are above 0.8 m) |

The shoved never takes itself for falling. Hands and head are measured by their capsules' lowest points (the forearm's hand end, and the neck bone's capsule, which is the head). The figures face -z, the way their toes and knees point, so a blow along -z is from behind; the test named the first two ways the other way round, and measured the left hand on the right forearm's capsule, 0.31 m behind the elbow, until the limbs' mirroring was found.

Pose error is measured per joint (a bone against its parent), which is what a muscle answers for. The lean is the pelvis's up against the animation's. A figure turned about the vertical is still on its pose.

## Next

As #414 lays out:
- balance by feedback on the hips and the stance foot, in place of the pelvis's assist;
- get-up clips from the pipeline in place of the keyed ways up, once a figure has them;
- the inspector's section, with a Hit button in the viewport;
- handing over from the networked horde: the strike and the giving back as horde inputs, so every peer takes the same zombie out at the same tick;
- drawing a powered figure's bodies each frame rather than each step, for an animation that plays on while its muscles track it.
