### Textures held while drawn; CI green on every runner

- A renderer holds a material's textures while any model it draws uses
  that material (`Material.renderer_users`, `Model.materials_held`, both
  renderers), and lets them go with the last such model. The fix covers:
  - OpenGL let a texture go once per model taken out. Two models sharing
    a material had it deleted under the second, and a model put back drew
    a deleted id.
  - Vulkan never let a texture go.
  - A group with no material of its own draws with the model's, so that
    is the material held.
  - A model uploaded again for a geometry change keeps its texture.
  - An id set with no path (a view's picture) is left as it was set.
  - `vulkan.renderer_texture_count` is new.
- `test_texture_release`, new: the shared, both-out, put-back and
  reupload cases, on both renderers.
- The Vulkan opaque prepass is on by default on a GPU and off on a CPU
  rasterizer (lavapipe, SwiftShader). There it cost 152.6 ms against
  144.2 ms without on llvmpipe. `AE3D_PREPASS` or
  `renderer_set_prepass` still decides it either way.
- `test_vk_prepass` measures the prepass off and on in turns, frame by
  frame, and takes the median of each. Back-to-back runs took in whatever
  else the GPU was doing, and the best of eight frames kept a reading of
  13 µs for 120 full-screen layers. It now holds a ratio under 0.7
  (0.21 to 0.58 measured).
- `test_vk_stages` takes each stage's median over 16 frames instead of a
  sum. Under MoltenVK, one frame in a few charged the wait before a pass
  to camera depth.
- Scripts on Windows: `@c_callback` functions are weak definitions, and
  GNU ld leaves weak symbols out of a DLL's exports, so every script was
  refused for not saying its layout. `scripts/build_script.sh` builds them
  as ordinary definitions there (`-DAETHER_WEAK_DEF=`). This was checked
  with MinGW on the generated C: `w script_layout_hash` became
  `T script_layout_hash`, and is exported.
- `test_gpu_lit` and `test_gpu_lit_rq` pass the emissive map
  `lit_pixel` gained, and the GL fixtures `lit_gl.frag` and
  `pick_gl.frag` now hold its uniform and sampler.
- ci.sh lists the drawing suites added on this branch (`test_emissive`,
  `test_hidden_size`, `test_hud_hold`, `test_texture_release`,
  `test_vk_prepass`, `test_vk_rings`, `test_vk_stages`) in `GPU_SUITES`, so
  runners with no GPU skip them.
