### A ragdoll fitted to the figure it dresses (#529, #482), and the protective fall put right (#479)

- Dressing builds the ragdoll again as the rig's figure (aephysics.human's
  `human_fit_shape`, aether-lang-dev/aephysics#57): every joint at its rig
  bone's head, every bone along the rig's line to its next mapped bone, so
  a chest's runs to the neck and not to whichever clavicle the exporter
  listed first. The rig's bind pose is the ragdoll's rest pose, and a body
  carries no bend to its bone, so a curved spine stands curved. A ragdoll
  dresses once (`ragdoll_dress_named` answers false the second time).
- A calf's shin and foot are told apart by the bone's own shape ids, not by
  the order a body lists its shapes in. The facing a figure is dressed to,
  where a knee bends, and a calf's end (the ankle, as `ragdoll_pose_end`
  said it was) were all read off the foot.
- The protective fall reached away from the fall and tucked the head into
  it: the fall's way came from the pelvis body's +y, which points down. The
  left arm reached up: one arm axis served both arms. `ragdoll_bone_axis`
  gives each bone's own.
- Landed, a figure holds the shape it landed in (`ragdoll_hold_shape`) on
  30% of its budget, and lies once its trunk is still. Before, the arms
  kept reaching for the ground they lay on and pushed it back up, and
  lying pulled the legs toward standing.
- `tests/test_falls.ae` holds the protective fall over thirty falls each
  way; `tests/test_ragdoll_fit.ae` dresses a straight rig and a curved one.
  `test_balance` sweeps its forward pushes; `test_get_up`'s trip is 300 N s,
  which a figure fitted to its rig needs; `test_motion` reads each bone's
  own capsule.
