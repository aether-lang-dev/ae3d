### Locomotion: a crowd walks round a body lying in its way

`locomotion.set_stand_in(l, a, b)` tells a handed-over figure's crowd where
its body lies, from `a` to `b` (its pelvis to its head, say). A walker
whose way crosses that line, widened by its clearance, turns toward a
point past the body's nearer end and walks round it (#647). Left where the
figure was struck, the crowd stepped round the place it had stood and
walked over the body lying metres off.

A lying body is a line, not a figure, and point avoidance does not hold it:

- **As points along it,** the pushes from the points on either side of a
  walker's way cancelled, and it walked between them.
- **As the one point nearest its way,** the walker stepped aside and came
  back onto the body as its goal drew it.

In `tests/test_locomotion.ae`, a fox walking at a body lying across its
way passes 0.73 m clear and gets where it was going. Not given the body,
it walks through it (0.004 m).

The plaza showcase uses it. Its report now gives the seconds walkers spend
walking through struck bodies, and how much of that the body lies still.
Most of what is left there is bodies thrown onto walkers who stand still:
their ragdolls are parked, so nothing collides with them.
