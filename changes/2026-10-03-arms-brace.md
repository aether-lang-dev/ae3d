### Motion: a hand to the wall, arms kept on the way up, a stagger that ends when caught

- A POWERED figure's upper arms missed their clip (#600) because their
  capsules were held off the hips, the lower spine and the thighs. A clip
  rests the arm against the flank and the hand against the thigh, and a
  capsule fitted around a bone is thicker than the flesh. Contact pushed
  each arm out and turned it about itself; every other joint tracked within
  a twentieth of a degree.
- While a figure gets up, its arms now pass those bones
  (`physics.ragdoll_free_flanks`, filter joints). Once it is up, each pair
  meets again as soon as its capsules are apart.
- Before, a risen figure's upper arms stood 42–45 degrees from their clip,
  and at the hand-over the arm swung 6.04 degrees a frame. Now they stand
  within 0.001 degrees, and the worst turn rising face down is 4.84
  degrees. Get-up's 6-degree bound is back.
- A figure that has not fallen still stands with its arms 16 degrees off.
  Letting the arms pass the body while standing made the clip's pose
  reachable, but every fall then began with the arms at the sides and
  fell worse: sideways the protected head met the ground at 1.9 m/s, not
  1.3. That is still open in #600.
- A POWERED figure going toward a wall braces against it (#590). A ray
  from its chest, as far as it will go in 0.6 s, finds the static world;
  head on, both hands reach for the wall, at a slant the nearer one, with
  the elbows giving. A protective fall toward a wall reaches for the wall,
  not the ground. `motion.set_bracing` turns it off (on by default), and
  `motion.braced` says whether a hand is up.
  - In `tests/test_brace.ae`, nine shoves of 270–350 N s from behind send
    figures toward a wall two strides ahead. In all nine a hand meets the
    wall first, and the head stays clear of the wall or meets it slower
    than the unbraced twin's: 0.56 m/s on average against 1.50.
  - A wall a stride ahead is met in 0.22 s, before an arm hanging at the
    side can come up; past 350 N s the body outruns the arms.
- A stagger is over once the figure moves back against the way it
  staggered (#598). On the IK rig 250 N s took nine steps and now takes
  three; the box man stands 270 N s in three steps, not five. What rocks
  it is still open on #598: a stance leg driven to the clip's angles on a
  foot that grips.
