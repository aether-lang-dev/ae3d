### Damage masks for a horde: one atlas page (#560)

- `core.damage_atlas_new(page, cell)` and `core.model_enable_damage_in(m,
  atlas)`: many models' masks as cells of one texture. A changed cell is
  written into its square of the page (`glTexSubImage2D` on OpenGL,
  `vktexture.update_region_in_frame` on Vulkan). The shader reads the
  cell's rectangle, clamped half a texel inside it.
- 300 damaged figures on Vulkan: with a mask texture apiece their blood
  showed on 253 (the renderer's 256 textures and sets a frame); in an atlas,
  on all 300. OpenGL shows 300 either way.
- A frame slot's in-frame texture writes are no longer capped at 64.
