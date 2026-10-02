### A ragdoll dressed in a real glTF rig (#539)

- Dressing strikes the rig's bind pose first (`skin.skeleton_strike_bind`):
  every bone where its inverse bind matrix says the mesh was modelled, in
  the skin's own space (`skin.skeleton_set_space`, the skinned node), so a
  figure a game object turned stays turned. A glTF exported from Blender
  carries the pose the scene was saved in; the Quaternius Adventurer's has
  its body turned 27 degrees and its legs in a stride, and the ragdoll
  fitted to that stood in the stride and staggered six steps at 40 N·s.
- A calf with no child -- an IK rig hangs its feet from its root -- takes
  as its ankle the bone heading on the leg's line below the knee, and a
  foot with no toe bone points along its own +y. The Adventurer had no
  facing at all, its mesh's toes pointing +z while the ragdoll reported -z.
- A skeleton keeps the meshes skinned to it (`skin.skeleton_add_mesh`;
  the glTF loader adds them) and answers a bone's farthest posed point in
  a direction (`skin.skeleton_bone_extreme`). Dressing fits the feet to
  that flesh: a missing toe bone's toe is the foot's farthest point
  forward, and both shins end, by one length, where the lower fitted
  foot's underside meets the sole. The Adventurer's ankle bone sits at its
  sole, and the foot hung below it stood the mesh 6.4 cm off the ground.
  One length for both legs: the reference's right toe sits 8 mm below its
  left, and fitting each foot to its own sole made legs of two lengths,
  which leaned the standing figure 22 to 29 degrees.
- An IK foot is carried by its calf body after dressing, so it falls with
  the shin instead of staying under the root.
- Measured in the bind pose, the figure is left as it stood (#542): the rig
  back in the pose it had, the bodies put on it, and the root riding the
  pelvis as the two stand there (a Body a clip turns 27 degrees between
  them). Dressing moves no bone. Left in the T-pose, a figure dressed while
  its Idle played had its bodies in one stance and its clip in another,
  and walked 33 cm off in a second.
- `core.quat_from_axes` (from the glTF loader) builds a rotation from its
  three axes.
- The Adventurer, POWERED, pushed at the chest, its Idle playing: it
  stands at 1.1 degrees, takes 60 N·s from behind with no step (it took
  six at 40 before), and holds every push to 260 N·s from behind (falls
  at 300; 120 fell before) and 180 in front.
- `tests/test_ragdoll_ik_rig.ae` holds it on `ik_man.glb`, a box figure
  rigged that way (written by `tools/make_gltf_fixture.ae`).
  `test_handover` and `test_net_handover` stand their hordes on the ground
  (y 0, not 0.02): the box man's dressed mesh had floated about 2 cm, and
  the hordes had been put where it floated to. Given back, a figure now
  pops 1.5 mm, against 3.2.
