### Locomotion: the crowd's bend eased before the facing follows it

How far a walker's crowd bends its way (`aside`, pack 43) now eases toward
the new bend over `ASIDE_EASE` (0.3 s) instead of following it at once. The
bend changes from frame to frame as the others move. Followed at once, the
facing swung with it, and a planted foot was swept round.

On the plaza with 200 walkers over 15 s:

| | before | after |
|---|---|---|
| no car: toe slide per stance, mean | 0.173 cm | 0.152 cm |
| no car: stances over 1 cm | 4.0% | 3.3% |
| car crossing: toe slide per stance, mean | 0.41 cm | 0.33 cm |
| car crossing: stances over 1 cm | 7.7% | 5.6% |

Easing over 0.15 s or 0.6 s did no better than not easing.

`test_locomotion` (41 checks), `test_avoid` (7) and `test_crowd_feet` (6)
pass. The two Foxes in a crowd still pass 0.84 m apart at nearest.
