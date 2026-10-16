### glslang 16.6.0, pinned

- **The checked-in SPIR-V is glslang 16.6.0's** (Nic, 2026-10-16; Debian's
  12.0.0 is too old to be the reference). `tools/generate_shaders` refuses
  any other `glslangValidator`, `--check` included, naming the version it
  found.
- **CI's suites runners take Khronos' release build**,
  `glslang-16.6.0-linux-x86_64-release.tar.gz`, through
  `scripts/glslang.sh`: the archive's sha256 and the binary's are checked,
  and it is cached by version, so a run fetches it once.
