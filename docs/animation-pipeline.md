# The animation pipeline

ae3d's animation is a pipeline of layers, the way shipped engines build it (#853). Each frame a figure's animator evaluates one pose, and that one pose is written to the figure's joints. Games set parameters and never write bones. Before it, seven modules wrote the same scene-graph bones and found each other by comparing floats; the old modules are frozen and are retired by #860.

| layer | module | what it does |
|---|---|---|
| L0 | `ae3d.pose` | A rig is a skin's joints read once, or a motion capture's skeleton: names, parents, parents-first order, rest pose, and a map onto one humanoid layout (the UE5 mannequin's 53 slots, fingers included) from UE5, Rigify, Mixamo or Xsens (BVH) naming. A pose is ten floats a joint, flat. Blends, masks, additive differences, model space, and the mirror (left for right). |
| L0 | `ae3d.bvh` | Motion capture read from BVH files: the skeleton and its channels, End Sites as joints, units found from its height. |
| L0 | `ae3d.retarget` | A take made on one humanoid played by another: facings and rest poses aligned, turns carried in the ground's space, the pelvis scaled by the two figures' pelvis heights, the feet kept on their contacts (a planted toe's tip held on the source's ground, the legs solved by IK, the pelvis lowered where they cannot reach), and a root made under the hips for a capture that has none. |
| L1 | `ae3d.clips` | A take is an animation resampled for a rig at the file's key rate. Read from it at import: foot contacts, planted frames, its speed over the ground, its heading, footfall sync markers and footfall events. Loops sealed. Root motion taken out with the root locked to the rest pose, straightened for a blend space, mirrored. |
| L2 | `ae3d.animator` | The single writer, a graph of states over pose buffers: a take (by its clock, or by a distance: `clock_by`), a blend space along one parameter or over the ground's two directions, a motion matcher, a held pose. Named parameters a game drives it by; transitions it takes itself on their conditions, inertialized or cross-faded, in step with the stride, to whichever of several states' feet match; masked and additive layers, aim offsets, events, root motion onto the figure's object or through its character controller. |
| L2 | `ae3d.mover` | The controller a game drives with a velocity (and a facing, strafing): Holden's springs move the figure and feed the graph its parameters (its velocity in its own frame, speed, the way come and the way left to rest); braking at a stop's own rate; or following its clips' root motion, the springs a simulation the figure is eased toward. |
| L3 | `ae3d.ikrig` | Feet on the ground (ground height under each foot, pelvis drop, the foot locked where the clip plants it, the heel peeled up when the leg cannot reach), two-bone legs and arms with soft reach, hands on a prop's grips, the head turned to a point. |

## A figure on its gaits

```aether
o = figure.figure(e, "Runner", "people/runner.glb")
a = animator.attach(e, o)                       // the figure's joints are the animator's now
move = animator.add_blend(a, "move")
names = ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]
k = 0
while k < 3 {
    t = animator.take(a, names[k], false)        // loaded once, freed with the animator
    animator.blend_add(a, move, t, clips.speed(t))   // each gait at its own measured speed
    k = k + 1
}
idle = animator.add_state(a, "idle", animator.take(a, "Idle_Loop", false), true)
animator.set_feet(a, ikrig.feet_new(animator.rig(a), o))
animator.play(a, idle, 0.0)

// Each frame, from the game: the speed the figure moves at.
animator.set_param(a, move, speed)
if speed > 0.25 && animator.current(a) != move { animator.play(a, move, 0.35) }
if speed < 0.1 && animator.current(a) == move { animator.play(a, idle, 0.4) }
```

A take made for another rig goes in with `animator.add_take(a, retarget.retarget(source, take, animator.rig(a)), false)`.

## Motion capture

A capture in BVH is read as a rig of its own and a take for it, retargeted onto the figure, its root motion taken out, and straightened when it is a gait for a blend space:

```aether
c = bvh.load("tests/fixtures/people/100style/neutral_fw.bvh", 0.0)   // centimetres found from its height
made = bvh.take(c, "walk", 0, 0 - 1)
walk = animator.add_take(a, retarget.retarget(bvh.rig(c), made, animator.rig(a)), true)
clips.straighten(walk, animator.rig(a), true)    // no turn; on the nearest of forward, back, left, right
clips.take_free(made)
bvh.capture_free(c)
```

The capture's skeleton has no root, so the retargeter makes one on the ground under the hips, its place and heading averaged over 0.4 s either side so it does not sway with each step, and the root motion is taken from it. The root is locked to the rest pose: whatever place and heading the actor had in the capture volume, the figure is drawn on its object and its travel is along its own facing. On a figure with a character controller (`physics.character_controller`), root motion moves the capsule, so a wall stops it.

`tests/fixtures/people/100style` holds cuts of the 100STYLE dataset (Ian Mason, CC BY 4.0): walks and runs forward, back and sideways, each whole strides where its travel and hips keep their direction, turns, a stop and a start. `tools/bvh_cut.ae` cuts frames from a take unedited; the folder's README names the source frames.

## Events, loops and mirrors

- Footfalls are found at import as events (`clips.FOOT_LEFT`, `clips.FOOT_RIGHT`), and a program adds its own (`clips.add_event`). The animator fires each as its clock passes it, a blend's from its heaviest take; a game asks `animator.fired(a, "cue")` after the pose phase.
- A take that loops is sealed at import, as Unity's Loop Pose does it: the gap between its last frame and its first is spread over it, so it never snaps as it wraps.
- `pose.mirror` and `clips.mirror` swap left for right: each joint's turn from its rest pose is reflected onto its other side's joint (names with left and right swapped), and its place reflected. A walk leading with its left foot leads with its right.
- A capture becomes a loop with `clips.loop_cut`: the two frames at least 0.6 s apart whose feet, hands, head and pelvis match best in place and motion, cropped and sealed. `clips.straighten` lays its path on the root's own frame and, `cardinal`, onto the nearest of forward, back, left and right, poses and path turned together.

## The graph, and a figure on a stick

A game drives a figure with `ae3d.mover` and lets the graph choose its clips:

```aether
move = animator.add_blend2(a, "move")               // each gait at its velocity: x to the left, z ahead
animator.blend_add2(a, move, walk_ahead, 0.0, 0.8)
animator.blend_add2(a, move, step_left, 0.51, 0.0)
animator.bind2(a, move, "vx", "vz")                  // the mover writes these
start = animator.add_state(a, "start", start_take, false)
animator.clock_by(a, start, "travelled", false)      // played by the way come
stop = animator.add_state(a, "stop", stop_take, false)
animator.clock_by(a, stop, "rest", true)             // played by the way left to rest
go = animator.add_transition(a, idle, start, 0.2)
animator.transition_when(a, go, "go", animator.IS, 0.0)
on = animator.add_transition(a, start, move, 0.3)
animator.transition_when(a, on, "", animator.ENDED, 0.0)
animator.transition_synced(a, on, true)              // the gaits take over in step
halt = animator.add_transition(a, move, stop, 0.25)
animator.transition_when(a, halt, "go", animator.IS_NOT, 0.0)
animator.transition_when(a, halt, "rest", animator.BELOW, clips.travel_length(stop_take))
animator.transition_or(a, halt, stop_on_the_other_foot)   // whichever's feet match
m = mover.mover_new(a, o)
mover.set_braking(m, clips.braking(stop_take))       // it comes to rest as the stop does
// Each frame: the stick.
mover.ask(m, velocity)
mover.step(m, dt)
```

- **Blend spaces in two directions** are weighted by polar gradient bands (Johansen 2009, Unity's freeform directional): between two samples of a speed, a direction blends them at that speed. The takes play in step by their footfalls, paced so their blended velocity is the one asked.
- **Starts and stops by distance** (Paragon, GDC 2016). A start is played by the way the figure has come since it stood, a stop by the way left to where the mover brings it to rest, so its feet plant where the clip planted them whatever the braking. The mover brakes at the stop take's own deceleration, so the stop enters with its feet where the walk's are in the stride; of a stop and its mirror, the transition takes the one whose feet match.
- **Turning on the spot in steps** (`ikrig.feet_set_steps`, #827). A planted foot keeps its heading as the body turns above it; when it is twisted or moved too far, it is lifted and set down where the clip has it, one foot at a time, begun on the twist it will have half a step on.
- **Motion matching** (`add_matcher`; Clavet, GDC 2016; Holden). Every frame of its takes is known by its feet's places and velocities, its hips' velocity, and where its root will be and face a third, two thirds and a whole second on; every 0.1 s the frame nearest the pose drawn and the way ahead the mover predicts is played, changing only for a clear gain and only to a frame that keeps each planted foot planted. With `mover.set_follow`, the figure goes by its clips' root motion and the mover's springs are a simulation it is eased toward.
- **Aim offsets** (`add_aim`): poses aiming at their yaw and pitch, blended at the aim asked and added over the spine.
- **A pose held** (`snapshot`): the pose drawn now as a state, what a get-up blends out of.

`tools/anim_showcase.ae`'s fifth figure (`AE3D_WATCH=5`) is this graph on the UE5 mannequin: it stands, walks, steps left and right facing ahead, runs, stops, turns round on the spot, and walks back aiming.

## The techniques, and where they come from

- **One pose, one writer.** This is Unreal's pose buffers, Unity's Playables and ozz-animation. It ends the class of bugs where one system draws over another.
- **Inertialized transitions** (Bollo, GDC 2018, Gears of War 4). At a change, the new state plays from where it enters. The offset from the pose drawn the frame before, and its speed, decay along a quintic. Only one clip plays, and no foot is dragged between two strides.
- **Sync markers.** A blend space's takes share a phase that runs from each take's left footfall (0) to its right (0.5), the way Unreal's sync groups keep markers. Every left foot of a blend comes down together, and every right foot does too. `play_synced` hands one gait to another at the stride's phase.
- **Speed matching.** Each take's speed is measured at import, from its planted feet's travel. Planted means flat for a gait that puts its feet down flat, and on the ball for one run on the forefoot. A blend picks its weights by speed and bends its pace so the feet carry the ground at the speed the figure moves.
- **Foot locking with toe pivots and foot roll.** A planted foot is locked on what is on the ground: its ankle from the heel's strike, its toe's tip once the clip plants it. When the leg cannot reach as the body passes, the heel peels up about the toe instead of letting it slide (foot roll in Unreal's leg IK).
- **Soft IK.** A leg's reach eases off from 97% of its length, or from the clip's own stretch where that is straighter, so a knee never snaps straight.
- **Retarget poses.** Rest poses are aligned per bone before any motion is carried, as Unreal's IK Retargeter does with a retarget pose.
- **IK goals in retargeting.** The feet are kept on their contacts, as Unreal's IK Retargeter keeps its goals: a planted toe's tip is held where the source planted it, on the source's ground (still under a capture, going back under a clip made in place, carried by the root where its motion was taken out), each leg reaches for its goal by two-bone IK, and the pelvis comes down where a leg cannot reach. The retargeted take keeps the source's contacts.
- **Planted means still.** Over a still ground, a foot that is low and flat is planted only while it does not move: a capture's shuffle as the actor turns is not a stance.

## What it is held to

`tests/test_anim_pipeline.ae` holds the layers to these numbers, on the Quaternius mannequins and their authored clips (`tests/fixtures/people`, CC0):

| | measured | held to |
|---|---|---|
| a take against the figure's own sampler, any joint | 0.027° | 0.1° |
| a planted toe's slide, feet locked, 1 to 8 m/s | under 10⁻¹² mm | 5 mm |
| the blend's feet against the speed asked, 1 to 8 m/s | 0% | 1% |
| idle to sprint and back, the fastest joint turn | 35.80 rad/s | the takes' own 35.54, plus 2% |
| a retargeted walk's segments against the source's | 0.00005° | 0.5° |
| the female's planted toe on retargeted gaits | under 10⁻¹² mm | 5 mm |
| the roll's root motion carried onto the object | 4.9914 of 4.9914 m | 1% |
| one foot over a 10 cm block: its sole, the other's, the fastest turn | +100.0 mm, 0.0 mm, 4.4° a step | 5 mm, 5 mm, 6° |
| walking with a bowl in both hands: each hand off its grip, the elbows | 2.0 mm at worst, 122 to 159° | 5 mm, 25 to 172° |
| a rest pose against its mirror; a walk mirrored twice | 0.021°; 3·10⁻⁶° | 0.5°; 0.001° |
| an event at 0.25 s over three cycles of the walk | fired 3 times | once a cycle |
| a loop's last frame against its first, after sealing | 2·10⁻⁶° | 0.1° |
| a 53-joint take sampled for one character | 0.32 µs | 20 µs |
| the roll on a character controller: open ground; a wall 2 m on | 4.991 of 4.991 m; stopped at 1.705 m | 1%; at the wall |
| 100STYLE's walk, run and backward walk onto the UE5 mannequin, turned bone by bone: every bone against the source's | 1.6° at worst | 2° |
| with the feet kept: a planted toe's slide a stance | under 10⁻¹¹ mm (11.0 mm turned bone by bone; the capture's own 5.6 mm) | 5 mm |
| the root made under the hips: its root motion against the hips' travel | 1.786 of 1.786 m | 1% |
| the head as it stands after retargeting, against the capture's | 1.2·10⁻⁶° | 2° |
| the 2D blend at 8 directions by 0.6, 1.0 and 1.3 m/s, feet locked: a planted toe's slide; the speed against the speed asked | under 10⁻¹¹ mm; 0% | 5 mm; 1% |
| a graph of idle, gaits and a roll driven by its parameters alone: its fastest joint turn | 32.6 rad/s (the takes' own 38.7) | the takes' own, plus 2% |
| halfway through a 0.6 s cross-fade: from each state, the two 83° apart | 42° and 43° | between a fifth and four fifths of it |
| a pistol's aim offset aimed down, level, up: the hand's height | 0.90, 1.40, 1.80 m | in that order; level, the pose unchanged |
| stand, start, walk 4 s, stop on a mover (feet locked): a planted toe's slide | under 10⁻¹¹ mm | 5 mm |
| half a turn on the spot in steps: a planted toe's slide; the hips off their spot; the degrees a step | under 10⁻¹¹ mm; 5.3 mm; 26° in 7 steps | 5 mm; 5 cm; 45° |
| motion matching through a stand, a walk, a side step, a turn and a stop: the frame played's root velocity walking, stepping left, at rest | 0.69 m/s ahead, 0.48 m/s left, still | a walk ahead, a step left, still |

`tools/anim_showcase.ae` puts four figures on these layers for a person to watch. Its runs measure the toes as the test does: through a 20 s cycle of starts, stops, accelerations and a circle, a planted toe slides under 10⁻¹¹ mm. The fourth walks 100STYLE's captured forward and backward walks out along a line and back on a character controller, by root motion.

## Next

- Motion matching on a database of the style's whole takes, its changes held to the takes' own joint speeds (today's database is one short take of each motion).
- Full-body IK and aim constraints (#857).
- The physics asset and physical animation (#858), then ragdolls and get-ups into matched clips (#859).
- The plaza, the motion showcase and Siltreach moved onto the pipeline, and the old writers retired (#860).
