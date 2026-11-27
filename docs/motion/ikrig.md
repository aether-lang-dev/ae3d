# IK: ikrig

`ae3d.ikrig` is the animator's last word on a pose before it is drawn: the clip said where the limbs go, the world says where they can. In the animator's order: feet, the trunk's aim, the whole body, hands, look. Each solve works on poses in the rig's space and writes nothing to the figure itself. The program is [`examples/docs/ik.ae`](../../examples/docs/ik.ae). Issue: #857.

## Feet on any ground

<!-- example: examples/docs/ik.ae#feet -->
```aether
f = ikrig.feet_new(r, o)
ikrig.feet_ground_physics(f, physics.of(e))            // soles traced on the static world, not a flat floor
ikrig.feet_set_steps(f, true)                          // a turn on the spot is stepped, one foot at a time
animator.set_feet(a, f)                                // the animator's now, freed with it
```

What the feet do each step:
- **Trace the soles.** Each sole at its heel, its pad and its toe, where the IK puts the foot (not where the clip has it), by a ray from 0.6 m over it looking 1.6 m down (`LOOK_UP`, `LOOK_DOWN`), ground steeper than 50 degrees passed over (`STAND_UP`, its cosine 0.64: taken as ground, the rounded flank of a seat log 53 degrees steep stood a heel for 0.2 s, #934). One surface under a foot is a plane it is laid on, its ankle stood off along the normal; an edge under it is a stair's, the foot level on the higher side and rested on the edge's corner, found by halving. A foot in the air looks a foot's length ahead for an edge its toe would meet.
- **Lock a planted foot.** While the take has a foot down, the foot is locked where it came down: its ankle from the heel's strike, its toe's tip once the take plants it. When the leg cannot reach as the body passes, the heel peels up about the toe instead of sliding (foot roll, as in Unreal's leg IK). Let go over 0.15 s (`RELEASE`) once the take lifts it.
- **Lower the pelvis** by what the lower foot and each leg's reach need, on a spring, no faster than 0.6 m/s while the figure stands (`STAND_DROP_SPEED`, the retired feet module's `PELVIS_SPEED`), so ground falling away under a standing foot never snaps the body down.
- **Solve each leg as a limb** (below), its reach eased off from 0.97 of its length (`SOFT_FROM`, or the clip's own stretch where that is straighter), so a knee slows into straight instead of snapping the last few degrees in a frame.
- **Put the foot on the ground by the lowest point of its sole** after the leg is solved, its toes bent up at the ball until they are out of it: the walk's own clip, rolled off its toes, put them 29 mm into the floor.
- **Step on the spot** (`feet_set_steps`, #827, #984): a planted foot keeps its heading as the body turns above it; turned past what it can twist, it is lifted and set down where the take has it, in one pivot on a ball up to about 180 degrees, the eyes, chest and hips leading.
- **Cut a stride** (`feet_set_stride`, as Unreal's animation warping): each step nearer the hips along the way the figure faces, the take's cadence kept, so steps fit a stair's treads.
- **Stand on a stance** (`feet_set_stance`, `feet_set_stance_by`, `feet_set_stance_ease`): a stop brings each foot to the stand's stance by its last step ([character.md](character.md#starts-and-stops)).

The figure's object stepping up a stair at once leaves the feet and the pelvis where they were in the world, eased to their new heights from there.

## Limbs and chains

- **Two-bone limbs** (`leg_limb`, `arm_limb`, `limb_solve`): a knee or an elbow bends the way its clip bends it off the clip's own hip-to-foot line, turned onto the line to its target; measured off that new line, a knee whose foot a lock held caved in 33 degrees, and bent by the thigh's twist alone it swung out 90. The hinge's axis is read off the rest pose in the upper bone's own frame, so it turns with the thigh's twist and a straight knee never flips. No knee or elbow bends past 150 degrees (`KNEE_MOST`, `ELBOW_MOST`, 2.618 rad), a knee never bends backward, and a target nearer than the joint lets the end come is reached as near as it comes. Of the twist the end's turn asks beyond the clip's, the forearm takes half (`ARM_TWIST`).
- **Chains** (`chain_solve`): FABRIK (Andreas Aristidou and Joan Lasenby, "FABRIK: A fast, iterative solver for the Inverse Kinematics problem", Graphical Models 73(5), 2011) over any parent chain, a spine's or a tail's, each joint held within a cone of the pose's own bend.

<!-- example: examples/docs/ik.ae#limb -->
```aether
leg = ikrig.leg_limb(r, 0)                             // the left leg: thigh, calf, foot
p = pose.new(r)
pose.copy(r, animator.pose_now(a), p)
pose.world(r, p, w)
foot = pose.human(r, pose.FOOT_L)
ankle = pose.translation(w, foot)                      // the rig's space
ankle = core.v3_add(ankle, ikrig.dir_to_rig(r, core.vec3(0.0, 0.2, 0.0)))   // 20 cm up the ground's up
reached = ikrig.limb_solve(leg, r, p, w, ankle, pose.rotation(w, foot))     // the foot kept as it was turned
```

## The whole body, aim, look, hands

<!-- example: examples/docs/ik.ae#body -->
```aether
b = ikrig.body_new(r)
animator.set_body(a, b)
low = core.v3_add(core.vec3(0.0, 0.4, 0.0), core.v3_mul(ahead, 0.6))
ikrig.body_set(b, ikrig.BODY_HAND_L, low, 1.0)         // low and ahead: the spine bends, then the hips
```

- **The whole body** (`body_new`, `body_set`, `animator.set_body`): four ends with points and weights. What the hands cannot reach from the shoulders bends the spine toward them (a chain from the pelvis to the chest, within `SPINE_CONE` 0.35 rad a joint), what is still out of reach moves the pelvis as far as the held feet let it, then each limb is solved onto its point.

<!-- example: examples/docs/ik.ae#aim -->
```aether
target = core.v3_add(core.vec3(0.0, 2.0, 0.0), core.v3_mul(ahead, 10.0))
animator.aim_at(a, target, 1.0)                        // the chest's forward turned onto a point, shared up the spine
animator.look_at(a, target, 1.0)                       // and the head onto it, within its limits
```

- **Aim** (`animator.aim_at`, `ikrig.aim_set_line`): a line held on the chest (a rifle's, from its butt; the chest's forward by default) turned onto a point, at most 1.2 rad (`AIM_MOST`), the turn shared up the spine. Hands held on a joint go on the rifle where the aim put it in the same solve.
- **Look** (`animator.look_at`, `look_off`; `character.look`): the head's forward turned onto a point within 1.3 rad either side of the way the figure faces (`LOOK_YAW_MOST`), 0.6 up and 0.8 down, turning toward a new way at no more than 5 rad/s (`LOOK_TURN`) for the whole turn; past the side's limit it lets go over 0.6 rad (`LOOK_FADE`), so a point behind is not looked at. The chest, the neck and the head share it. The eyes lead and the head turns 0.07 s after them (`HEAD_LAG`; 50 to 100 ms in people: Zangemeister and Stark 1982, Freedman 2008, as the code cites them), the eyes turning up to 0.7 rad from the head's way (`EYE_RANGE`; an eye's own range is 35 to 45 degrees). The retired `ae3d.lookat` did this on bones; `tests/test_lookat.ae` holds the animator's look to its numbers.

<!-- example: examples/docs/ik.ae#hands -->
```aether
h = ikrig.hands_new(r)
animator.set_hands(a, h)
grip = core.v3_add(core.vec3(0.0, 1.1, 0.0), core.v3_mul(ahead, 0.4))
ikrig.hands_set(h, 1, grip, 1.0)                       // the right hand (1) on a grip in the world, 40 cm ahead
```

- **Hands** (`hands_new`, `hands_set`, `hands_set_on`): hands on grips in the world, or held on a joint (`hands_set_on`: a rifle on the aimed chest), the fingers wrapped round a handle (`hands_wrap`), an index on a trigger (`hands_trigger`). A load in the hands (`hands_load`) leans the trunk away from it and slows the character ([character.md](character.md)).

## What it is held to

`test_anim_pipeline` (2026-11-19, `bea4c991`):

| | measured | held to |
|---|---|---|
| a planted toe's slide, feet locked, 1 / 2 / 4 / 6 / 8 m/s (the same with no IK) | 0.45 / 0.12 / 0.41 / 0.73 / 4.39 mm (13 / 20 / 33 / 26 / 53 mm) | 5 mm |
| one foot over a 10 cm block: its sole, the other's, the fastest turn getting there | +100.6 mm, 0.002 mm, 4.4 degrees a step | 5 mm, 5 mm, 6 degrees |
| turned 90 and 180 degrees on the spot: steps; a planted toe's slide; a step's lift | 1 step each; 2.9 to 3.1 mm; 54 mm | one step; 5 mm; 30 mm or more |
| turning: a foot past the hips' middle | never (4.7 cm short of it at worst) | never |
| walking with a bowl: each hand off its grip; the elbows | 2.0 mm; 122 to 159 degrees | 5 mm; within the limits |
| a 6 kg parcel in two hands: each palm off its hold; the trunk's lean back | 0.16 mm; 5.35 to 5.40 degrees | 5 mm |

`test_ik_constraints` (the Rigify mannequin, 22 checks; 2026-11-19, `bea4c991`):

| | measured | held to |
|---|---|---|
| walk, jog, crouch and idle, feet locked, hands on a bowl: the most a knee and an elbow bend; a knee behind straight | 133 and 150 degrees; 0 mm | 150 degrees; 1 mm |
| a hand asked to its own shoulder, a foot to its hip: the elbow, the knee | 150, 150 degrees | stopped at 150 |
| a hand turned 90 degrees about its forearm: off its grip; what the wrist took | 3.3e-5 mm; 44.3 degrees | 5 mm; 40 to 50 degrees |
| a FABRIK spine bowing the head 10 cm forward and 2 down: off the point; the bones' lengths | 0.51 mm; 1.8e-13 mm | 1 mm; 0.01 mm |
| a hand 15 cm past its arm's length, the whole body reaching: off the point; at half weight off half way; the feet | 1.0e-6 mm; 1.2e-7 mm; 4e-13 mm | 5 mm; 5 mm; 1 mm |
| a rifle aimed 40 degrees right and 15 up at 10 m: the barrel; the hands off their grips; the elbows | 0.15 degrees; 0.0023 mm; 123 degrees | 1 degree; 5 mm; 150 |
| two bones swept over 1,600 targets: the bones' lengths; the most bend | 2.8e-13 mm; 150 degrees | |
| walking on flat ground: a sole into the floor, the walk alone and with ikrig | 29.0 mm and 0.0075 mm | 5 mm |
| five 0.2 m stairs a step deep, up and down: a planted sole off; a sole into it; the knees | 0.54 mm; 0.096 mm; 113 degrees | 1 cm; 5 mm; 150 |
| five 0.2 m stairs 0.3 m deep, the stride cut to 0.40: the same | 1.93 mm; 1.93 mm; 127 degrees | 1 cm; 5 mm; 150 |
| a 20 degree ramp up and down at 0.7 of the stride: a foot down's sole off it; into it; a flat foot's heel and pad off the clip's heights | 4.58 mm; 0.0075 mm; 0.56 mm | 1 cm; 5 mm; 5 mm |

The retired feet and look modules' numbers, which the ikrig feet and the animator's look are held to (each as written into the docs at the commit named):
- `tests/test_feet.ae` (the Rigify mannequin, no window): on a 15 degree slope across the stance each sole within 2.7 mm of it, the pelvis down 4.3 cm for the lower foot; stood on a 20 cm kerb with the plank under its other foot taken away, that foot reaches the road and the pelvis comes down 20 cm at 1 cm a frame at most (on the spring alone, 3.6 cm a frame) (`7909fb52`, 2026-11-18).
- `tests/test_hips_writers.ae`: walking on a 10 degree slope across its way, stopping and setting off every second for 12 s, standing at the end of each second the pelvis, less the drop, is where it was the second before to 0.6 mm (`7909fb52`, 2026-11-18).
- `tests/test_lookat.ae` (the box man's idle beside a twin with no look): a point 31 degrees aside faced to 0.29 degrees; a point 86 degrees aside holds the way at 1.3 rad; the head turns 5.6 degrees a frame at most, the clip included; cleared, back on its clip exactly; no joint outside the chest, neck and head moves (`de44af6e`, 2026-11-18).

## Costs

Per solve, `test_ik_constraints` on 2026-11-19 at `bea4c991` (the pose's copy taken off): two bones 0.0044 µs, a limb 0.24 µs, a FABRIK spine of 5 joints 19.0 µs, the whole body reaching past its arm 12.8 µs, the look 2.65 µs, the aim 2.11 µs. A figure's feet, the heaviest part of a figure's frame, cost 20.7 µs after their ground reads were halved (97 to 53 rays a figure a frame; #862, 2026-11-10, `bench_animlod`).

## State

`ikrig.feet_state_write` (in the animator's state, up to `FEET_STATE_MOST` floats): each foot's lock (the point it is held by, heel or toe, and its heading), its release and step in progress, the pelvis's drop and its spring, the turn on the spot under way. `look_state_write` and `aim_state_write` carry the look's and the aim's current ways. A late joiner missing the feet's state had a turn-on-the-spot join apart by 0.2 mm and 0.04 degrees (#858, 2026-11-19).

## Limits and known issues

- One foot system: `ae3d.motion`'s keyed feet and `physics.ragdoll_plant_foot` still to retire onto ikrig (#857, #860).
- Walking a 20 degree ramp at the walk's full stride, the trailing toe stands 16 mm off the slope; the test walks it at 0.7 of the stride (#857).
- A reach across the trunk: the forearm rests 22 cm short of a wound on the other arm (#700).
- `toes_flat` bends a lifting foot's toes 0.67 rad in one frame (#1017); `feet_reset` lays a foot flat in one frame and a locked foot drifts round its toe (#995).
- Cross-slopes and risers: #1008, #1007. Knees out on several figures, a sharp turn crossing the feet: #969, #977.
- The owner's review: hands limp at the wrists (#1011), legs flickering (#1012), the head hanging forward (#1013).
