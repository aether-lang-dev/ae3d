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
