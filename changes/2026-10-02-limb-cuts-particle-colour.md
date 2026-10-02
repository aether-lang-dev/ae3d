### A cut kept to a limb (#556), particles in their colour (#557)

- `core.model_clip_joint(m, joint)` and `skin.skeleton_clip_limb(s, m, bone)`
  keep a model's cut to the vertices hanging off the named joints. The plane
  cuts where a vertex's skin weight on them is past one half, in the scene,
  the depth and every shadow. `core.model_set_clip_detached(m, true)` is a
  severed limb's loose copy: everything off the joints is gone too. With no
  joints named the cut is the whole model's, as before. The Vulkan block is
  11,168 bytes.
- Particles drew white whatever their colour. `model_set_instance_color`
  wrote a point instance's colour into a buffer no point reads; it now writes
  the point's own record and resends the stream. A red emitter now draws
  (163, 10, 12) on both renderers, where it drew (155, 148, 132).
- Tests: `test_skinned_render` cuts the column kept to its top five bones,
  plus the loose copy. `test_shadows` checks a skinned sphere's shadow
  through the same kind of cut. `test_instance_streams` recolours one grain
  on its own, and `test_particles` checks the emitter's colour in the stream.
