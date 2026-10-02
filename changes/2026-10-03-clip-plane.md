### A model cut by a plane (#545)

- `core.model_set_clip(m, normal, distance, noise, noise_scale)` cuts a model
  by a plane in its bind space; `model_clear_clip` takes it away. Nothing on
  the normal's side is drawn: not in the scene, not in the depth the
  occlusion, reflections and water read, not in any shadow. The plane
  turned round is the other side, for a severed limb's loose copy. Value
  noise wanders the cut for a ragged edge, the same in the scene's fragment
  shader and the depth one.
- Every vertex shader -- the scene's, the crowd's, the two depth ones --
  hands its fragments the vertex before it was skinned (`BindPos`); the
  depth passes have a varying for the first time.
- A cut model never merges into a batched draw or cast, and on Vulkan keeps
  the shadow map rather than the rays.
- Held on both renderers: a skinned column cut at half its height draws half
  (923 of 1,846 pixels), the plane turned round the other half, a ragged cut
  differs from the clean one, a bent column cut down its middle keeps half
  of itself (the cut is on the body); a sphere cut in half casts half its
  shadow (670 of 1,340 pixels). zombie_city at 20,000 costs what it cost.
