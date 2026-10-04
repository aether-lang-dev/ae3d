### Tests: the light grid's build held to the machine it runs on

- The 256-lamp light grid build is now held to under 3 times the 64-lamp
  build in the same run, and under 5 ms (#604). It used to be held to
  2 ms flat. On a Linux runner slow throughout the test, even the fastest
  of twenty builds took 2.05 ms and failed a PR that didn't touch the
  grid. Here 256 lamps take 1.79 times 64's.

### Motion: stepping aside for another figure

- `ae3d.avoid` (#509) bends a figure's wanted velocity so it passes the
  figures around it, the way people do on a pavement.
  - `avoid.aside(position, current, wanted, others, count, avoid.RADIUS, delta)`
    looks 2.5 s ahead, finds when and how near it would meet each figure,
    and turns aside to clear by two radii plus 0.25 m.
  - Coming straight at each other, both keep right. It keeps away from a
    figure it is overtaking until it is clear.
  - The speed stays the wanted one, and it turns no faster than 3 rad/s.
- `tests/test_avoid.ae`:

  | case | nearest | |
  |---|---|---|
  | head on | 0.82 m | they pass on opposite sides |
  | crossing at right angles | 0.73 m | |
  | overtaking a slower figure | 0.74 m | the faster one ends ahead |
  | eight crossing a circle | 0.63 m | all eight arrive |

  Two figures walking side by side 3 m apart are never bent.
- `locomotion.set_crowd(l, walkers)`: a figure under locomotion steps
  aside for the others in a list it is given. The velocity asked for is
  bent before the accelerations take it.
  - In `test_locomotion`, two Foxes on controllers walk head on to where
    the other started. They pass on opposite sides, 0.82 m apart at the
    nearest, and both end within 5 cm of where they were going.
