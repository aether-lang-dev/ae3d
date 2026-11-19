# Clips and retargeting

The bottom two layers: a rig and its poses (`ae3d.pose`, `ae3d.bvh`), and the takes played on it (`ae3d.clips`, `ae3d.retarget`). Nothing here writes a joint; a take is data a figure's animator samples. The program is [`examples/docs/clips.ae`](../../examples/docs/clips.ae). Issue: #855.

## Rigs and poses

A rig is a skin's joints read once: names, parents, an order that puts parents first, and the rest pose. A pose is ten floats a joint (translation, rotation, scale), flat, indexed by the rig's joint order: every stage of the pipeline reads poses and writes poses, and only the animator writes one to the figure.

A rig also maps its joints onto one humanoid layout, the UE5 mannequin's 53 slots (`pose.PELVIS`, `pose.THIGH_L`, `pose.HAND_R`, fingers included), from whichever naming the file uses. That is how a take made on one humanoid plays on another and how IK finds a leg without being told its bones.

<!-- example: examples/docs/clips.ae#rig -->
```aether
o = figure.figure(e, "Person", FIGURE)
a = animator.attach(e, o)
r = animator.rig(a)                                    // the skin's joints, read once
pelvis = pose.human(r, pose.PELVIS)                    // the UE5 mannequin's slot, whatever the file names it
```

The namings read, as `tests/test_anim_pipeline.ae` printed them on 2026-11-19 at `bea4c991`:

| file | joints | naming (`pose` scheme) | humanoid slots |
|---|---|---|---|
| `people/mannequin.glb` (Quaternius, UE5) | 65 | UE5 (0) | 53 |
| `people/ual1_rigify.glb` (Universal Animation Library) | 53 | Rigify (1) | 53 |
| `gltf/humanoid.glb` (the box man) | 20 | the engine's Blender export (2) | 20 |
| `100style/neutral_fw.bvh` | 28 | Xsens | 22 body slots |
| CMU walk (ASF/AMC) | 38 | ASF | 22 body slots |

Mixamo's naming (`mixamorig:Hips`, with or without the prefix) is read too. A rig the map does not know gets no humanoid slots; everything that asks for a slot then gets -1.

`pose.mirror` reflects a pose left for right: each joint's turn from its rest onto its other side's joint. On the UE5 mannequin a rest pose against its mirror is 0.021 degrees apart, and a pose mirrored twice is 3.0e-6 degrees from where it began (`test_anim_pipeline`, 2026-11-19, `bea4c991`).

## Motion capture

