### Locomotion: a transition's joint-velocity limit, stated and held

#509 asks that transitions have no pose discontinuity above a stated joint
velocity limit. `test_locomotion` now states one and holds it: while the
figure blends from one clip, or one frame of the matching database, to
another, no bone turns faster than the clips' own fastest when played
alone. The blend adds no motion of its own.

Measured on the Fox through the whole scripted run (stand, walk, half
stick, run, stop, turn a quarter, turn round, a 20 cm step):

| posed | fastest bone while blending | fastest with a clip played alone |
|---|---|---|
| by speed | 21.4°/frame | 25.2°/frame (1,512°/s) |
| by matching | 22.6°/frame | 25.0°/frame |

The 30° a frame bound stays as well; a cut is 89°. That makes 41 checks.
