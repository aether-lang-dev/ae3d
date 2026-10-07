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
