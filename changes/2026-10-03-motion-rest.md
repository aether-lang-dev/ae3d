### Motion: still at rest, struck on the frame, knees that give, parts with a mode of their own

- A powered figure at rest is still (#579). At 4 sub-steps a joint's
  constraint sat on the solver's limit and rang against the motors: every
  body of a figure standing untouched turned at 0.56 rad/s on average, 1.6
  at most. A world holding a powered figure now steps in 8 sub-steps: 0.0035
  and 0.04 (`tests/test_motion_rest.ae`). It costs 34 µs a figure at 32
  against 23; a world with no powered figure keeps 4.
- The stagger and the writhing had leaned on the trembling. Balance now reads
  the pelvis for the way a figure faces (a shove from behind folds the chest
  forward, and its front read as backwards), and a step is backwards only
  behind the rear foot: stepping stands to 360 N·s from behind (240 without).
  Writhing happens where the figure lands (#480); face down it no longer
  tries to turn over, which only braced it against the ground.
- The protective fall meets #479 every way: heads slower than the twin's in
  30, 30 and 30 of 30, no second impact, every figure still within 3 s.
  Forwards the ensemble's blows run 410 to 460 N·s, past what the stagger
  now catches.
- Falling, the knees give 0.45 rad (#578): forwards the pelvis is 0.35 m
  down when the figure leans past 45 degrees, against 0.20 for a twin that
  keeps its knees, and the head meets the ground at 0.84 m/s instead of
  1.44. A stepping knee bends 0.48 rad.
- An impact shows on the frame it lands (#581): a figure going `POWERED` from
  its clip is drawn from its bodies at once, under the offset the clip had
  from them, which fades over 0.25 s. The drawn hips' way and the body's
  differ by 0.9 cm at worst (3.4 before) (`tests/test_impact_shows.ae`).
- Body parts with a mode and a lasting strength (#573):
  `set_part_mode(body, part, LIMP)` lets an arm hang and swing from the
  shoulder while the figure walks its clip, drawn from its bodies;
  `set_part_strength` holds an injury through every blow and recovery
  (`tests/test_motion_parts.ae`). A motor joint capped at 0 still
  warm-started its last impulse (aephysics#76), so a limp bone's anchor joint
  is destroyed and made again.
