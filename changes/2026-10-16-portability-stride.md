### Vulkan on the portability subset: no zero-stride skin binding, a present semaphore an image

- **A plain pipeline names no skin stream.** It named binding 2 at a stride
  of zero, every vertex reading one unused element, which the portability
  subset refuses (`VUID-VkVertexInputAttributeDescription-vertexAttributeAccessBeyondStride-04457`,
  MoltenVK on every run). Now only a skinned pipeline has binding 2 and
  attributes 8, 9 and 12; a plain one draws with `scene_plain_vk.vert` or
  `depth_plain_vk.vert`, the same shaders with `AE3D_UNSKINNED` defined,
  which hold what an unskinned vertex read (no joints, no weights, the
  second UV set (-1, -1)) as constants. OpenGL's shaders are unchanged.
  Every `test_backend_parity` frame is byte-identical to before on the M6,
  both renderers (`scripts/frames_against.sh`; the clouds within #793's
  tolerance).
- **A present semaphore a swapchain image**, not a frame in flight: a
  present holds its semaphore until the image comes back from the
  swapchain, which can be after its frame slot came round again, so the
  slot's submit signalled a semaphore the swapchain was still waiting on
  (`VUID-vkQueueSubmit-pSignalSemaphores-00067`, twice a run of
  zombie_city, the one suite that presents). Each image's is made the
  first time it is drawn to. zombie_city under the layer (`AE3D_TICK=60`,
  30 frames): 0 errors.
