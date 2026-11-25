# A program's own screen pass

A program can draw a full-screen pixel shader of its own, written in Aether
with `quote`, over every frame ae3d makes: a picture made by the shader
alone (a raymarch, a fractal, the rings of `examples/screen_pass.ae`), or a
pass over the scene. ae3d draws it last, after the scene's tone curve and
FXAA and before the view blits, so what it writes is shown as it is.

```aether
s = screenpass.rings(vec2(960.0, 600.0), 0.0)           // the program's quoted shader
engine.engine_set_screen_pass(e, s, screenpass_spirv.rings())
...
_t = gpu.set_float(s, "time", t)                         // each frame, its inputs by name
...
engine.engine_set_screen_pass(e, null, null)             // off; the shader stays the program's
gpu.shader_free(s)
```

## The shader

A `fragment(name) quote | uv: vec2 | { ... }`, as ae3d's own passes are
(`ae3d.shaders.fxaa`): its inputs are what it captures, the parameters of
the function that makes it, set between frames with `gpu.set_float`,
`set_vec2`, `set_vec3`, `set_int` and `set_mat4`. It may sample textures,
or none. `@quotable` functions are written out beside it. `frag_coord()` is
the backend's own: y runs down the frame on Vulkan and up on OpenGL, so a
shader that measures from the top turns it over where `screen_y_sign()` is
1 (`examples/lib/screenpass`).

## Vulkan: SPIR-V made at the program's build

ae3d's Vulkan backend compiles no GLSL at run time: its own shaders are
SPIR-V made by `tools/generate_shaders.ae`. A program's are made the same
way, by a small generator of its own that calls `ae3d.quotegen`:

```aether
import ae3d.quotegen
import examples.lib.screenpass

main() {
    g = quotegen.begin("examples/lib/screenpass_spirv/module.ae", "examples/screen_pass.ae's pass")
    quotegen.add(g, "rings", screenpass.rings(vec2(1.0, 1.0), 0.0))
    os.exit(quotegen.finish(g))
}
```

`quotegen` writes each shader's Vulkan GLSL (its screen vertex shader and
its pixel shader), compiles both with `glslangValidator` (on PATH; any
version, which the module names), and writes an Aether module whose
`rings()` is a `*gpu.QuotedSpirv`: the words, and the hash of the tree they
were made from. The values the tree is made with do not matter; its shape
does. A program whose shader has changed since its SPIR-V was made stops
when the pass is made, naming the shader and saying to run its generator
again, as ae3d does for its own (`vkquote.fresh`).

OpenGL compiles the tree's GLSL when the pass is set, and needs no SPIR-V:
`engine_set_screen_pass(e, s, null)` is enough there. On Vulkan a pass with
no SPIR-V is left out, and said.

## Checked by

`examples/screen_pass.ae` draws the same picture on Vulkan and on OpenGL,
every pixel (576,000 at 960 x 600, on an M6). The Aether port of Chris
Hinsley's Raymarch (ChrysaLisp's `apps/demos/raymarch`) draws his film
shader this way and is held to his own native code's frames: 44 of 360,000
pixels more than 1/255 from his on Vulkan, 46 on OpenGL.
