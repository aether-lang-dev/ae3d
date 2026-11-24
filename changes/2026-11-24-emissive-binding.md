### The emissive map at binding 11

- On Vulkan the emissive map moves from binding 10 of the draw set to 11.
  The motion branch (#939, #855) puts the skin rows a skinned draw reads its
  palettes from at 10, and both live in one draw set once the branches
  meet. Regenerated: `lit_quoted.frag`, `lit_rq_quoted.frag` and their
  SPIR-V. The picture is unchanged: `test_emissive`, `test_backend_parity`
  and `test_gpu_lit` pass.
- `scripts/build_script.sh`: the Windows define for scripts' weak symbols
  sits in its own block, apart from the runtime-library line the motion
  branch rewrote.
