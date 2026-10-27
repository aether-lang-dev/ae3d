### Fixes found running the pick and views change through the local gate

- The renderers free what the views and the pick pass allocate. Vulkan's
  renderer frees its view list, view targets and kept state, and a view's
  lazily made bloom, cloud, reflection-blur and temporal arrays go with it;
  OpenGL's frees the pick targets, the pick and view-blit programs and shaders,
  and its blit and view lists. Before, `leaks --atExit` failed about 130 suites.
- A sampler's mip bias is applied only where the device can bias, and the
  portability subset's features the device has are enabled: the render-scale
  bias was refused by the validation layer (VUID-VkSamplerCreateInfo-
  samplerMipLodBias-04467) on MoltenVK.
- `frame.pixel`'s colour no longer leaks four JSON numbers a read
  (`colour_json`).
- `test_agent_pick` and `test_engine_view` ask about pixels at their own size,
  so `AE3D_WIDTH`/`AE3D_HEIGHT` (which `ci.sh` sets) no longer move what is
  under them; `test_gpu_pick`, `test_view_swap` and `test_pick_crowd` free what
  they made.
