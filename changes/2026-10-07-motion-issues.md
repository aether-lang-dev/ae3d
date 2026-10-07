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
