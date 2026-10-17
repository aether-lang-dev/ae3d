### glslang 16.6.0, pinned

- **The checked-in SPIR-V is glslang 16.6.0's** (Nic, 2026-10-16; Debian's
  12.0.0 is too old to be the reference). `tools/generate_shaders` refuses
  any other `glslangValidator`, `--check` included, naming the version it
  found.
- **CI's suites runners take Khronos' release build**,
  `glslang-16.6.0-linux-x86_64-release.tar.gz`, through
  `scripts/glslang.sh`: the archive's sha256 and the binary's are checked,
  and it is cached by version, so a run fetches it once.
- **`generate_shaders --check` compares the SPIR-V bytes** as well as the
  GLSL text: it compiles what the source writes (a copy under
  `build/shaders/check`, never the checked-in GLSL) with the pinned glslang
  and holds `ae3d.vkspirv` to the module it would write, naming each shader
  whose words differ. One byte of `taa_vk.frag`'s words altered by hand
  fails it, by name; 43 shaders, 1,083,120 bytes, pass on the M6.
- glslang's per-file lines on stderr are kept and shown only when a shader
  fails to compile, so a failing check's first lines are its verdict.
