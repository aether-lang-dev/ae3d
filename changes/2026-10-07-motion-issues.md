### Motion: the open motion issues, in one pack

- **The Unreal mannequin's names (#646).** `physics.humanoid_scheme`
  knows a fourth naming, `HUMANOID_UNREAL`:
  - `pelvis`, `spine_01`, `spine_03`, `neck_01`;
  - `thigh_l`/`_r`, `calf_l`/`_r`;
  - `upperarm_l`/`_r`, `lowerarm_l`/`_r`.

  Quaternius' CC0 figures, the UE4 and UE5 mannequins and the rigs
  retargeted to them now get an active ragdoll from `motion.on_figure`,
  which used to return null. `tests/test_motion_figure.ae` builds such a
  rig: it is known, dressed, and stands POWERED.
- **A body's whole balance (#641).** `motion.body_assist(m)` is the most a
  body's feet can hold it by: its weight about 0.4 m, under
  `full_assist()`'s 1200 N·m ceiling. That is before its strength and
  wounds take their share, so a game can cap a crippled figure's balance
  at a share of it. A share of the ceiling capped nothing: on an 86 kg
  figure, whose whole balance is 337 N·m, half of the ceiling is 600.
- **A struck figure is drawn as its bodies are, not as its clip.** The
  bodies drew the figure at the fixed step, but a clip played in the
  update after it, even one held on a frame under a struck walker, posed
  the rig again. What the clip poses and the bodies do not, the feet a
  calf carries and the hips' place, was drawn as the clip had it: struck
  walkers' feet 5 to 50 cm in the ground. Now:
  - physics redraws every figure it draws from its bodies in the pose
    phase, after the clips, first taking the frame's clip pose as the
    animation's;
  - motion redraws a way up in the pose phase too.

  Over 60 s with 20, 24 and 28 walkers, feet in the ground went from
  534 s to 78 s. Struck walkers walking again: 93 of 103.
- **Handed over whole.** `feet.release` and `lookat.release` let go at
  once, not eased out. Each puts back its last turn of the legs, or of
  the neck and head. Eased out over a quarter second after a walker was
  struck, they went on turning what the bodies had drawn.
- **Risen over its own feet (#643).** The last stage of a way up, from
  kneeling over the front foot to standing, is now planned on contacts
  like the stages before it:
  - the planted foot stays where it is;
  - the back foot is lifted and set down beside it;
  - by the end the limbs are eased onto the animation's own turns.

  Before, the stage was eased bone by bone, and the back foot was dragged
  a metre along the ground. Then the figure settles before it is handed
  to its balance:
  - the stance is brought over the foot nearer its spot, at 0.3 m/s;
  - a foot still more than 2 cm off its spot takes one short step to it,
    lifted 5 cm;
  - it is handed over once it is upright, still, its centre of mass over
    its feet and the feet come to rest, or after a second at the most.

  Handed over on the clock instead, a figure risen onto a kerb's edge
  had its feet 20 cm behind its hips. Righting itself, it rocked 20 to
  30 cm back and stepped off the kerb. Now:
  - every kerb from 0 to 2 m ahead stands, the edges (1.2 to 1.6 m) among
    them (`tests/test_get_up_kerb.ae`, three new cases);
  - each moves under 1 cm in the second after it rises (3.9 cm risen
    beside the kerb, past its end);
  - the hand-over is seamless: 0 degrees and 0 mm.

  The stand point is no longer shifted off the edge (`clear_ahead`). That
  dragged the planted foot after it.
- **People are not ground (#654).** A character's ground ray skips
  ragdoll bones, its own figure's and anyone else's. A walker whose way
  crossed a figure lying in the street used to climb onto it, its
  capsule 0.3 to 0.4 m up while its feet were set on the street.
  `tests/test_character_bodies.ae` walks a character across a lying box
  man: its feet stayed at 0 cm over the ground, against 29 cm before.
- **aephysics at its latest main (a5d9940).** aephysics#120, the macOS
  cost reading, measured as runner noise and is closed. a5d9940's
  eight-lane contact solver is written on std.lanes' `f32x8`, so CI's
  Aether goes to v0.788.0 with it. Measured alone, POWERED figures cost
  68 us a step each at sixteen and 44 at thirty-two.
