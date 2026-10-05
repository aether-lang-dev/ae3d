### Physics: a ragdoll that weighs what its person weighs

`physics.ragdoll_set_mass(r, kg)` sets the ragdoll's total mass and gives
each bone its share of it (#626).

- **The shares** come from de Leva's (1996) segment table, male
  (`physics.ragdoll_segment_share`):

  | bone | share |
  |---|---|
  | pelvis (lower trunk) | 11.17% |
  | spine 01 (middle trunk) | 16.33% |
  | spine 03 (upper trunk) | 15.96% |
  | neck (head and neck) | 6.94% |
  | each thigh | 14.16% |
  | each calf (shank and foot) | 5.70% |
  | each upper arm | 2.71% |
  | each lower arm (forearm and hand) | 2.23% |

- **How:** every shape on a bone's body has its density scaled by the bone's
  new mass over its old, so the shapes keep their size and the inertia
  follows the mass.
- **Defaults:** `physics.person_mass(height)` gives a person's mass at a
  body-mass index of 23. A 1.75 m person weighs 70.4 kg.

Built from solid capsules fitted round the bones, the reference human
weighs 138.5 kg as `physics.ragdoll` makes it. That is 1.5 to 1.8 times a
person. Set to 75 kg, a 400 N·s shove moves it at 5.33 m/s, where as made
it moves at 2.89.

`test_ragdoll_mass` holds this (7 checks), including the box man set to
75 kg standing POWERED for three seconds, leaning 0.012 rad at most.

A dressed figure now weighs what a person of its height does: `fit_to_rig`
calls `ragdoll_set_mass(r, person_mass(ragdoll_height(r)))`, about 86 kg for
the 1.93 m rig. The motion that retunes against it is in
`2026-10-05-person-weight-motion.md`.