`ae3d.bvh` reads a BVH file (Biovision hierarchy: Xsens, Vicon, OptiTrack, the CMU and 100STYLE libraries) as a rig no skin wears and its frames as a take for it. An End Site (a head's, a toe's or a finger's tip) becomes a joint named after its parent with `_end`, so the tip a foot rolls about is there for the feet to find. Units are found from the skeleton's height when the call passes 0. ASF/AMC (the CMU library's own format) is read too: the CMU walk read from ASF/AMC and from its BVH conversion are 0.0004 degrees apart over 343 frames (`test_anim_pipeline`, 2026-11-19, `bea4c991`).

## Retargeting

A take made on one humanoid, played by another, the way Unreal's IK Retargeter and Unity's Humanoid avatar carry it:

<!-- example: examples/docs/clips.ae#capture -->
```aether
c = bvh.load(CAPTURE, 0.0)                             // units found from its height
made = bvh.take(c, "walk", 0, 0 - 1)                   // every frame
walk = animator.add_take(a, retarget.retarget(bvh.rig(c), made, r), true)   // feet kept; root motion out
clips.straighten(walk, r, true)                        // its path laid on forward, back, left or right
clips.take_free(made)
bvh.capture_free(c)
```

What `retarget.retarget` does, in order:
1. **Facings aligned.** The source is turned about up by the angle between the two rigs' rest facings (square to the line across the thighs).
2. **Rest poses aligned**, bone by bone: the turn that lays the target's rest direction onto the source's. Two rigs never stand alike at rest (a T-pose against an A-pose); carried as turns from rest alone, a T-posed clip put an A-posed figure's arms 45 degrees off. Clavicles are the exception: carried as turns from each rig's own rest, since where a skeleton puts its clavicle is its build, not a pose (aligned, 100STYLE's walk put the mannequin's shoulders 8.8 cm ahead of its neck where its own clips hold them 5.5 to 7.6 cm behind).
3. **Each frame**, every target bone turned from its aligned rest as the source's turned from its rest, in the ground's space.
4. **The pelvis and root** carried as the source's moved, scaled by the ratio of the two pelvis heights: a shorter figure takes shorter steps over the same ground in the same time.
5. **The feet kept on their contacts** (Unreal's IK goals): each leg reaches by two-bone IK for where the source's toe tip is, held where it was planted through each stance, and the pelvis comes down where a leg cannot reach within 0.97 of its length (`REACH`), eased over 0.1 s either side (`SMOOTH`). `retarget.retarget_with(..., false)` turns this off.
6. **A root made under the hips** for a capture that has none, its place and heading averaged over 0.4 s either side (`ROOT_SMOOTH`) so it does not sway with each step.
7. **Fingers the source lacks** relaxed as a living hand rests (`ikrig.relax_fingers`), not left straight and spread.

The take that comes out is the target's own: its contacts, speed and heading found on it as for a take read from its own file.

What it is held to, `test_anim_pipeline` on 2026-11-19 at `bea4c991` (100STYLE onto the UE5 mannequin):

| | measured | held to |
|---|---|---|
| forward walk, run, backward walk: arms, spine and head against the source's, turned bone by bone | 1.01, 1.45, 1.60 degrees | 2 degrees |
| a planted toe's slide a stance, turned bone by bone only | 11.0, 8.1, 8.5 mm (the capture's own 5.6, 5.6, 5.3) | |
| the same with the feet kept on their contacts | under 1.5e-12 mm | 5 mm |
| the head as it stands, against the capture's | 1.2e-6 degrees at most | 2 degrees |
| a root made under the hips: its root motion against the hips' travel | 1.786 of 1.786 m | 1% |
| the Rigify mannequin's gaits onto the UE5 mannequin, the female and the box man: a planted toe's slide | 4.2e-13 to 2.7e-12 mm | 5 mm |
| a CMU walk (ASF), feet kept: a planted toe's slide (the capture's own 24.6 mm) | 7.9e-13 mm | 5 mm |

The legs move up to 22.5 degrees off the source's when the feet are kept; that is the IK putting the target's feet where the source's were on legs of other proportions.

## Takes

A take is one animation resampled for a rig at the file's key rate, every joint's local transform a frame, so a sample is two frames and a blend with no key search. glTF stores keys per node on their own clocks; resampled at the file's own rate a take is exact at its frames. Sampled against the figure's own glTF sampler, the Rigify walk is 0.027 degrees off at worst (`test_anim_pipeline`, 2026-11-19, `bea4c991`; held to 0.1 degrees).

What a take knows about itself, read once as it is made:

<!-- example: examples/docs/clips.ae#knows -->
```aether
pace = clips.speed(walk)                               // metres a second over the ground, from its planted feet
length = clips.travel_length(walk)                     // metres its root goes, end to end
left_down = clips.planted(walk, 0, 0.5, true)          // foot 0 (left) planted half a second in
footfalls = clips.event_count(walk)                    // FOOT_LEFT and FOOT_RIGHT, found as it was made
```

- **Root motion.** Where the root (the UE5 skeleton's `root`, the pelvis where there is none) travels and turns, taken out of the poses and kept beside them (`clips.extract_root`, `travel`, `root_delta`). The animator moves the figure's object by it, or through its capsule (`physics.character_controller`), so a wall stops it: the roll carried 4.991 of its root's 4.991 m on open ground and stopped at 1.705 m with a wall 2 m on (`test_anim_pipeline`, 2026-11-19, `bea4c991`).
- **Foot contacts.** A foot is down while its sole is within 3 cm of the lowest it comes (`CONTACT_UP`), planted while it is also still: over a still ground, a foot that is low and flat is planted only while it does not move, so a capture's shuffle as the actor turns is not a stance. A gait run on the forefoot counts as planted on its ball.
- **Speed and heading.** Measured from the planted feet's travel for a clip made in place, from the root otherwise, over a 0.1 s span (`SPEED_SPAN`) so a capture's sway does not read as its pace.
- **Footfalls and sync markers.** Each footfall an event (`clips.FOOT_LEFT`, `FOOT_RIGHT`); a take's phase runs from its left footfall (0) to its right (0.5), which a blend space keeps in step.
- **Distances.** `time_at_distance`, `time_at_distance_left`, `moving_at` (the first time its root goes faster than a speed), `still_at`, `braking` (a stop's own deceleration), `stop_path` (how far and which way a stop turns as it rests): what distance matching plays starts and stops by.

On the 100STYLE gaits retargeted onto the mannequin (`test_anim_pipeline`, 2026-11-19, `bea4c991`): forward walk 0.80 m/s, backward 0.65, side 0.51; forward run 1.71, backward 1.31, side 1.47.

### Shaping a take

<!-- example: examples/docs/clips.ae#shape -->
```aether
looped = animator.add_take(a, clips.loop_cut(walk, r), false)   // the best seam at least 0.6 s apart, sealed
other = animator.add_take(a, clips.mirror(looped, r), false)    // left for right
clips.add_event(looped, 0.25, "cue")                   // a program's own event, fired as the clock passes it
```

- **`loop_cut`** finds the two frames at least 0.6 s apart (`LOOP_LEAST`) whose feet, hands, head and pelvis match best in place and motion, crops between them and seals the loop. A capture cut between two footfalls ends 16 to 41 degrees off its start at a foot, too far to seal.
- **Sealing** (`seal_loop`, as Unity's Loop Pose): the gap between a loop's last frame and its first spread over it, so it never snaps as it wraps. After sealing the fixtures' loops are 2.4e-6 degrees apart across the seam (`test_anim_pipeline`, 2026-11-19, `bea4c991`; held to 0.1 degrees).
- **`mirror`** swaps left for right, contacts and events with it: the Rigify walk mirrored has its feet down at 0.767 s and 0.1 s against 0.1 and 0.767.
- **`straighten`** lays the path on the root's own frame and, `cardinal`, onto the nearest of forward, back, left and right, poses and path turned together: 100STYLE's forward walk straightened goes 1.779 m ahead and 3e-17 m across.
- **`crop`**, **`root_under_pelvis`** (a get-up's root motion from its pelvis, so the capsule stays under the body).

The animator frees the takes it was given (`add_take`) or loaded (`take`) with itself. A take made once and shared by several figures goes through `animator.share_take`: one walk shared by two figures drew their joints 2.4e-6 degrees apart, outlived both animators, and was refused to a rig of another size (`test_anim_pipeline`, 2026-11-19, `bea4c991`).

### Compression

<!-- example: examples/docs/clips.ae#compress -->
```aether
before = clips.take_bytes(looped)
moved = clips.compress(looped, r)                      // within clips.COMPRESS_ERROR of the skin
after = clips.take_bytes(looped)
```

A take is compressed in place within `COMPRESS_ERROR` (0.1 mm) of where any point of the skin would be drawn, as ACL compresses UE5's AnimSequences: each joint's translation, rotation and scale a track of its own, kept as one value when it holds still, else as 16-bit numbers over its range, 32-bit or 64-bit floats, the coarsest that keeps its share of the error at virtual vertices a bone's length from each joint (ACL's measure); then frames the skin does not need dropped (ACL's keyframe stripping, #992), a dropped frame being the blend of the keys either side. The whole take is decoded and measured against the original after, and any chain past the bound made finer. A compressed take samples at the same cost. `examples/docs/clips.ae` on 2026-11-19 at `bea4c991`: the retargeted 100STYLE walk loop, 1.35 s on 65 joints, went from 431,744 to 45,652 bytes, a skin point moved 0.0044 mm at most. A graph file's takes are compressed as they are read and shared by every figure on the same file and skeleton (#992).

## State

A take is not in a figure's snapshot: every peer makes the same takes from the same files the same way, and a snapshot carries only where each state's clock is ([networking.md](networking.md#what-a-snapshot-holds)).

## Costs

| | measured | where |
|---|---|---|
| a 53-joint take sampled for one character | 0.33 µs | `test_anim_pipeline`, 2026-11-19, `bea4c991` (held to 20 µs) |
| a mannequin's animation memory | about 59 MB | #990, 2026-11-09; shared takes and compression are reducing it (#990, #992) |

## Limits and known issues

- The skin takes up to 256 bones (`skin.MAX_BONES`); `tests/test_skinned_render.ae` holds a 256-bone skeleton drawn on the GPU against the CPU.
- Animation memory per figure: #990, #992.
- Motion matching reads trajectory features backwards near a looping take's end: #998.
- Turning stop captures are classed but never played: #1029.
- Motion warping (a take's root bent onto a target): #987.
- Milestone: #855.
