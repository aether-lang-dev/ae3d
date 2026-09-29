### The Vulkan modules build clean under clang and glibc's checks

- A render pass's dependencies took their subpasses as `int`, and Vulkan's
  `SUBPASS_EXTERNAL` is `~0u`: clang said so six times in every program
  (`-Wconstant-conversion`, 4294967295 to -1), which is every macOS build
  failing. They take `uint32`, the field's own type; the surface's extent
  is compared with `~0u` as a `uint32` constant rather than cast to -1.
  Every program's generated C (157 of them; the editor needs aether-ui)
  goes through clang's default warnings with none.
- A program that links the renderer and never starts it (`test_agent_cost`)
  failed Linux's build: the descriptor writes' scratch is made at the
  backend's start, gcc on glibc saw it never made there, and the fortified
  `memset` of a write given it null (`-Wnonnull`, in a part of
  `rewrite_shadow` gcc split out). The writes, and the tables the backend's
  reset and shutdown clear, are touched only where they exist. Reproduced
  on Windows by compiling the program through glibc's fortify wrappers,
  and gone with the fix.
