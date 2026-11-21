### The head takes its share of a gaze shift (#910)

- **As people's heads do** (`ikrig.head_share_of`, `look_solve`): the eyes
  make a gaze shift under 15 degrees alone; past it they keep 15 degrees
  and 15% of the rest, and the head turns the remainder, starting 70 ms
  after the eyes (53% of a 40 degree shift, 64% of 60). It holds that
  share a quarter of a second, then catches up over a 0.4 s time
  constant, the eyes recentring as it comes, all the while on the point.
  On VRoid's base female, the head's share at 0.3 s: 0% of 10 degrees,
  20% of 20, 52% of 40, 62% of 60; at 2 s it has caught up 92 to 97% and
  the eyes are within 0.1 degree of where they settle in the head.
