### Damage masks: blood, bruises and burns kept in UV space (#544)

- `core.model_enable_damage(m, size)` gives a model a four-channel damage
  mask over its second UV set, or its first.
  `core.model_damage_splat(m, centre, radius, channel, amount)` writes a hit
  at a bind-space point into it. Also `model_damage_fade`,
  `model_clear_damage`, `model_set_damage_colour` and `model_damage_at`.
- The mask is written on the CPU through a position map baked once (each
  texel's bind-space point). No render target is needed and the result is
  the same on both renderers. A hit on a 256 x 256 mask costs 0.22 ms.
- The second UV set: `mesh_set_uv1`, read from glTF's TEXCOORD_1, carried in
  the skin stream (now 48 bytes a vertex: joints, weights, UV1). Vertices
  without one fall back to the first set.
- OpenGL updates the mask with `glTexSubImage2D`. Vulkan copies it into the
  texture inside the frame (`vktexture.update_in_frame`), with no device
  wait, and binds it at binding 9.
- `tests/test_damage.ae`, on both renderers and under the validation layer.
