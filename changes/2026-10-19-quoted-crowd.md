### The crowd's vertex shaders are written with quote

Step 6's mesh shaders, in Nic's order (docs/aether_quote_design.md section
11): after the water, the crowd. Its pixel shaders are the scene's and the
depth pass's, which move with the scene; until then the quoted vertex
shaders are drawn with the hand-written ones. The hand-written crowd
shaders go in a cleanup pull request after this.

- **`ae3d.shaders.throng`** is VERTEX_CROWD, its AE3D_PULL variant and
  VERTEX_CROWD_DEPTH in Aether: `crowd_vertex` (a figure posed from the pose
  bank at its own phase, or an impostor turned to the eye), `crowd_pull_vertex`
  (the same over the cluster cut's vertices, skin and figures pulled from
  storage by the index) and `crowd_depth_vertex` (posed into a shadow map, a
  figure past a lamp's reach dropped). `bone_at`, `skin_at` and
  `skin_at_phase` are the hand-written helpers; the bodies keep the
  hand-written statements' order. It is throng, not crowd: ae3d.crowd,
  ae3d.horde and ae3d.vkcrowd are the engine's.
- **Captured structs:** the draw's `Throng` (the model, the bank's frames,
  the impostor's grid and size, the walk's step, the cut's vertex bits) and
  the frame's `Eye` and a new `Shadow` (`ae3d.shaders.frame`: the map's light
  space and a lamp's reach), each field the scene block uniform it was.
- **What they hand on** is what FRAGMENT_DEFAULT and FRAGMENT_DEPTH read, by
  their names and at their places: the varyings struct's fields are named
  `fragTexCoord`, `Normal`, `FragPos` and so on.
- **ae3d.gpu:**
  - a vertex shader samples textures (the pose bank), after its block;
  - storage buffers, `Floats` and `Vec4s` (`floats_at`, `vec4s_at`), which a
    vertex shader reads at set 1, binding by capture, its own block and
    textures then at set 2 (`vertex_set`); OpenGL's GLSL of one, and a pixel
    shader reading one, are refused;
  - the calls `mul_fm4`, `mul_m4f`, `add_m4` (a skinning matrix weighed and
    summed a matrix at a time, as GLSL writes it), `mat4_cols`,
    `mat4_floats`, `m4_col`, `mul_m3` (mat3(m) * v), `texel_fetch_at`,
    `int_of` and `vertex_index`, each on the CPU too.
- **Vulkan:** `vkquote.vertex_ring_new` draws a quoted vertex shader with a
  hand-written pixel shader: its layout the scene's set, the cluster cut's
  pulled set for a shader reading storage, then its own, whose block is a
  dynamic uniform buffer, each draw's values at their own offset in its
  frame slot's ring (1024 draws), the pose bank named once a frame in a set
  of its own. A draw's values are copied word for word from the block the
  scene's ring takes for it. The lit crowd's opaque, culled and blended
  pipelines, the cut's and the shadow's are on the rings' layouts; where a
  ring would not make, the hand-written crowd's draw. **OpenGL** compiles
  the crowd program and the crowd's depth program from the quoted shaders'
  GLSL and the hand-written pixel shaders, and fills the structs from what
  the hand-written programs were sent.
- `tests/test_gpu_crowd.ae`, 32 checks: the GLSL in both dialects (golden
  fixtures; glslang and spirv-val), the places, the cut's sets, the refusals,
  every field's 32 bits from block words through the structs and back out,
  shaderlib's matrices, and on the CPU the lit crowd (48 vertices, figures
  and impostors, to 2.4e-7 of plain Aether posed from the bones themselves),
  the cut against the vertex input (to the bit) and the depth pass (12, to
  8.7e-8; a lamp's reach drops 4 of 6). Leak-free at -O0. Six negative
  controls fail it (fract dropped from the phase, mul_m3's third column,
  the figures' stride, the reach's comparison, vertex_set, the impostor's
  row).
- `test_quoted_hashes` holds the three shaders.
- **`VERTEX_CROWD`, `VERTEX_CROWD_DEPTH`, `crowd_vk.vert`, `crowd_pull_vk.vert`,
  `crowd_depth_vk.vert` and `vkpipes`' crowd pipelines are gone** (the
  cleanup after the frames above). With them go the nine scene-block
  uniforms only they read (134 uniforms, 15168 bytes; 53 shaders):
  poseBankFrames, the impostor's grid and size, crowdTravel,
  crowdPhaseStep, pullVertexBits and shadowReach. Vulkan keeps them in the
  crowd's own words (`vkframe.set_crowd_*`), which the rings copy from as
  they copy the rest from the scene's block. A crowd whose rings would not
  make draws through the skinned pipelines; `vkpipes` still makes the
  cluster cut's pulled set layout, which the cut's ring reads through.
