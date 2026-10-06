### Motion: the get-up puts hands, knees and feet where they bear the body

The way up from the ground was four whole-body key poses eased bone by
bone. Nothing it leaned on was under it: the body floated up while the
hands and feet swept through the air and the ground. Now each key is
planned on the figure's contacts (#414).

- **From its front:**
  1. The hands are set on the ground under the shoulders.
  2. It pushes up onto hands and knees, the shoulders over the hands and
     the hips over the knees.
  3. It brings one foot forward and kneels on the other knee, the hands on
     the front knee.
  4. It rises over the front foot, and the back foot comes up beside it.
- **From its back:**
  1. It sits up, leaning back on its hands behind the hips, with the knees
     up and the feet flat.
  2. It rocks forward over the feet into a crouch, the hands down ahead.
  3. It rises over its feet.
- **Planted limbs stay planted.** In each key the trunk is placed where
  the planted limbs can hold it. Each limb is solved with two bones and a
  pole to reach its point on the ground. Between keys every limb is solved
  again each step, so a planted hand or foot stays where it was put, and
  one that moves lifts off the ground on the way.
- **Long swings take longer.** The hands set from where they lay, the
  foot brought forward and the hands lifted each take 1.7 times a stage.
  A rise from the front takes 3.6 s and from the back 2.6 s.
  `tests/test_get_up.ae` holds every bone under 6 degrees a step and the
  hand-over to the animation seamless.
- **On the ground under each contact.** Each hand, knee and foot is set
  on the ground under it, found by a ray down onto the world's static
  shapes, and the trunk is held over the ground under the hips. Planned
  on one flat floor at the figure's lowest point, a figure tripped onto a
  kerb (legs below, chest on it) ended its rise 0.71 rad off upright and
  went down again. `tests/test_get_up_kerb.ae` covers kerbs from 0 to
  2 m ahead: every rise ends within 0.07 rad of upright and stands. With
  the chest landing right across the kerb's edge, it still gets up
  leaning (#643).
