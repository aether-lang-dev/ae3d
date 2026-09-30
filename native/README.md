# The C under the engine

ae3d is written in Aether. This directory holds the C that remains -- two
files and a shim -- and each is here for a reason the language cannot meet
([#398](https://github.com/nicolas-maman/ae3d/issues/398)):

| folder | what | why still C |
|---|---|---|
| `platform/` | `crash.c`, the native stack printed on a crash; `metal_surface.m`, the CAMetalLayer MoltenVK draws into on macOS | a signal handler may call only what is async-signal-safe and has to be installed when the library loads, before any entry point; the Objective-C runtime |
| `dlss/` | `streamline.cpp`, DLSS through NVIDIA Streamline; `stub.c`, what is built without the SDK | the SDK's interface is C++ |

Everything else that was C is Aether now, each part moved on its own and
measured against the C it replaced in the same run on the same machine.

For a long time every file here had the same reason to be C: Aether had no
32-bit float, and everything a GPU reads is one. The language has `f32` now
([aether#2134](https://github.com/aether-lang-dev/aether/issues/2134)), and
what it made possible has moved: the mesh and instance stores
(`ae3d.geometry`), bone palettes and pose banks (`ae3d.posing`), the OBJ
builder (`ae3d.loader`) and the scene's mesh files (`ae3d.scene`), each the
same bits as the C it replaced.

Both renderers have followed. OpenGL's calls are `ae3d.gl`'s, over
`ae3d.glapi`, the GL entry points resolved from Aether (the process first,
then the window system's resolver); its offscreen context -- CGL on macOS,
a hidden GLFW window elsewhere -- is `ae3d.offscreen`'s; and it draws every
frame the same to the byte. Vulkan is Aether whole, on Aether's own Vulkan
bindings (`contrib.vulkan.vk`, #402): the loader, the instance, the
window's surface and the device (`ae3d.vkdevice`); the frame -- begun, its
passes opened and closed, its draws recorded, its post chain, DLSS,
submitted and presented or read back (`ae3d.vkframe`); what it draws into
(`ae3d.vktargets`), its pipelines (`ae3d.vkpipes`), its uniform blocks and
descriptor sets with the clustered lamps' buffers (`ae3d.vkdesc`); the
light meter (`ae3d.vkmeter`), the text and rectangles drawn over the frame
(`ae3d.vkoverlay`), reading a frame back, offscreen or captured
(`ae3d.vkreadback`); textures and the table a draw binds them from
(`ae3d.vktexture`); meshes, geometry that many models share uploaded once,
and the instance streams (`ae3d.vkmesh`); the acceleration structures the
shadow rays are traced through (`ae3d.vkrays`); the crowd sorted by a
compute pass on the device into the tiers it draws (`ae3d.vkcrowd`); their
buffers, images and command buffers `ae3d.vkhost`'s. `tools/generate_shaders.ae`
derives the Vulkan GLSL from the OpenGL sources in `src/ae3d/shaders`
(`src/ae3d/vkspirv/glsl`) and writes the SPIR-V (`ae3d.vkspirv`) and the
uniform block's offsets (`ae3d.vkscene`). Each part was moved as its own
step, and after each `tests/test_backend_parity` drew the same numbers
channel for channel.

What was C for other reasons has moved too: the crowd's kernels
(`ae3d.horde`), the flow field (`ae3d.nav`), the weather's particles
(`ae3d.weather`), the clouds' noise (`ae3d.cloudnoise`), the PNG writer
(`ae3d.png`), the file-as-bytes reader (`ae3d.blob`), the script loader
(`ae3d.script`), the agent channel, both sides (`ae3d.channel`,
`ae3d.probe`), the job pool (`ae3d.jobs`, on aephysics's scheduler; a loop
in a module a script imports, like the crowd's instance matrices, reaches
it through the runner `ae3d.jobs` installs in `ae3d.geometry`, where
`gpu/jobs.c` was the door -- a script's own copy of that module runs its
loops on the thread that calls them), the window, input and timing layer
(`ae3d.platform`, calling GLFW itself) and the frame capture the agent
reads a scene by (`ae3d.capture`). So is reading an image file: PNG, JPEG,
TGA and BMP decode in `ae3d.picture` (the JPEG in `ae3d.jpeg`, the PNG's
deflate in `ae3d.inflate`), where `image/` decoded them through the
vendored `stb_image.h`. Each decoder is stb's followed step for step, and
every image in the repository and 87 fixtures decode to the bytes stb gave
(`tests/test_image_decode`).

GLFW is called from both sides -- the window, input, the GL entry points
and the offscreen context from Aether, the Cocoa window's layer from
`platform/metal_surface.m` -- so it has to be one shared library, the one
every package manager ships; every program names it on its link line beside
the engine's.

There is no C API left to declare: the Aether modules bind the few entry
points here by `extern` directly. Every file compiles under
`-Wall -Wextra -Werror` on Linux, macOS and Windows (ci.sh checks each one
alone).
