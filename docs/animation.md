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

## The crowd's feet and heading

A crowd figure's pose bank is baked in place, so its feet move back under
its root at exactly the root's travel, and a body that covers that distance
leaves them where they were set down. Before #575, five things broke that:

| What | Before | Now |
|---|---|---|
| Speed | the bank's speed at the frame the phase falls in, while a step crosses frames | the root's travel over exactly the stretch of the walk the step plays (`posebank_travel_over`, interpolated) |
| A speed limit | applied after matching, so the clip ran on while the body was held back: a figure held to 60% slid by 40% of its speed | the walk slows by the same share |
| Standing | the walk played on the spot | the walk stops |
| A clip made in place (Mixamo's "in place", the Fox's walk) | travel zero, so a crowd matching its speed to the bank stood still | travel taken from the foot on the ground: frame to frame, the lowest of the bones that rise and fall over the walk |
| `horde_strike` | stepped its crowd with no bank, the walk unrelated to the travel | stepped with its bank |

The heading turns toward the way a figure goes at no more than 3.5 radians
a second (`TURN_RATE`). A neighbour's shove turns it over a few frames, not
one. An edge no longer flips it 180 degrees in a step: near the edge,
within half a second's walk, a figure not yet heading away is pointed back
in, and it turns until it walks away. In `examples/street_drive.ae` the
walkers likewise turn back on a tight arc at 2.4 rad/s, at 45% of their
pace with their gait slowed to match, instead of rotating π in one step.

`tests/test_crowd_feet.ae` runs on the Fox's walk:
- 81 units of travel (it is in centimetres) recovered from its feet;
- no slide in a step walking free or held to 60%;
- the walk stopped while standing;
- a heading shoved left and right every frame turns 3.34 degrees a frame
  at most (the cap);
- walked into an edge, it turns back by no more than the cap a frame and
  walks back into the street.
