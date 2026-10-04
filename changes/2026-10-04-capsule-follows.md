### Locomotion: the capsule follows the planted foot

Locomotion's foot hold keeps a planted foot where it was set down by
moving the drawn body off its capsule (#611). Until now that offset was
bled back out of the drawn body over `LOCK_BLEED`. The hips carry both
feet, so bleeding them back slid the planted foot. Most of the turn-round
skate left after packs 33 and 34 came from this bleed.

- The capsule now takes up the offset instead. Each fixed step, the
  share that used to be bled is added to the controller's move.
  - The drawn body stays where its planted foot put it, and the capsule
    comes to it, as root motion would bring it.
  - The controller's velocity, and so the figure's speed and momentum,
    are untouched.
- A turn on the spot now pivots on a foot (#509): the body swings about
  the planted foot, and the capsule follows.
- Locomotion's hold and `ae3d.feet` now work together. They used to pull
  against each other: locomotion's bleed dragged the foot `ae3d.feet`
  held out to `LOCK_REACH`.

On the box man, turning round, the toe on the ground slips:

| posed | before (bleed) | now |
|---|---|---|
| by speed | 29% of the body's way | 0.8% |
| by matching | 16% | 2.6% |
| on `ae3d.feet` too | 40% (holds fighting) | 2.2% |

- The drawn body stays within 0.25–0.33 m of its capsule.
- Walking straight on `ae3d.feet`, the toe still slips 0.009%.
- On the Fox, a running foot drifts 0.14% of the way (it was 2.5%).

`test_locomotion` now requires a turn round to slip under 5% of the
body's way (it was 50%), by speed, by matching and on `ae3d.feet`. Its
box man on `ae3d.feet` runs with locomotion's hold on.
