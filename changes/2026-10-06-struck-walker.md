### Locomotion: a struck walker gets up once and stands

`locomotion.set_paused(l, true)`, which hands a figure to its active
ragdoll, now holds the figure's clip on the frame it is at. Before, the
clip played on.

- **Why it fell again.** A POWERED ragdoll's joints follow the figure's
  clip. The walk went on stepping under the ragdoll, so a walker struck
  mid-stride got up and then walked on the spot with no step to stand on.
  It went over, rose and went over again, 3 to 5 times in 20 s.
- **Held, not stopped.** With the clip stopped, nothing posed the figure
  each frame. As `ae3d.feet` eased out, it turned the legs on top of the
  previous frame's turn. The legs were left twisted, and the figure fell
  as often as before.
- **Measured** with the plaza showcase, 60 s each with 20, 24 and 28
  walkers. Of the walkers the car struck, 90 of 102 walk again, on
  average 8 s after the strike. Before, it was 35 of 75, after 13 to 25 s.
  `tests/test_struck_walker.ae` strikes a walking box man at three moments
  of its stride. It goes down once, gets up and stands, and walks again
  when taken up.
