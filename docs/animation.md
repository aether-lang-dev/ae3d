# Animation

How figures move when nothing pushes them: clips, the changes between
them, layers on top. The active ragdoll that takes over when something does
push them is [motion.md](motion.md). The epic for all of it is #509.

## Changing clip without a pop

`figure.play` cuts. The new clip's first pose replaces the last one in a
single frame, so a fox going from Walk to Run jumps a bone 59 units (it is
modelled in centimetres) and turns one 89 degrees in a frame. The clips
themselves never move a bone more than 8.4 units or 25 degrees in a frame.

`figure.play_blended(f, clip, rate, loops, seconds)` inertializes instead
(Bollo, GDC 2018, #574):
- When the clip changes, each node keeps its offset from where it was
  drawn to where the new clip puts it: the rotation as an angle about an
  axis, the position axis by axis.
- It also keeps the speed that offset was changing at, from the two frames
  it was last drawn in.
- The offset decays to nothing over `seconds` along a quintic that starts
  at that speed and ends at rest. An offset growing away from rest is
  taken as still, so it cannot overshoot, and one falling fast comes to
  rest no later than its own speed allows.

An offset that comes to rest early stays at rest. Each quintic keeps its
own rest time, and is not evaluated past it, where the polynomial runs away.
Changes landing on a change still decaying (Run, back to Walk a frame later,
Survey two frames after) step a bone 12.5 degrees a frame at most. Before
that was kept, the same chain turned a bone 40 degrees in a frame, and a
locomotion stop from a run spun an arm 175.

Nothing is averaged between two poses. The new clip plays from its first
frame under an offset that fades, so feet are never dragged sideways by a
mix of two strides, and the motion carries on at the speed it had instead
of stopping dead. The same change takes the fox's largest step in any frame
to 6.7 units and 12.5 degrees, inside the clips' own. 0.4 s after a 0.3 s
change, the pose is Run's own to within 1e-7.

## Layers

On top of the clip and its transition:
- `figure.layer_play(f, clip, bone, weight, additive, loops)` plays
  another clip over the bones under `bone`, at a weight: an upper body
  that aims and reloads over legs that walk.
- With `additive`, it plays the clip's change from its own first frame,
  added to whatever is beneath: breathing, a flinch.
- `layer_set_weight` and `layer_stop` adjust and remove layers. They apply
  in order, each over what the ones below posed.

`tests/test_blend.ae` checks all of the above on the Fox fixture with no
window:
- the cut is measured and the inertialized change held inside the clips'
  own largest step;
- the pose after the blend equals the new clip's;
- a layer under `b_Spine01_02` (10 of the fox's 24 bones) poses those bones
  as its clip does and leaves the other 14 as the walk beneath;
- an additive layer changes nothing at weight 0 or at its first frame, and
  turns bones by 0.42 rad half a second in.

## The crowd's feet and heading

A crowd figure's pose bank is baked in place, so its feet move back under
its root at exactly the root's travel, and a body that covers that distance
leaves them where they were set down. Before #575, five things broke that:

| What | Before | Now |
|---|---|---|
| Speed | the bank's speed at the frame the phase falls in, while a step crosses frames | the root's travel over exactly the stretch of the walk the step plays (`posebank_travel_over`, interpolated) |
| A speed limit | applied after matching, so the clip ran on while the body was held back: a figure held to 60% slid by 40% of its speed | the walk slows by the same share |
| Standing | the walk played on the spot | the walk stops |
| A clip made in place (Mixamo's "in place", the Fox's walk) | travel zero, so a crowd matching its speed to the bank stood still | travel taken from the foot on the ground: frame to frame, the lowest of the bones that rise and fall over the walk, along the way the feet go back. A foot still landing, carried forward, counts against the walk, so the cycle's length is true; frame to frame the travel never goes back |
| `horde_strike` | stepped its crowd with no bank, the walk unrelated to the travel | stepped with its bank |

The heading turns toward the way a figure goes at no more than 3.5 radians
a second (`TURN_RATE`). A neighbour's shove turns it over a few frames, not
one. An edge no longer flips it 180 degrees in a step: near the edge,
within half a second's walk, a figure not yet heading away is pointed back
in, and it turns until it walks away. In `examples/street_drive.ae` the
walkers likewise turn back on a tight arc at 2.4 rad/s, at 45% of their
pace with their gait slowed to match, instead of rotating π in one step.

`tests/test_crowd_feet.ae` runs on the Fox's walk:
- 65 units of travel a 0.71 s cycle (it is in centimetres) recovered from its
  feet;
- no slide in a step walking free or held to 60%;
- the walk stopped while standing;
- a heading shoved left and right every frame turns 3.34 degrees a frame
  at most (the cap);
- walked into an edge, it turns back by no more than the cap a frame and
  walks back into the street.

## Feet on the world

A clip is made on a flat floor. `ae3d.feet` (#577) puts a walking figure's
feet on the ground under them, whatever shape it is, every frame in the
engine's pose phase (after the clips, before the draw):

```aether
f = feet.attach(e, figure_root, hips, l_hip, l_knee, l_ankle, r_hip, r_knee, r_ankle)
feet.ground_physics(f, physics.of(e))      // a ray down onto the static world
feet.ground_height(f, height_fn, state)    // or a function of x and z
```

- **The target.** Each foot's target is its animated place raised or
  lowered to the ground under it, by however far that ground is from the
  root's floor. A swing over a kerb clears the kerb by what it cleared the
  floor.
- **The pelvis.** It comes down so the lower foot can reach its ground,
  and never goes up. It eases at no more than `PELVIS_SPEED`
  (0.6 m/s), so a kerb appearing under a foot never snaps the body down.
- **The legs.** Each is solved onto its target with `ae3d.ik`'s two-bone
  solver, its knee turned toward the way the figure faces.
- **The foot.** A foot on the ground is turned to lie on it, by up to 30
  degrees.
- **Locking.** A foot the clip has set down (low and slow) is locked where
  it was set, whatever the body does over it, until the clip lifts it. It
  is then let go over 0.15 s. No hand-made contact labels are needed.

`set_weight` eases it out while the figure is in the air or ragdolled.

`tests/test_feet.ae` runs on the box man (Mixamo's names), with no window:
- on flat ground nothing moves;
- on a 15-degree slope across the stance, each foot stands within 1e-14 m
  of its height over the slope, the pelvis comes down 2.7 cm for the lower
  foot, and the knees bend forward, never past straight;
- stood on a 20 cm kerb with one foot off, that foot reaches the road and
  the pelvis comes down 20 cm, 1 cm a frame at most;
- a planted foot moves 2 mm while the body walks 6 cm over it, and is let
  go when the clip lifts it.

## A figure under a player's hand

`ae3d.locomotion` (#576) is what a player's character is made of: a
character controller for where it goes, a figure for how it looks going
there, and the motion between them.

```aether
c = physics.character_controller(player, 0.3, 1.8)
l = locomotion.attach(e, player, c, "Idle", "Walk", "Run")
locomotion.set_input(l, direction, running)   // every frame; the length is the stick's deflection
```

- **Momentum.** The asked-for velocity is reached at no more than
  `ACCELERATION` (4 m/s²) and given up at no more than `DECELERATION`
  (6 m/s²). A start leans into its first steps, a stop settles.
- **The clip follows the speed, and the speed the clip.** Each clip's own
  speed is read from it as the crowd's banks are, sampled at 120 a second:
  which foot is the lowest changes between samples, and a coarse bake puts
  that change early or late and the speed off by it. The walk or the run is
  played at the body's speed over that, so its feet cover what the body
  does. Below `IDLE_BELOW` it idles; it runs above the middle of the two
  speeds. Every change is inertialized.
- **The facing** turns toward the way the body goes at no more than
  `TURN_RATE` (4 rad/s). The way a clip walks is read from it (its root's
  way, or against the way its feet go back), so a pack whose figures face
  -z walks forward.
- **The lean.** The hips lean into a turn by how fast it turns at its speed
  (up to 12 degrees), and forward or back into a change of speed (up to 6).
  The hips are a pack's by name, else the shallowest bone the walk poses:
  a skin's first joint is often a still root above it. They are put back
  to their own pose before each frame's lean, so a bone no clip poses does
  not gather it frame on frame.
- **A step.** The controller climbs a step at once; the drawn body climbs
  it at `STEP_SPEED` (1.2 m/s), the hips carried by the difference.
  `ae3d.feet` finishes the job where the figure has legs.

`tests/test_locomotion.ae` drives the Fox at a metre long through a scripted
run with no window: stand, walk, half the stick, run, stop, a quarter turn,
turn round, a 20 cm step. The numbers:

| Measure | Result |
|---|---|
| The foot on the ground's drift along the way, over whole cycles | 0.19% of the body's way walking, 1.7% at half the stick, 0.14% running |
| The same, aside | 0.01%, 0.02%, 2.2% (the run's own gallop) |
| The most any bone turns in a frame, through every change | 25 degrees, the clips' own (a cut is 89) |
| The facing's turn in a frame | 3.82 degrees, the cap |
| Change of speed | 6 m/s² at most, the deceleration |
| The drawn hips up a 20 cm step | 1.24 m/s, against 1.2 plus the walk's own bob of 0.22 |

The Fox's clips themselves carry a foot 14 cm (walk) and 32 cm (run) while
it is the lowest, as it lands and lifts, played on the spot as much as
under a body. Pacing cannot take that out; locking the feet (`ae3d.feet`)
does, on a figure with legs to solve.

## Motion matching

`ae3d.matching` (#586, part of #509) moves a figure the way motion matching
does. A spring moves the body. Every tenth of a second the figure's clips
are searched for the moment whose pose and path ahead best fit where the
body is going, and that moment is entered by inertialization.

```aether
db = matching.database_new(fig, root)
matching.add_clip(db, "Idle")
matching.add_clip(db, "Walk")
matching.add_clip(db, "Run")
matching.build(db)
m = matching.matcher_new(db)
matching.set_input(m, velocity)   // every frame
matching.step(m, delta)           // moves the root, searches, plays, advances the figure
```

- **The database.** The clips are sampled 60 times a second. Each frame
  stores, in the root's frame with the way the clips walk as +z:
  - up to four feet's places and velocities (the bones that rise and fall);
  - the hips' velocity;
  - the path ahead: where the root is 0.33, 0.66 and 1 s on, and the way it
    faces. A clip made in place takes its path from its feet's travel.

  Each feature is scaled by its spread, and each group weighted: the path
  ahead three times the feet. At equal weight a standing figure asked to
  walk kept choosing to stand on.
- **The spring.** Velocity and facing ease toward what is asked,
  critically damped with a 0.27 s half-life (Holden's). The spring is
  also the search's path ahead.
- **The search.** Runs of 16 and 64 frames each have a bounding box in
  feature space; a run whose box is no nearer than the best found is
  passed over, and a frame's cost stops adding once it passes the best,
  with the playing frame as the first best (#588). It finds the same frame
  as brute force. The current pose is the playing frame's own
  features, so it asks what continues best from here. It changes clip only
  when the best is a quarter better than carrying on: a jump to a phase
  that fitted a little better slid the feet. A clip that walks plays at the
  body's speed over its own, between half and one and a half times.
- **`figure.play_blended_at`** enters a clip at a given time under an
  inertialized offset.

`tests/test_matching.ae` drives the Fox, a metre long: standing, a walk, a
run, let go, sent to the side.

| Measure | Result |
|---|---|
| The clip each stretch plays | Survey, Walk, Run, 100% each |
| The foot on the ground's drift along the way, whole cycles | 0.06% walking, 2.7% running |
| The most a bone turns in a frame, at its clip's pace | 25 degrees |
| The facing's turn in a frame | 2.8 degrees |
| 2,000 searches over 316 frames | 0.83 ms (brute force 7.8 ms), the same frame as brute force in all 777 searches checked |

That is #509's 2,000 searches in a millisecond, on one thread, over the
Fox's database. A larger database, or the job system, is the next step.

## Looking

`ae3d.lookat` (#587, part of #509) turns a figure's head to look at a
point. It runs every frame in the pose phase, after the clips.

```aether
l = lookat.attach(e, figure_root, neck, head, forward)   // forward: the way the figure faces, in its root's frame
lookat.set_target(l, point)
lookat.clear(l)
```

- **The turn.** It runs from where the clip has the head facing to the
  point: about the figure's up, then across. Each part is held within a
  neck's reach: 80 degrees either side, 57 up and down.
- **Eased.** A critically damped spring with a 0.12 s half-life moves the
  turn toward what is asked, or back to none when cleared, so a head never
  snaps round. `set_weight` fades it in and out.
- **Shared.** The neck takes 40% of the turn and the head the rest. The
  whole turn is made first and then shared: a yaw-and-pitch turn on the
  neck and another on the head are not the whole one, and they left the
  head 3 degrees off.
- **Put back each frame.** The bones it turns are returned to their own
  pose before each frame's turn, so a still pose is not turned further
  frame after frame.

`tests/test_lookat.ae`, on the box man playing its Idle:
- **Within the limits.** A point 31 degrees aside and a little up is faced
  to 2.8 degrees. The rest is the eased turn trailing the Idle's sway.
- **Past the limits.** A point behind holds the turn at 1.4 rad.
- **No snapping.** The head turns 5.7 degrees a frame at most, the clip
  included.
- **Cleared.** It is back on its clip, to 0.0001 rad.
- **Nothing else moves.** No other bone moves.

## A player's figure posed by matching

`locomotion.use_matching(l, db)` (#591) poses a figure on a character
controller by motion matching over a database of its clips, instead of
idle, walk or run chosen by speed. The controller still moves the body,
with its momentum, steps and capped turn.

`matching.follow(m, position, velocity, wanted, heading, delta)` is told
where the body is, how it moves and what is asked of it. It searches and
plays and paces the clip, but moves nothing and leaves the figure for the
engine to advance.

`tests/test_locomotion.ae` runs its whole script both ways, to the same
checks:

| The foot on the ground's drift along the way | by speed | by matching |
|---|---|---|
| walking | 0.19% | 0.29% |
| at half the stick | 1.7% | 0.17% |
| running | 0.14% | 2.3% |

No bone turns more than 25 degrees a frame either way.

When the search stays with the playing clip, the playing frame is still
the one on screen. Before, it was taken for the best frame, and the next
query's pose was a frame not being shown.
