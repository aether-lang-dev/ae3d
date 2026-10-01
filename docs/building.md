# Building

The toolchain, the dependencies on each platform, the build scripts, the
continuous integration gate, and the environment variables every program
honours.

## Requirements

- The [Aether toolchain](https://github.com/aether-lang-dev/aether): `ae`
  and `aetherc` on `PATH`, 0.743 or later. `std.observe` and `struct T
  @observable` (0.727, aether-lang-dev/aether#2220) are how a script's own
  stores on a component reach the inspector, a save and the network
  ([components](components.md)). In 0.743 `T[]` became a slice, a pointer
  with its length (aether-lang-dev/aether#1286). The engine and aephysics
  are written to it, and generated code and scripts call the runtime's
  bounds checks. On Windows, 0.743 itself needs
  aether-lang-dev/aether#2305 (the checks spell the source path with
  unescaped backslashes).
- A C compiler (`cc`, `gcc` or `clang`), for the C under `native/` and for
  the C Aether generates. On Windows the build also makes
  `build/aether_runtime.dll` from the toolchain's `libaether.a` (the whole
  archive, with the optional libraries it calls into, such as zstd), which
  every program and every script links, so a script and the program that
  loads it share one runtime ([components](components.md#scripts)).
- GLFW 3.3 or later as a shared library (the one every package manager
  ships: the window layer calls it from Aether and the renderers from C,
  and a static copy in each would be two libraries with two states), zlib,
  `pkg-config`, and the Vulkan headers. The Vulkan loader is opened at run
  time; a Vulkan driver is optional (the engine falls back to OpenGL when
  `AE3D_API=opengl`, and the tests run on either).
- No Python: the build, the gate and every tool are Aether. `tools/blender/`
  is Python because it runs inside Blender.

```bash
brew install glfw molten-vk vulkan-loader                        # macOS
sudo apt install libglfw3-dev libvulkan-dev mesa-vulkan-drivers  # Debian/Ubuntu
pacman -S mingw-w64-ucrt-x86_64-{gcc,glfw,zlib,pkgconf,vulkan-headers,vulkan-loader}  # Windows, MSYS2 UCRT64
```

On Windows the build runs in an MSYS2 **UCRT64** shell. The Aether
toolchain links the Universal C runtime, and a UCRT `libaether.a` does not
link against an msvcrt gcc; the failure looks like the engine's
(`__imp__get_timezone`, `__imp__strtof_l`) and is not. A checkout outside
MSYS2 names its GLFW by hand:

```bash
GLFW_CFLAGS="-I/c/msys64/ucrt64/include" GLFW_LIBS="-L/c/msys64/ucrt64/lib -lglfw3" ./build.sh examples/spinning_cube.ae
```

## Building a program

With the toolchain alone, from the repository root:

```bash
git submodule update --init                 # deps/aephysics, the physics engine
ae run examples/spinning_cube.ae            # build (cached) and run
ae build examples/physics.ae -o build/physics
```

`aether.toml` declares aephysics as a dependency patched to its submodule
(which exports its root, so `aephysics.*` needs no `--lib`) and compiles
everything with `-ffp-contract=off`, as `build.sh` does. The rest comes from
the modules a program imports: `ae3d.core` names the crash handler
(`@source`), `ae3d.vkdevice` the DLSS stub and, on macOS, the Metal layer,
and `ae3d.platform` links GLFW and the system's windowing and GL libraries
for the platform it is built on (`@link` in a `when target.os` arm; MSYS2
calls GLFW `glfw3`). A library search path the machine needs, Homebrew's
`/opt/homebrew/lib` and its include directory, goes in `LIBRARY_PATH` and
`CPATH`. The examples' shared code is imported by its path from the root
(`import examples.lib.blackhole`).

`build.sh` builds the same programs another way, which a program that loads
scripts needs: the engine's C as one shared library that the program and
every script link, and the DLSS shim against the Streamline SDK. It leaves
out of the program the `@source` files that library carries, so a program
has one crash handler and the real DLSS, not the stub.

```bash
./build.sh examples/spinning_cube.ae        # -> build/spinning_cube
./build.sh examples/zombie_city.ae city     # -> build/city
./build.sh --natives                        # the engine's C library only
```

`build.sh` compiles the C under `native/` into `build/obj/` (only what
changed, every file under `-Wall -Wextra`), links it as the engine library,
says so if `src/ae3d/shaders` is newer than the generated Vulkan shaders,
compiles the program with `aetherc` to `build/<name>.c` and links the
result. `--natives` builds the library and stops, for a script (a shared
library loaded by `ae3d.script`) that links the same engine its host does.
Module resolution is relative to the repository root, so the script always
runs from there whatever directory it was called from.

The variables the script reads, each with a default that finds the usual
install: `CC`, `CFLAGS`, `GLFW_CFLAGS`/`GLFW_LIBS`,
`VULKAN_SDK` (for the headers when `pkg-config` does not know Vulkan), and
`AE3D_STREAMLINE_ROOT` for DLSS (below), and `AE3D_CC_LAUNCHER`, a program run in front of every compile (`ccache` on the runners: a program whose generated C has not changed since the last run is not compiled again).

## The editor

The editor's chrome is [aether-ui](https://github.com/aether-lang-dev/aether-ui),
in its own repository. Point `AETHER_UI_ROOT` at a checkout or leave a
sibling `../aether-ui`:

```bash
git clone https://github.com/aether-lang-dev/aether-ui.git ../aether-ui
./editor/build_editor.sh && ./build/ae3d_editor
```

Linux needs GTK 4 and epoxy; macOS uses AppKit; Windows the Win32 backend.
`AETHER_UI_REF` in `.github/workflows/ci.yml` pins the toolkit commit CI
builds the editor against, and each bump carries a line saying why.

## The shaders

`src/ae3d/shaders/module.ae` holds the GLSL, written once for OpenGL.
`tools/generate_shaders.ae` derives the Vulkan versions -- the GLSL in
`src/ae3d/vkspirv/glsl`, the SPIR-V in `src/ae3d/vkspirv` and the uniform
block's offsets in `src/ae3d/vkscene` --
asks `glslangValidator` (the Vulkan SDK, on `PATH`) for its own std140
offsets and stops on the first disagreement:

```bash
./build.sh tools/generate_shaders.ae && ./build/generate_shaders
./build/generate_shaders --check            # is the committed output current? (no SDK needed)
```

`build.sh` says when the source is newer than the output, and `ci.sh`
runs the check and fails when it is stale.

## DLSS

DLSS goes through NVIDIA Streamline on Vulkan. With
`AE3D_STREAMLINE_ROOT` pointing at the SDK, `scripts/native.sh` compiles
`native/dlss/streamline.cpp` in place of the stub, and at run time
`AE3D_STREAMLINE` names the directory the runtime's DLLs are in (or they
sit beside the program). `AE3D_DLSS=n` picks the mode. Without the SDK the
stub is built and `engine_set_dlss` reports the feature absent.

## The gate: `ci.sh`

`./ci.sh` is the whole gate, run on the machine a change is written on
before its pull request is merged:

1. the C under `native/` compiled file by file with warnings as errors;
2. every module type-checked alone, every example's library likewise;
3. the generated Vulkan shaders and the agent's documentation checked
   against their sources;
4. every test suite built and run, every benchmark built and run;
5. every example run hidden for a bounded number of frames
   (`AE3D_CI_EXAMPLE_FRAMES`, 10), at a quarter of the width and height on
   a runner without a GPU;
6. the demo rig (`tools/zombie_street.ae`) critiqued on both backends and
   held to its recorded frame cost;
7. the editor built, its names checked, and driven through its test
   driver on each backend;
8. the headless programs checked for leaks.

The runners run the same script, each over the part its platform is there
for (`AE3D_CI_TIER`, set in the workflow's matrix, #511):

| runner | tier | what it runs |
|---|---|---|
| Linux | `suites` | every suite, the readback suites again under the Vulkan validation layer, the checks of what is generated from the tree, and the benchmarks' smoke run |
| Linux | `apps` | the examples and the editor, its bounded run on OpenGL only through the saved and reopened scene; the showcase scenes (item 6, `scripts/ci_scenes.sh`) only with `AE3D_CI_SCENES=1` |
| macOS | `leaks` | every suite, each then held to `leaks`, several at a time |
| Windows | `platform` | the suites over code that differs by platform: sockets, threads, files and formats, float rounding, scripts |

The two Linux tiers run at once on two runners; `full` is both on one
machine. With no tier, the whole gate runs, scenes included. `AE3D_CI_SCENES=1` adds
the scenes to a runner's tier. A pull request that changes only prose
(`*.md` but `docs/agent.md`, `changes/`) starts no run, and a push cancels
the run under way for the one before it. A change to the workflow runs on
main once it lands, which saves the caches every later pull request
restores: a pull request reads its own and main's, never another's.

The knobs: `AE3D_CI_FRAMES`, `AE3D_CI_EXAMPLE_FRAMES`, `AE3D_CI_WIDTH`/`HEIGHT`,
`AE3D_CI_JOBS`, `AE3D_CI_RUN_LIMIT`, `AE3D_CI_TIER`, `AE3D_CI_SCENES=1`, `AE3D_CI_GPU=0` (no suite that draws is built: the macOS and Windows runners can open no window), `AE3D_CI_TRACE=1` for a trace of every
command, `AE3D_SKIP_LEAKS=1`. A pull request is the unit of review, so the
runners' checks are on the pull request; a branch without one is not built.

## Environment variables

Every program built on the engine honours these; nothing in a program has
to read them.

| Variable | Effect |
|---|---|
| `AE3D_API=opengl` | run through OpenGL instead of Vulkan |
| `AE3D_FRAMES=n` | stop after `n` frames, so any example is a smoke test |
| `AE3D_HIDDEN=1` | no window on screen; rendering still happens |
| `AE3D_WIDTH`, `AE3D_HEIGHT` | the window's size |
| `AE3D_SNAPSHOT=path.png` | write the last frame; `AE3D_SNAPSHOT_BURST=k` for the last `k` |
| `AE3D_PERF=1` | print the frame's cost by stage at exit ([performance.md](performance.md)) |
| `AE3D_JOBS=n` | the job pool's thread count, the machine's by default |
| `AE3D_AGENT=port` | open the control channel on loopback; `auto` for a port the system picks, written to `AE3D_AGENT_PORT_FILE` ([agent.md](agent.md)) |
| `AE3D_AGENT_RECORD=path` | write the channel's whole session to `path`, every request and answer, for `tools/agent_replay.ae` ([agent.md](agent.md#recording-a-session-and-replaying-it)) |
| `AE3D_MSAA=n`, `AE3D_TAA=1`, `AE3D_SSAO=1`, `AE3D_SSR=1` | the anti-aliasing and screen-space passes |
| `AE3D_RAYS=1` | shadows by ray through the scene's acceleration structure, where the device has ray queries |
| `AE3D_RAY_SKINNED=n` | how many skinned figures the rays pose a frame, the nearest first (32; 0 leaves them to the shadow map) |
| `AE3D_SUN_SIZE=n` | the sun's size for the rays' penumbra, in tenths of a degree (5 is the sun; 0, the default, a point) |
| `AE3D_RAY_AO=1` | ambient occlusion by ray in the screen-space pass's place |
| `AE3D_DLSS=n` | DLSS at mode `n` (1 performance, 2 balanced, 3 quality, 6 DLAA) |
| `AE3D_RENDER_SCALE=50` | draw the scene at half the window's size, the composite scaling it up |
| `AE3D_TIME=HHMM` | the time of day, where a scene takes one |
| `AE3D_WEATHER=rain\|snow\|dust\|storm` | the weather over a scene that takes one; `AE3D_WEATHER_LEVEL` its strength |
| `AE3D_CROWD=n` | the crowd's count in the crowd examples; `zombie_city`'s horde hunts the camera, `AE3D_HUNT=0` lets it wander |
| `AE3D_CAMERA_WANDER=n` | fly the camera at random for `n` frames by injected keys and say the nearest it came to anything drawn ([rendering.md](rendering.md#the-camera)); `AE3D_CAMERA_WANDER_SPEED`, `_RANGE`, `_SEED` |
| `AE3D_PHYSICS_SCENE=pyramid\|pile\|ragdolls\|cloth` | the reference scene `examples/physics` runs |
| `AE3D_VIEW=3`, `AE3D_CAMX/Y/Z`, `AE3D_AIMX/Y/Z` | a camera placed by number, for sweeps ([testing.md](testing.md)) |
| `AE3D_TICK=60`, `AE3D_HOLD=90` | every frame advances the world and the renderers' clock by 1/60 s whatever the wall clock did, and the agent channel holds the scene at frame 90: the same frame on every run and on either renderer ([testing.md](testing.md#the-scenes-on-both-renderers)) |
| `AE3D_EYE=0` | the eye's adaptation off, where a scene turns it on |
| `AE3D_DIAG=1` | a scene's own diagnostics on the console |
| `AE3D_FONT_CACHE=dir` | where baked glyph atlases are kept, `build/cache/fonts` by default; `off` bakes every time ([ui.md](ui.md)) |

The scene-specific ones (`AE3D_LAMP`, `AE3D_MOON`, `AE3D_NOPROPS`, ...) are
documented in the example that reads them.

## Scratch and output

Programs go to `build/`, objects to `build/obj/`, generated C to
`build/<name>.c`. Anything a job makes on the way (captures, contact
sheets, measurements) goes under `build/scratch/` and is not committed.
