### An environment map lights the scene in place of the sky (#869)

- `engine_set_environment(e, path, intensity)` (`AE3D_ENV`, `AE3D_ENV_INTENSITY`):
  image-based lighting from a Radiance `.hdr` or an OpenEXR equirectangular map,
  on Vulkan and OpenGL, through the sky's own irradiance, GGX prefilter and
  split-sum path (the map replaces only the capture, once, not every frame).
  Unset, every frame is byte for byte what it was.
- `ae3d.radiance` (RGBE flat, new and old run-length, mirrored orientations)
  and `ae3d.openexr` (scanline, HALF/FLOAT, RGB(A) or Y, NONE/RLE/ZIPS/ZIP) decode
  to `ae3d.hdrimage` floats, from the formats' descriptions; other EXR
  compressions, tiled, deep and multipart files fail with a reason.
- `ae3d.shaders.envmap.env_capture`, a quote shader for SPIR-V, GLSL and MSL.
- Fixtures from `tools/make_env_fixtures.ae`; tests `test_envimage`,
  `test_gpu_envmap`, `test_environment`, and an environment case in
  `test_backend_parity`.
