### Locomotion: stepping aside, it faces the way it goes

When a walker steps aside for its crowd (`set_crowd`, `ae3d.avoid`), it now
turns to face the way it is actually going.

Before, avoidance bent the walker's velocity but the heading still followed
the stick. The body crabbed sideways while its clip stepped straight on,
dragging the planted foot across the ground. On the plaza, 200 walkers with
no car, 310 of the 334 stances that slid more than a centimetre were
walkers going aside, not turning.

Locomotion now keeps the angle the crowd bends its way by (`aside`). The
heading turns toward the stick's direction plus that angle.

On the plaza, 200 walkers with no car, over 15 s:

| | before | after |
|---|---|---|
| toe slide per stance, mean | 0.255 cm | 0.173 cm |
| stances over 1 cm | 334 of 6,089 (5.5%) | 208 of 5,191 (4.0%) |
| ...of those, with less than 5° of turning | 310 | 37 |

The stances over 1 cm that remain come with turning, which avoidance now
does on purpose. With the car crossing as well, the share over 1 cm goes
from 9.6% to 7.7%. One stance, though, slid 50 cm.

`plaza_showcase` gains `AE3D_NOCAR=1`. Each stance printed by
`AE3D_STANCES=3` now also says how far the walker turned and how fast it
went.

`test_locomotion` (41 checks), `test_avoid` (7) and `test_crowd_feet` (6)
pass. The two Foxes in a crowd still pass on opposite sides, 0.81 m apart
at nearest.
