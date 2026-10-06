### Motion: a struck walker gets up and stays up

Three things kept knocked-down walkers from getting up, or from staying up
once they had.

- **Landed in a heap, it was never "down".** A walker that came to rest
  kneeling or on its hands and knees had its pelvis half a metre up and
  leaned less than `DOWN_TILT`. It lay still for the rest of the minute,
  never counted as on the ground, so it never got up. A figure that has
  landed and lies still is now on the ground, whatever its shape.
- **Handed over, the figure holds its walk ready to land.**
  `locomotion.set_paused(true)` holds the walk at the moment its swing
  foot is ahead and coming down: half way from where the feet pass to
  where it lands. Held wherever it was struck, a runner's frame (leaning,
  a foot in the air) was the pose it got up into, and it fell again.
  Struck walkers and runners that fell again after getting up:

  | Held pose | Fell again |
  |---|---|
  | Ready to land | 4 of 48 |
  | Both feet down | 10 of 48 |
  | Wherever it was struck | 17 of 48 |
  | Bind pose or the idle's first frame | 7 or 8 of 8 |

- **ae3d.feet puts back its own last turn.** Before turning the legs again,
  it restores whatever it wrote last frame and nothing has posed since,
  as `ae3d.lookat` does. On a held or stopped pose, it had turned the legs
  on top of its own turn every frame as it eased out.

In the plaza showcase (60 s at 20, 24 and 28 walkers), 44 of 47 struck
walkers walk again, 7 to 9 s after the strike on average. A stance's toe
slide is 0.23 to 0.31 cm, from 0.34 to 0.39.
