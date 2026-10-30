# The animation pipeline

ae3d's animation is a pipeline of layers, the way shipped engines build it (#853). Each frame a figure's animator evaluates one pose, and that one pose is written to the figure's joints. Games set parameters and never write bones. Before it, seven modules wrote the same scene-graph bones and found each other by comparing floats; the old modules are frozen and are retired by #860.

| layer | module | what it does |
|---|---|---|
| L0 | `ae3d.pose` | A rig is a skin's joints read once, or a motion capture's skeleton: names, parents, parents-first order, rest pose, and a map onto one humanoid layout (the UE5 mannequin's 53 slots, fingers included) from UE5, Rigify, Mixamo or Xsens (BVH) naming. A pose is ten floats a joint, flat. Blends, masks, additive differences, model space, and the mirror (left for right). |
| L0 | `ae3d.bvh` | Motion capture read from BVH files: the skeleton and its channels, End Sites as joints, units found from its height. |
| L0 | `ae3d.retarget` | A take made on one humanoid played by another: facings and rest poses aligned, turns carried in the ground's space, the pelvis scaled by the two figures' pelvis heights, the feet kept on their contacts (a planted toe's tip held on the source's ground, the legs solved by IK, the pelvis lowered where they cannot reach), and a root made under the hips for a capture that has none. |
| L1 | `ae3d.clips` | A take is an animation resampled for a rig at the file's key rate. Read from it at import: foot contacts, planted frames, its speed over the ground, its heading, footfall sync markers and footfall events. Loops sealed. Root motion taken out with the root locked to the rest pose, straightened for a blend space, mirrored. |
| L2 | `ae3d.animator` | The single writer. States (a take, or a blend space along one parameter), inertialized transitions, gait-to-gait hand-overs in step, masked and additive layers, events fired as the clock passes them, root motion onto the figure's object or through its character controller. |
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

`tools/anim_showcase.ae` puts four figures on these layers for a person to watch. Its runs measure the toes as the test does: through a 20 s cycle of starts, stops, accelerations and a circle, a planted toe slides under 10⁻¹¹ mm. The fourth walks 100STYLE's captured forward and backward walks out along a line and back on a character controller, by root motion.

## Next

- Blend spaces in two dimensions (direction and speed) and starts, stops and turns as clips (#856).
- Full-body IK and aim constraints (#857).
- The physics asset and physical animation (#858), then ragdolls and get-ups into matched clips (#859).
- The plaza, the motion showcase and Siltreach moved onto the pipeline, and the old writers retired (#860).
