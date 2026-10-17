### frames_against builds each tree with the Aether it pins

- **`scripts/frames_against.sh` builds this tree and `ref` each with the
  Aether release its `.github/workflows/ci.yml` pins (`AETHER_REF`).** With
  one toolchain for both, a release that names a quote's helpers otherwise
  (aether#2943) hashed the other tree's quoted shaders otherwise, its Vulkan
  refused their SPIR-V, and no frame was drawn to compare. A pin the
  toolchain on PATH is uses it; another is built once from an Aether
  checkout at its tag (`AE3D_AETHER_SRC`, `../aether` by default) under
  `build/frames_against/aether-<tag>` and kept. With no checkout, or no such
  tag in it, the script says which pin it cannot build and stops (exit 2)
  rather than compare frames made by the wrong compiler.
