### Retargeted feet held to the toe, loops without seams, and the animation viewer (#855, #854)

- **Feet kept on the toe's tip on every rig** (`ae3d.retarget`): each leg
  reaches for the source's toe tip, found along the feet's own heel-to-toe
  forward (`ikrig.rest_forward`) by a ball joint or, for a foot with none,
  by its flesh (`ikrig.flesh_toe`). Found along the hips' facing, the box
  man's tip was taken on his instep and his toe slid 18 mm a stance.
- **A retargeted in-place take goes over the ground as its source does**
  (`clips.ground_like`): its speed scaled and its heading turned as its held
  feet were carried. Read off its own balls, the jog's heading came out a
  degree off and its planted toes skated 6.7 mm a stance.
- **Loops without a seam**: a stance across a loop's seam is held from where
  it went down in the cycle before, and the pelvis drop is eased over
  windows that wrap round the seam (0.77 degrees and 2.6 mm at the walk's
  seam before, 2.4e-6 degrees and 0 mm now).
- UAL1's idle, walk and jog on the UE5 mannequin, the female mannequin and
  the box man: planted toes within 1.2e-12 mm a stance (were up to 16.3 mm).
- **`tools/anim_viewer.ae`**: a clip and the same clip retargeted, side by
  side, with the clip list, scrubbing, each skeleton drawn over its figure,
  and its `ae3d.metrics` meters on screen. CI builds it and runs it a few
  frames with the showcases.
