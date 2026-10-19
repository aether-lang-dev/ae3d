### The water's surface is drawn by shaders written with quote

Step 6's mesh shaders begin (docs/aether_quote_design.md section 11): the
water, as a vertex and a pixel quote, drawn on both renderers. The
hand-written water shaders went in a cleanup pull request after it.

- **`Light[16]` probed first:** Aether 0.829.0's quote types a captured
  struct's `Light[16]` field as `Light[16]`, an element as `Light` and its
  field as `vec4`; `mat4[96]` likewise. The scene's lights need nothing of
  aether.
- **`ae3d.shaders.sea`** is VERTEX_WATER and FRAGMENT_WATER in Aether.
  `sea_vertex` raises the sheet by the four Gerstner trains and sums them
  under the eye; `sea` lights the surface (the wave field summed per pixel,
  the mirrored sky, glitter, foam, caustics, fog, the shore, the underside)
  and writes its colour and motion vector. waveField's `out` parameters are
  its body written into the pixel shader's. The helpers keep the
  hand-written shapes; the sky's are skydome's.
- **The scene block split, for the water:** four captured structs, the
  frame's `Eye`, `KeyLight` and `Weather` (`ae3d.shaders.frame`) and the
  draw's `Water`, each field the uniform it was. `Eye`, not `Camera`:
  importing a second `Camera` beside `ae3d.core`'s made the engine's own
  unqualified `Camera` ambiguous in every module that took both.
- **ae3d.gpu:**
  - a captured struct holds `mat4` fields, written, run and set by name;
  - `set_field_words` fills a field from a uniform block's std140 words,
    which is how Vulkan copies the water program's block, word for word;
  - `mat2` (`mat2_of`, `mul_m2`), `fract_v3` and `vec3_xv` join the calls;
  - a vertex shader with a local named as a varying is refused (the out
    was never written: the local hid it), and so is a pair that captures a
    struct under one name (one uniform on OpenGL, declared twice).
- **Vulkan:** `vkquote.mesh_pair_new` draws a pair over a model's mesh
  through opaque, culled and blended pipelines on its own layout, up to 64
  draws a frame. A water draw goes through it with the images the scene's
  set bound (the sky's image, the camera's depth, the ripples' mask, the
  sky's light and irradiance). **OpenGL** compiles the pair at start and
  fills the structs from what it gave the hand-written program, in the
  same order, a model's uniforms by name through the same table; its images
  stay on the units the scene's draws bind them on.
- **Shapes MoltenVK rounds by:** the shore's `water_below`, as a helper
  given the inverse view-projection, left 117 channels of the shore case a
  step out; written where it is used, reading its values there as the
  hand-written one read its uniforms, it is main's. The vertex shader keeps
  handing on the uv and the trains' normal, and `noised` builds its result
  in one constructor, as the hand-written ones did.
- `tests/test_gpu_sea.ae`, 30 checks: the GLSL in both dialects (golden
  fixtures; glslang and spirv-val), the link at the hand-written places,
  every field's 32 bits from block words through the structs and back out
  (61 values), both refusals, mat2, and on the CPU the vertex shader (still
  trains to 1.2e-6 of plain Aether; varied ones within the noise's reach)
  and the pixel shader in six cases (to 4.1e-4), each case's feature shown
  at its points. Leak-free at -O0. Five negative controls fail it (a
  Fresnel constant, set_field_words' stride, the link guard, the varying
  check, mul_m2's columns).
- `test_quoted_hashes` holds both trees, and now exits 1 when one fails
  (it printed FAIL and exited 0).
- Frames on an Apple M6: `frames_against.sh` against main, 59 frames, none
  differ (the clouds within #793); test_backend_parity at 1x and 4x
  byte-identical to main's but the clouds; zombie_city and street_drive at
  AE3D_TICK=60 main's frames in each mode (#794). The water, sky-lit,
  composite and scene suites print main's numbers (test_water_sky
  40.324, 129, 55.6744 on Vulkan). Khronos validation with sync, nothing
  excluded: 0 errors, parity, both scenes, the water suites and the flood,
  floating and caustics examples.
- **`VERTEX_WATER`, `FRAGMENT_WATER`, `water_vk.vert`/`.frag` and `vkpipes`'
  water pipelines are gone** (the cleanup after the frames above). The
  water's shader is a kind with no source (`shaders.water_shader()`):
  `core.shader_valid` holds a named kind valid on its own, OpenGL compiles a
  model's own GLSL only for a custom shader, and a Vulkan water draw whose
  pair would not make draws nothing. With them go 34 scene-block uniforms
  only they read (143 uniforms, 15216 bytes; 53 shaders): the wave table and
  the surface's settings, the key light's four flat names, and the overcast.
  Vulkan keeps them, in the same 32-bit words, where the water's pair copies
  them from: the overcast in the sky's words (`SKY_OVERCAST`,
  `SKY_OVERCAST_COLOUR`, which the quoted sky and `vksky` read too), every
  other in the water's own (`vkframe.water_word`), which a water draw's model
  uniforms the block has no member for are written to, and the key light
  each frame. `frames_against.sh`: 59 frames, none differ but the clouds
  (#793); parity at 1x main's but the clouds.
