# Natural motion

`ae3d.motion` is an active ragdoll (#414): a figure whose animation is played by its muscles rather than pasted onto its bones. It's what GTA IV and V get from NaturalMotion's Euphoria. Hit it, and it gives where it was hit and comes back; hit it harder than it can take, and it falls. It's an option on the engine's own motion system, a component on any ragdoll that wears a skinned figure (`physics.ragdoll_dress`), and off unless asked for.

It has muscles, balance, reactions to hits, a protective fall and getting up again. Balance that steps to catch a fall, and writhing, come next.

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

**Heading.** That anchor leaves the way the figure faces free, so its feet hold it, as a sole's grip on the ground does (#689). While the figure is on its soles, stepping or not, and leans less than 0.35 rad, a turn of up to 60 N·m about the vertical (840 N on a sole at a friction of 0.9, over 8 cm) brings its pelvis back to the way its pose faces it. Unheld, a swinging leg turned the pelvis and the trailing foot was dragged round after it: the motion showcase's figures turned 45° a shove from behind, and 127° after six. Held, they stay within 5°. Held past that lean too, figures falling forwards came down on their hips in 7 of 30; held only between steps, they took a step more to stand and turned 12°.

**Strength and hits.** `set_strength(body, s)` scales every budget (0 is limp, 1 full strength). `hit(body, bone, point, impulse)` applies the blow and takes a share of the struck bone's budget, and half that share of its neighbours'. By default the share is the speed the blow gives the struck bone over 1.6 m/s, capped at 95%: a bullet in an arm (8 N·s on a 4.9 kg arm) takes all of it. A game that knows what struck passes the share itself, `hit(body, bone, point, impulse, true, cost)`. A punch to the head moves it hard and should cost a little: 0.1 takes 9.5% of the neck's muscle, where the default takes 95%. It comes back over `set_recovery` seconds (0.8 by default), so a shoulder shot drops the arm and the arm comes back up.

**Where it was hit (#698).** A blow the figure stands through is answered where it landed. A free hand comes to the wound and holds it for 2.5 s, carried with the body: the hand on the wound's side for the trunk or a leg, the other hand for an arm. It is never the struck arm or a weak one, and not while a startle or a brace has the arms. The palm covers the wound from the side of the bone it can reach, so a wound on the outside of an arm is held from its front, and the arm turns there at no more than 4.5 rad/s. A wound to the trunk folds the spine toward it (forward for the belly, sideways for a flank), and a wound to a leg bends its knee, both by how much of the bone's muscle the blow took. A blow that takes under a quarter of it is not answered, nor is one that gives the whole body 0.3 m/s or more: that one throws the body, and the balance, the steps and the arms answer it. `set_hit_reaction(body, false)` turns it off. Struck in the belly with 25 N·s, the palm rests 13 cm from the point struck and the chest folds 8 cm toward it; struck on the thigh, the knee gives 0.3 rad. Reaching across the body to the other upper arm, the forearm comes to rest on the chest and the palm about 10 cm short of the arm, because the reach doesn't route around the trunk (#700).

## The protective fall

A `POWERED` figure that leans more than 0.35 rad (20°) from its pose is falling (`falling(body)`), and it protects itself, as a person does (`set_protective(body, false)` turns this off):

- its balance keeps working against the fall until it is down: the pelvis's assist keeps its full torque. Let go at the first lean, the figure toppled from the hips like a plank;
- its arms reach toward where it is falling, 0.7 down to 1 along the fall and a little out to each side so the hands land apart, and straight, since a straight arm takes the landing through its joints where a bent one folds on its elbow's muscle;
- its head tucks 0.8 rad away from the fall, from where the chest carries it;
- its knees give, 0.45 rad toward their bend (#578), so it comes down in stages, knees then hips then hands, rather than toppling from the ankles like a plank. Forwards, when it leans past 45 degrees its pelvis is 0.35 m down, against 0.20 for a twin that keeps its knees. The knees bend 2.3 rad (130 degrees) from straight and no further than straight, as a person's do; the reference ragdoll's bent 60 degrees, with straight on one limit. With that range a fall's knees fold further on their own (a twin's reach 0.6 to 0.95 rad), though the protective fall's own bend stays 0.45: a deeper one, or a deeper step, has caught fewer falls and pushes;
- when the fall is toward its back, its spine bends away from the fall too, 0.5 rad at each of its two joints. Going over backwards, from the first lean, that rounds the back and tucks the chin, so the head comes down last. In a fall forwards or sideways the pelvis's front turns back along the fall once it passes level; face down, the bend arches the back and lifts the chest and head off the ground.

If it catches itself (leans less than half the threshold again), the reach and the tuck let go and the balance comes back. It has landed when it leans past 1.2 rad (69°) with its pelvis down, within 25 cm of its lowest point, for ten steps: the reach stops, the balance lets go, and every joint holds the shape it landed in, the head still tucked, on 40% of its budget (`physics.ragdoll_hold_shape`). Once its pelvis and chest have been slower than 0.3 m/s for ten steps more, it lies (`lying(body)`). A fall caught on the hands and knees, or sitting, leans less or keeps its pelvis up. Its trunk still for a third of a second, it has landed as well, and holds the shape it was caught in at full strength with its balance kept, as a person on all fours does. A caught figure can still go over -- kneeling, it tips onto its face -- and if its trunk moves faster than 0.3 m/s again after it has lain still, it falls again: the shape let go and the arms reaching, to land and lie as any fall does.

Each of those was measured over thirty falls each way. With the arms still reaching once the figure was down, they pushed it back off the ground, and it fell a second time. Held at full strength, a figure lying flat rocked. Below a fifth of its budget the shape sagged and crept, and from half upward the joints chattered against the ground. Two fifths settles the most: at a third, a forearm propped up as the figure landed tipped over for a second, and the slowest sideways faller lay still 3.25 s after landing; at two fifths every fall backwards and sideways is still within 1.3 s. Held through a tip-over, a kneeling figure went over in its kneeling shape and rocked on its arms after. A caught figure let go to that share slumped onto its face. Holding the shape takes its own drive. An aim holds a bone's rotation in the world, and every bone aimed where it lay wrenched the legs back toward those rotations as the body rolled. Within 0.02 rad of a held shape the joints brake rather than chase it, or the calves creep along the ground for good.

**In the street.** `street_drive`'s bystanders are active ragdolls. The ones that stand hold themselves up on their muscles, and the walkers walk by their animation until struck. The car's blow is about 60 N·s per m/s it was closing at, along its heading. Past 4 m/s it lands on the pelvis, which takes the balance with it, and the figure goes down reaching for the road. Below that it lands on the spine, and the figure is knocked back and recovers. On the autopilot's run the three bystanders in the road are struck at 7 to 10 m/s and all three go down. Before this they went limp the moment they were touched.

The reach, the tuck and the bend are **aims** (`physics.ragdoll_aim(ragdoll, bone, rotation)`): a bone's joint drives it to a rotation in the world, from wherever its parent is, instead of to the animation's pose. The bones below it keep the animation's pose relative to it. Any controller can aim a bone this way, for example to turn a head toward a threat. `ragdoll_clear_aim` and `ragdoll_clear_aims` hand the bones back to the animation.

The reach and the tuck were first chosen by one fall each way while three faults hid in them. The way of the fall was read from the pelvis body's +y, which points down because aephysics's pelvis rests a half turn about x, so the arms reached away from the fall and the head tucked into it. One arm axis served both arms, though the left arm's capsules lie along +x and the right's along −x, so the left arm reached up. And the pelvis's anchor, its assist set to nothing as the figure fell, kept applying its last impulse for as long as it lived (aephysics#58): an assist nobody had asked for, which every setting had been chosen on top of. With the three fixed, `tests/test_falls.ae` holds the protective fall over thirty falls each way, with blows from 376 to 424 N·s, a protected figure beside an unprotected twin each time. The settings were swept on it: a tuck of 0.5 to 1.2, a bend of 0 to 0.5, the assist from none to all of it, the reach 0.4 to 1.0 down, the fall's lean 0.25 to 0.45. Without the assist no setting kept the protected head slower in more than 18 falls backwards and 22 sideways.

| way | protected head slower | head, protected / twin (average) | a second head impact | still within 3 s of landing | knees going down |
|---|---|---|---|---|---|
| over backwards | 30 of 30 | 0.10 / 3.63 m/s | 0 | 30 (the slowest 1.25 s) | 0.45 rad |
| forwards | 30 of 30 | 0.84 / 3.20 m/s | 0 | 30 (0.88 s) | 0.45 rad |
| sideways | 30 of 30 | 0.18 / 3.29 m/s | 0 | 30 (1.52 s) | 0.48 rad |

The knees giving took the forward head from 1.44 m/s to 0.84 and the forward count from 29 to 30.

Forwards the blows run from 410 to 460 N·s: from behind, a figure that steps now staggers out of shoves up to 390 (below), and with 376 to 424 four of the thirty were caught and never fell. Every way meets #479: the protected head the slower in at least 29 of 30, no second impact, every figure still within 3 s of landing.

Before, on the same ensemble (the reference's figure, all three faults), the protected head was the slower in 14, 23 and 21 falls, and over backwards it met the ground faster than its twin's on average (2.99 against 2.77 m/s). Forwards, its head met the ground a second time in 16 falls.

## Struck while animated

A figure stays `ANIMATED`, drawn from its clip, until something touches it,
and goes `POWERED` the moment it is struck (#581). Its bodies trail a rig
of other proportions by up to 2 cm at rest, so the drawing can't jump
straight to them. At the change it keeps the offset the rig's pose had
from the bodies, and that offset fades over 0.25 s. What the blow does to
the bodies shows on the frame it lands.

Before, the drawing blended from the rig's pose to the bodies' along a
smoothstep, which starts flat. A blow showed late, and a second blow in
those 0.25 s landed where the figure wasn't drawn.

The offset is taken each frame along what then lies between the bodies and
the pose shown, and never more than that (#665). Kept as it was on the
frame of the change, it went on top of bodies already moving the pose's
way, and counted twice. A risen walker whose get-up had keyed its knee
straighter than its bodies had its knee drawn 7 to 11 degrees past straight
as the bodies straightened it. `tests/test_handover_gap.ae` hands a box man
over with its bodies' knee bent and the pose shown straight: the drawn
knee never passes straight, and a quarter second on it is the bodies'.

Hand the figure over (`set_mode(m, POWERED)`) before letting go of whatever
else writes its rig, the feet's solved legs or a look's turned head. The
pose shown is the rig as it is at the call. Let go first, the rig was back
on the clip, the drawing started there while the bodies had just been put
on the solved legs, and a nearly straight knee the feet had bent was drawn
backwards 6 to 14 degrees as the plaza's car struck.

`tests/test_impact_shows.ae` strikes a figure 60 N·s at the chest as it
goes `POWERED` from `ANIMATED`:

| | before | now |
|---|---|---|
| the drawn hips' way against the pelvis body's, worst in 0.3 s | 3.4 cm | 0.9 cm |
| how much of the body's 7.2 cm the drawing has gone, 0.2 s in | 79% | 91% |

A twin `POWERED` all along draws its hips with its body to the millimetre.

## Stepping to catch itself

Pushed, a `POWERED` figure steps to catch itself (`set_stepping`, on by
default; `steps_taken` counts them). Every fixed step it watches its
capture point: the centre of mass carried on by its velocity times
√(height / g), where it would come to rest over a foot. A foot swings to
put itself under that point when two things hold:
- the point leaves the ground the two feet cover (heel under the ankle,
  toe 0.2 m ahead) by more than 24 cm, which is as far as the balance the
  pelvis keeps brings back without a step;
- the figure is moving over the ground at 0.25 m/s or more.

The thigh reaches toward the spot, within the hip's cone as the joint has
it (`physics.ragdoll_within_cone`: about the cone's own centre, an ellipse
for the hips, aephysics#129), with the knee bent for the first 0.12 s so
the foot clears the ground: 1.2 rad for a step aside or back, about a
person's swing knee at its most, and 0.6 for a step ahead (within 45
degrees of the way it faces), which swings under the body. On a person's
hips the stepping foot dragged at 0.5 and the box man stood out of 51 of
84 shoves (1.0 to 1.6 m/s, seven angles from the side, in front and
behind), against 82 now. Ahead, a knee lifted 1.2 left the foot up behind
as a fall forward cut its step short, and the figure dived onto its hands. Then the
leg straightens onto it. The whole step takes 0.3 s, and lands 5 cm past
the capture point, at most half a metre from under the hip.

Which foot moves:
- **Pushed forward:** the foot further behind swings through.
- **Pushed sideways:** the foot on that side steps out. Swinging the other
  across it only tangled the legs.
- **Pushed back:** it shifts its weight onto the stance foot first (0.12
  s, #578), then steps back. Pushed onto its heels, a figure stands on both
  feet, and a step back taken at once lifted neither. While the stagger
  goes mostly back (its backward speed over half its speed), the trunk
  bends forward over the hips, as a person's does stepping back: 0.2 rad
  at the chest and half that at the lower spine for each m/s it goes back,
  at most 0.2 (#642). Upright over its steps, the body's mass stayed over
  its heels and each step back landed short of a capture point still
  running away. The bend is let go once the stagger no longer goes back,
  and the moment the figure falls.
- **A push past two strides:** that's a fall, and the protective fall has
  it. At a stride and a half, the first step waited for the capture point
  to come back within reach (0.28 s after a 330 N·s shove), and the figure
  fell two steps later.

`tests/test_balance.ae` pushes figures at the chest, each push with and
without stepping, and sweeps the pushes from behind from 240 to 315 N·s
for where standing still gives out:

| push | without stepping | stepping |
|---|---|---|
| 60 N·s from behind | stands | stands, no step |
| 255 N·s from behind | stands | stands, 4 steps |
| 270 N·s from behind | falls | stands, 4 steps |
| 315 N·s from behind | falls | stands, 3 steps |
| 180 N·s from the side | stands | stands, 2 steps |
| 210 N·s from the side | falls | stands, 2 steps |
| 150 N·s from in front | stands | stands, no step |

How far each way holds:
- **Forward:** 255 N·s without stepping, 360 staggering
  (`tests/test_stagger.ae`).
- **Sideways:** 180 N·s standing still, 210 stepping. A step counts as
  backwards only when the capture point is mostly behind the rear foot. A
  side shove turns the figure a little and puts the capture point a little
  behind, and taken for a step back, that had stopped every step after the
  first. Catch steps that cross or close the feet are #481: tried, quicker
  steps and a closing step did not catch more, against a hip that turns 30
  degrees.
- **Backward:** the box man shoved from in front at 1.0 to 1.6 m/s, at
  seven angles from -30 to 30 degrees, stands out of 17 of the 28 shoves,
  against 12 upright over its steps; bent for any backward part of a
  stagger, and further (0.6 rad per m/s), side and forward staggers that
  turned a little bent too, and it stood out of fewer shoves every way.
  `tests/test_balance.ae` holds it to all seven at 1.0 m/s and 15 or more
  of the 21 from 1.0 to 1.4 (17 now), with the chest 3 cm or more ahead of
  the pelvis on average as it steps back from 1.0 (1.1 cm upright).

## Staggering

A shove one step does not catch, the figure staggers from
(`staggering(body)`). Once a step has been taken and the capture point is
still off the feet, the steps come in a run:
- each goes to where the capture point is by then;
- each is quicker than the first: 0.22 s long, 0.03 s apart;
- a step is backwards only when the capture point is behind the rear foot,
  and the way the figure faces is its pelvis's (not its chest's, which a
  shove from behind folds forward);
- the run goes on while the capture point is within three strides, and
  ends the moment it is not.

While it staggers, the protective fall waits until the figure leans past
0.5 rad (29°) rather than 0.35. A figure still catching itself is not yet
falling. It ends standing, or falls into the protective fall. Waiting to
46°, as first tried, brought the arms too late in shoves from behind that
the steps could not catch: over `tests/test_falls.ae`'s thirty falls
forwards, the protected head was the slower in 28, against 29 now.

`tests/test_stagger.ae` shoves figures from behind, each with and without
stepping, and runs the whole twice:

| shove | without stepping | stepping |
|---|---|---|
| 330 N·s | falls | staggers 4 steps (0.02, 0.35, 0.62 and 0.88 s after the shove), stands, and brings its feet together at 1.32 s |
| 390 N·s | falls | steps once at 0.2 s, then falls into the protective fall |

It holds:
- two or more steps for the 330 N·s shove, none in the first second more
  than 0.4 s after the last;
- the stagger over once it stands;
- on the second run, the same steps at the same fixed steps, and the same
  end to the bit.

Swept from 120 to 450 N·s, stepping stands to 360 and falls from 390.
Without stepping it holds 240.

## Writhing

Down and hurt, a `POWERED` figure writhes (`set_writhing(body, seconds)`,
off by default; `writhing(body)` says it is). It writhes for the seconds
it is given after it lands, then lies still and settles, so `set_get_up`
counts from then. A `LIMP` figure is past it.

- **The legs** draw up together and let down, once every 1.7 s: the hips
  bend forward 0.6 rad and the knees 0.2 at the top. The knees bent less
  than the hips lift the feet off the ground; a foot dragged along it
  pushed the figure across the ground.
- **The arms** fold over its front, toward where it was last struck: the
  shoulders forward 0.7 rad and in 0.3, the elbows 0.6, rocking 0.12 rad
  every 1.1 s. The reference ragdoll's shoulders and elbows turn too little
  for a hand to reach its own chest, so the fold is as far as they go.
- **It fades:** full for the first half of its time, then less and less.
- **Caught on its hands and knees**, as a figure not hurt is, it does not
  stay there. It lets go, down to 15% of its muscle and no balance, and
  goes down to writhe where it comes to lie.
- **Where it lands**, it writhes. Face down its legs draw up under it, the
  hips lifting off the ground as the knees come in, and its arms stay
  tucked. It used to turn over onto its back first: the arm on the higher
  side pushed the ground, the leg on that side crossed, the trunk twisted.
  With the figure at rest (#579), that only braced it against the ground,
  still for the whole of its writhing.
- **A limb a blow left weak**, or the struck arm, doesn't take part: shot in
  the arm, it clutches with the other.

The limbs that writhe have all of their muscle: at less, with the figure
at rest, the arms could not lift themselves over a chest lying on its
back. The rest keep 15%: a limb not aimed drives toward the standing pose
and, strong, would push the body over. Every bend is from the limb's rest
place under its parent, within its joint's cone. The shape it landed in is
let go while it writhes, since held it holds every joint whatever an aim
asks. Done, it holds the shape it ends in.

`tests/test_writhe.ae` knocks four figures down with 450 N·s:
- three from in front, onto their backs: one writhes for three seconds, a
  twin lies still, and a third is struck on the right forearm once down;
- a fourth from behind, onto its face, writhing where it lies.

| | Measured |
|---|---|
| the left hip's swing, 0.5 to 2.5 s after landing | 0.30 rad on its back, 0.43 on its face, 0 still |
| the left upper arm toward the chest's front (cosine) | 0.70 writhing, 0.70 struck on the right forearm, 0.01 at rest |
| the pelvis's drift from 1.5 s down to the end of writhing | 1.3 cm on its back, 1.0 cm on its face |
| it stops | 3 s after landing, down 0.15 s later |
| the struck arm | never aimed |
| the same run twice | the same to the bit |

The hip draws up 0.3 rad on its back and no further: the reference
ragdoll's hip turns 30 degrees about a cone that is not centred ahead of
the leg. More of a person's curl waits on that limit (#578).

The same test shoves sixteen writhers from eight directions, at 450 and
500 N·s (#480). All of them land, eight face up and eight face down. In
every one the hip swings at least 0.30 rad, the pelvis drifts no more than
7 cm, and the writhing stops when its time is up.

## Body parts

A part of a figure can have a mode and a strength of its own (#573). The
parts are the head, the spine, each arm and each leg (`PART_HEAD` to
`PART_LEG_R`).

```aether
motion.set_part_mode(body, motion.PART_ARM_L, motion.LIMP)        // a crippled arm
motion.set_part_strength(body, motion.PART_LEG_R, 0.3)            // a leg that will not hold
motion.set_part_mode(body, motion.PART_ARM_L, motion.ANIMATED)    // taken back
```

- **A limp part** hangs and swings from its parent and collides, as the
  ragdoll's arm does. On an `ANIMATED` figure the rest walks its clip on,
  and the limp part is drawn as its bodies hang, after the clip in the pose
  phase. On a `POWERED` one it has no muscle.
  - A limp bone's anchor joint is destroyed, not set to nothing: at nothing,
    its last spring impulse was still applied every sub-step, and it held an
    arm out on its shoulder's limit (aephysics#76).
  - It keeps a tenth of its joint's friction. At all of it (6.4 N·m at a
    shoulder) an arm let go of stayed held out where it was.
- **Taken back**, the part is drawn from where it hung to its clip over
  0.3 s, under an offset that fades, as the drawing does when a figure is
  struck (#581). Its anchors are made again where its bodies are.
- **A part's strength** is a lasting share of its muscle. Every drive the
  module sets goes through it, so a blow, a recovery or writhing never
  restores an injury. A game that clamped its crippled arm after every
  step no longer has to.

`tests/test_motion_parts.ae` holds a rig's arms 0.6 rad ahead as a clip
would:

| | Measured |
|---|---|
| `ANIMATED`, the left arm let go | it comes down 0.58 rad from its clip, the right stays within 0.011 of its; drawn within 0.014 rad of its body; the figure still on its clip |
| struck at the forearm, 8 N·s | the drawn arm swings over 0.2 rad |
| taken back | drawn to its clip with no more than 0.062 rad a frame, on it a second later; its body within 0.11 rad (it comes up with its elbow straight on its limit) |
| following, an arm held up ahead | 0.059 rad from its anchor, the sag the anchor's 5 Hz allows |
| `POWERED`, the right arm at 3% | 3% of the left's muscle before a blow and after it and its recovery |
| `POWERED`, the left arm limp | no muscle; it comes down 0.69 rad while the right holds |

While a figure follows its clip, each joint's spring pulls toward the
clip's pose, with the anchors (#584). Its 8 Hz used to pull toward the
reference pose against the anchors' 5 Hz: a healthy arm held up ahead
trailed its clip by 0.14 rad, and an arm taken back stopped 0.25 short.
Springs off instead, an arm sagged from its keys through a get-up, and
when the figure went `POWERED` at the end it snapped up 8 degrees a step.

**A `POWERED` part on an `ANIMATED` figure** (#658) is on its own muscles
while the rest walks its clip:
- the part's bodies, and every body hanging from them, lose their anchors;
- each joint's motor drives it toward the clip's turn there, within the
  bone's muscle, as a `POWERED` figure's joints are; the clip's turn is
  handed to physics in the pose phase, before the bone is drawn over it;
- `hit` pushes the part and the muscle brings it back, while the pelvis
  and the legs stay on the clip;
- it is drawn as its joints bend, from its parent as drawn. Drawn in the
  world from its bodies instead, the chest carried the anchored pelvis's
  sag up to the head, 2 cm aside;
- given back to `ANIMATED`, it is drawn back to its clip over 0.3 s, as
  from limp.

The bones hanging from the part go on their muscles with it: held to the
clip by world anchors, the arms would hold a swaying chest where the clip
had it. A heavier blow can still take the whole figure `POWERED`.

`tests/test_part_powered.ae` stands the pipeline's rig on its clip, spine
and head `POWERED`, and jabs it in the face, 20 N·s at a cost of 0.1:

| | Measured |
|---|---|
| standing on its muscles | the head drawn 0.001 cm from the clip's |
| jabbed | the head drawn back 3.3 cm, the pelvis on its clip, the figure `ANIMATED` (no part powered: 0 cm) |
| 0.9 s on | the head 0.013 cm from where it stood |
| given back | no step over 0.001 cm; the clip's to 1 mm |

How far the head goes hardly depends on what the blow costs (3.6 cm at a
cost of 0.6). A muscle here is a velocity servo, rigid within its torque,
and real muscle gives more (#661). A limp part drawn during a get-up is not
there yet.

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
- dressed, each faces within 1.5° of its object's turn;
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
| 0 | 0.4 µs | | |
| 4 | 236 µs | 59 µs | 17 |
| 16 | 598 µs | 37 µs | 27 |
| 32 | 1080 µs | 34 µs | 30 |

A figure standing still falls asleep and costs nothing, which is why the
figures bow: an awake figure is what the step pays for. A dozen awake
figures cost about 0.45 ms a step. The test holds a figure under 80 µs, a
dozen within a millisecond, and every figure still standing at the end.

A world holding a powered figure steps in 8 sub-steps rather than 4 (see
[At rest](#at-rest)): at 4 the same figures cost 23 µs each at 32.

## At rest

A powered figure standing untouched is still (#579). At 4 sub-steps a
step, a joint's constraint, at its 60 Hz, sat on the solver's limit of a
quarter of the sub-step rate, and against the motors' drive it rang. Every
body of a figure standing untouched turned at 0.56 rad/s on average and
1.6 at most, and every powered figure visibly trembled. A world holding a
powered figure now steps in 8 sub-steps:

| | on average | at most |
|---|---|---|
| 4 sub-steps | 0.56 rad/s | 1.59 rad/s |
| 8 sub-steps | 0.0035 rad/s | 0.04 rad/s |

What else was tried:
- **A slower drive** (the motors closing the gap in 0.15 s, not 0.05)
  quietened it to 0.14 and left five suites failing.
- **Softer joints** (20 Hz at 4 sub-steps) quietened it to 0.001, but the
  limbs went too soft to writhe or to catch a fall.

`tests/test_motion_rest.ae` holds a figure standing from 1 s to 5 s under
0.05 rad/s on average and 0.2 at most. Before, it measured 0.56 and 1.59.

Some of what the stagger and writhing did had come from the trembling, and
went with it:
- **Balance read the chest for the way the figure faced.** A shove from
  behind folds the spine forward, and leveled, the chest's front pointed
  back the way the figure came. A stagger's second step was taken for a
  step backwards. Balance now reads the pelvis.
- **Writhing turned a face-down figure onto its back** with the trembling's
  help. Without it, the push only braced the figure against the ground.

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

A networked horde hands over too, on every peer (`ae3d.nethandover`, #466; [networking.md](networking.md#struck-zombies-handed-to-ragdolls-on-every-peer)): the strike and the giving back are the horde's inputs, so every peer takes the same zombie out at the same tick and puts it back to the same bits; the host's pool simulates the ragdoll, and every client poses a figure of its own pool from the ragdoll's bones as it draws them (`puppet`, `puppet_pose`, `puppet_end`). `renumber` follows a zombie the horde's compaction moves, and `set_on_despawn` says when a killed one's figure is parked.

## What it is held to

`tests/test_motion.ae` runs eleven figures on one ground, each dressed in a humanoid rig:

| Figure | Measured |
|---|---|
| the tracker, its rig bowing the chest 15° forward and back | the chest within 1.6° of its pose; the figure never leans more than 1.2° |
| the shoved, 60 N·s to the chest | knocked 23.6° off its pose, back within 0.1° and upright three seconds later |
| the felled, 400 N·s to the chest | down |
| the struck, 8 N·s to the right upper arm | its muscle at 5% (the forearm's at half), then back to full |
| the limp | down |
| three protected fallers, felled by 400 N·s from the front, from behind and from the side | the hands reach the ground (at steps 103, 86 and 88) and the head never does |
| their unprotected twins | the head meets it at 2.60, 1.82 and 4.23 m/s |
| the protected fallers, landed | each lets go and lies |
| the felled, as drawn | its drawn hips at 0.45 m, with its pelvis body: down on its knees (a standing figure's are above 0.8 m) |

The shoved never takes itself for falling. Hands and head are measured by their capsules' lowest points (the forearm's, which reaches the hand, and the neck bone's, which is the head). One fall a way is one fall's chance: how the protected head compares with its twin's is `tests/test_falls.ae`'s, over thirty falls each way (above).

Pose error is measured per joint (a bone against its parent), which is what a muscle answers for. The lean is the pelvis's up against the animation's. A figure turned about the vertical is still on its pose.

## Next

As #414 lays out:
- balance by feedback on the hips and the stance foot, stepping when the centre of mass leaves the feet;
- writhing in every way a figure lands (#480), and sideways staggers (#481);
- get-up clips from the pipeline in place of the keyed ways up, once a figure has them;
- the inspector's section, with a Hit button in the viewport;
- drawing a powered figure's bodies each frame rather than each step, for an animation that plays on while its muscles track it.
