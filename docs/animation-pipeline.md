# The animation pipeline

ae3d's animation is a pipeline of layers, the way shipped engines build it (#853). Each frame a figure's animator evaluates one pose, and that one pose is written to the figure's joints. Games set parameters and never write bones. Before it, seven modules wrote the same scene-graph bones and found each other by comparing floats; the old modules are frozen and are retired by #860.

| layer | module | what it does |
|---|---|---|
| L0 | `ae3d.pose` | A rig is a skin's joints read once: names, parents, parents-first order, rest pose, and a map onto one humanoid layout (the UE5 mannequin's 53 slots, fingers included) from UE5, Rigify or Mixamo naming. A pose is ten floats a joint, flat. Blends, masks, additive differences, model space. |
| L0 | `ae3d.retarget` | A take made on one humanoid played by another: rest poses aligned bone by bone, turns carried in the ground's space, the pelvis and root scaled by the two figures' pelvis heights. |
| L1 | `ae3d.clips` | A take is an animation resampled for a rig at the file's key rate. Read from it at import: root motion (the root's travel and turn, taken out), foot contacts, planted frames, its speed over the ground, its heading, and footfall sync markers. |
| L2 | `ae3d.animator` | The single writer. States (a take, or a blend space along one parameter), inertialized transitions, gait-to-gait hand-overs in step, masked and additive layers, root motion onto the figure's object. |
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

## The techniques, and where they come from

- **One pose, one writer.** This is Unreal's pose buffers, Unity's Playables and ozz-animation. It ends the class of bugs where one system draws over another.
- **Inertialized transitions** (Bollo, GDC 2018, Gears of War 4). At a change, the new state plays from where it enters. The offset from the pose drawn the frame before, and its speed, decay along a quintic. Only one clip plays, and no foot is dragged between two strides.
- **Sync markers.** A blend space's takes share a phase that runs from each take's left footfall (0) to its right (0.5), the way Unreal's sync groups keep markers. Every left foot of a blend comes down together, and every right foot does too. `play_synced` hands one gait to another at the stride's phase.
- **Speed matching.** Each take's speed is measured at import, from its planted feet's travel. Planted means flat for a gait that puts its feet down flat, and on the ball for one run on the forefoot. A blend picks its weights by speed and bends its pace so the feet carry the ground at the speed the figure moves.
- **Foot locking with toe pivots and foot roll.** A planted foot is locked on what is on the ground: its ankle from the heel's strike, its toe's tip once the clip plants it. When the leg cannot reach as the body passes, the heel peels up about the toe instead of letting it slide (foot roll in Unreal's leg IK).
- **Soft IK.** A leg's reach eases off from 97% of its length, or from the clip's own stretch where that is straighter, so a knee never snaps straight.
- **Retarget poses.** Rest poses are aligned per bone before any motion is carried, as Unreal's IK Retargeter does with a retarget pose.

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

`tools/anim_showcase.ae` puts three figures on these layers for a person to watch. Its runs measure the toes as the test does: through a 20 s cycle of starts, stops, accelerations and a circle, a planted toe slides under 10⁻¹¹ mm.

## Next

- Blend spaces in two dimensions (direction and speed) and starts, stops and turns as clips (#856).
- Full-body IK and aim constraints (#857).
- The physics asset and physical animation (#858), then ragdolls and get-ups into matched clips (#859).
- The plaza, the motion showcase and Siltreach moved onto the pipeline, and the old writers retired (#860).
