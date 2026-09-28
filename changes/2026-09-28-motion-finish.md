### Natural motion: writhing, staggering, and the protective fall set right

- A `POWERED` figure down and hurt writhes (`set_writhing(body, seconds)`,
  off by default; `writhing`, `wound`) (#414): its legs draw up together
  and let down, its arms fold over its front toward where it was struck,
  fading over the second half of its time; then it lies still and settles,
  so `set_get_up` counts from there. Only a `POWERED` figure writhes. Face
  down it turns over onto its back first: the arm on the higher side
  pushes the ground away, that leg draws up, the others let go. A limb a
  blow left weak, or the struck arm, takes no part.
- A shove one step does not catch, a figure staggers from
  (`staggering(body)`): quicker catch steps in a run, each to where the
  capture point is then, while it is within three strides, and the
  protective fall waits until it leans past 0.8 rad. Forward, 340 N·s is
  caught (240 without stepping).
- The protective fall reached the wrong way. It took the pelvis body's +y
  for its up, and the reference ragdoll's trunk bodies are made upside
  down: the arms reached away from the fall and the head tucked into it.
  The fall's way is now the world's up turned as the pelvis is, and the
  protective fall is: the arms reach down and out to their sides, the
  trunk curls 0.5 rad at each joint of the spine, the head tucks 0.5 rad,
  all from each limb's rest place under its parent and kept within its
  joint's limits (a target past a limit only saturates the motor, which
  turns the body instead). Landed, the reach and the curl let go.
- Limbs are aimed along their own capsules. `physics.ragdoll_bone_axis`
  gives a bone's direction: the reference ragdoll's limbs are mirrored
  (left thigh along -x, right along +x, the arms the other way), where
  every limb was once taken to lie along -x. It and `ragdoll_pose_end`
  read a calf's own capsule, the shin, not its foot, which a body lists
  first: a calf's end was its toe and its axis 50° off the shin.
- Stepping measures the feet from the ankles now, so its margin is 24 cm
  (8 cm while it measured from the toes); the swing thigh aims within the
  hip's cone and the knee bends 0.5 rad as the foot lifts.
- Measured over thirty falls each way against unprotected twins, the head
  meets the ground at 1.18, 0.33 and 0.61 m/s (forwards, over backwards,
  sideways) against 3.46, 2.41 and 1.68; slower in 30, 30 and 23 of 30,
  the hands first every time. Before, no better than the twin on average.
- `tests/test_stagger.ae`: 330 N·s from behind fells a figure that can't
  step, and one that can staggers three steps, 0.33 and 0.27 s apart, and
  stands; 360 N·s is staggered from twice and falls into the protective
  fall; the run twice is the same to the bit.
- `tests/test_writhe.ae`: the hip swings 1.18 rad writhing (0.006 still),
  the arm folds to a cosine of 0.47 against the chest's front (-0.01
  still), 0.25 m of drift, stopped at 3 s and down 0.15 s later, the
  struck arm left alone, bit for bit twice.
- `tests/test_motion.ae` names its fall ways as the figure faces (-z is
  from behind) and measures the left hand on the left forearm's capsule;
  protected heads meet the ground at 1.04 and 0.83 m/s, and not at all
  from the side, against 1.95, 3.68 and 2.19. `test_balance`: 270 N·s from
  behind is caught in 2 steps.
