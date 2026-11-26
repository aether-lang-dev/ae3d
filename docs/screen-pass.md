# A program's own screen pass, and its own draws

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

## Where in the frame

`engine_set_screen_pass_rect(e, x, y, w, h)` draws the pass in a rectangle
of the frame instead of the whole of it: `w` by `h` from (x, y), in the
framebuffer's pixels from the top left (window points times
`platform.window_content_scale`). The rest of the frame is the scene's and
the clear colour's, with whatever the program draws over it: a panel of
`ae3d.menu` sliders above the picture, say. The quad fills the rectangle,
so the shader's `uv` runs across it, 0 to 1; `frag_coord()` stays the
frame's. `uv`'s y runs down the rectangle on Vulkan and up on OpenGL, so a
shader that measures from the top turns it over where `screen_y_sign()`
says 1. A raymarcher with sliders draws its shader this way, in the
640 x 480 rectangle under them.

## Many draws: a program's sprites

`engine_screen_draw(e, s, spirv, x, y, w, h)` queues a draw of a quoted
shader in a rectangle, with the shader's inputs as they are when it is
queued: the program sets them again and queues it again, as often as it
likes, a draw each, each with its own inputs. The draws are drawn over
every frame, after the screen pass and in the order queued, until the
program clears them (`engine_screen_draws_clear`) to queue the next lot;
a program that draws only when something changes queues only then.

```aether
engine.engine_screen_draws_clear(e)
engine.engine_set_screen_clip(e, x0, y0, w, h)          // what the draws after it are cut to
_c = gpu.set_vec3(ball, "colour", 1.0, 0.0, 0.0)
engine.engine_screen_draw(e, ball, spirv.ball(), x, y, 32, 32)
_c = gpu.set_vec3(ball, "colour", 0.0, 1.0, 0.0)
engine.engine_screen_draw(e, ball, spirv.ball(), x + 40, y, 32, 32)
```

Each draw is blended over what is there as a premultiplied colour is:
what the shader writes is already times its alpha, so a clear pixel (all
0) leaves the frame as it was and an alpha of 1 covers it. Its quad fills
its rectangle, `uv` 0 to 1 across it, as the screen pass's does; a
rectangle may run off the frame or its clip
(`engine_set_screen_clip`, 0 wide for the frame), which cuts it. Many
shaders may be queued, one after another in any order; each is made the
first time it is (its pipeline from its SPIR-V on Vulkan, its GLSL
compiled on OpenGL) and kept. `examples/screen_draws.ae` draws a ruled
backdrop, a draw of `fill` a line, and balls cut to a rectangle over it;
the same on Vulkan and OpenGL but for one pixel in 576,000, by 1/255. A
molecule viewer draws each atom this way, its own pixel shader for a
polished ball in its square, over its backdrop's lines: every atom where,
and as, reference frames drawn by another renderer have it, and no pixel
more than 2/255 from them.

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
every pixel (576,000 at 960 x 600, on an M6). A raymarched film drawn this
way is held to reference frames drawn by another renderer: 34 of 360,000
pixels more than 1/255 from them on Vulkan, 36 on OpenGL.
