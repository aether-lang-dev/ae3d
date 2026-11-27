# A program's own canvas

A program can draw meshes of its own with shaders of its own, written in
Aether with `quote`, into a canvas: a picture with depth, the program's,
drawn each frame before the frame's own passes and shown in a rectangle of
the frame as its shaders wrote it, through no tone curve. A world of the
program's making (a flight over hills a vertex shader raises), or anything
a vertex and a pixel shader of its own draw better than ae3d's materials.

```aether
canvas = engine.engine_canvas_new(e, 480, 480)          // once the engine has started
globe = engine.engine_mesh_new(e, mesh)                  // an ae3d.core mesh of the program's
...
_l = gpu.set_m4(vs, "lens", engine.engine_canvas_lens(e, frustum))   // each frame
engine.engine_canvas_begin(e, canvas, 0.1, 0.12, 0.2, 1.0)           // cleared to, and the last frame's draws off
engine.engine_canvas_draw(e, canvas, vs, ps, globe_spirv.globe(), globe, true, null, 0)
engine.engine_canvas_show(e, canvas, x, y, 480, 480)
```

## The pair

`vs` is a vertex shader, `ae3d.gpu`'s `vertex(name) quote | v: V | {...}`:
its parameter a struct of the mesh's vertex, fields named as ae3d's vertex
has them (`position`, `uv`, `normal`), and it returns a struct of its clip
`position` and its varyings. `ps` is a pixel shader whose parameter is that
struct. Each has its inputs, the parameters of the functions that make
them, set between frames with `gpu.set_float`, `set_vec3`, `set_m4` (an
`ae3d.shaderlib` `mat4`) and the rest. The pixel shader may sample
textures, given to the draw as the renderer's texture handles in its order.

A draw takes both shaders' inputs as they are when it is queued: the
program sets them again and queues the same pair for the next mesh, a draw
each. Draws are depth-tested and written, in the order queued, a mesh's
back faces culled when asked. They stay queued, drawn every frame, until
`engine_canvas_begin` clears them; a program that changes nothing queues
nothing.

## Clip space

A canvas's vertex shader writes OpenGL's clip space on both renderers, y
up and z from -1 to 1 as a frustum makes it, when the matrix it multiplies
by has been through `engine_canvas_lens`: on OpenGL that is the matrix as
it is, on Vulkan its y turned over and its z halved into 0 to 1, as ae3d
does its own camera's (`vkdesc.clip_correct`).

## Vulkan: SPIR-V made at the program's build

As a screen pass's (`docs/screen-pass.md`), a pair's SPIR-V is made by a
small generator of the program's own, with `ae3d.quotegen.add_pair`, which
links the two by their varyings:

```aether
g = quotegen.begin("examples/lib/canvasglobe_spirv/module.ae", "examples/canvas.ae's pair")
quotegen.add_pair(g, "globe", canvasglobe.globe_vertex(ident(), ident()), canvasglobe.globe_lit(...))
os.exit(quotegen.finish(g))
```

Its hash is of both trees (`gpu.pair_hash`); a pair whose shaders have
changed since stops the program when it is first drawn, naming them.
OpenGL compiles the pair's GLSL the first time a pair of its shape is
queued.

## How it is drawn

On Vulkan a canvas is a colour image of the display's format and a depth
image, drawn by a render pass of its own (`ae3d.vkcanvas`) at the start of
the frame's commands, each pair a pass of its own made the first time it
is queued and grown as more of its draws are. On OpenGL it is an offscreen
target with depth, drawn at the start of the frame. Either way it is shown
through the view blit, as a view's picture is (`engine_view_blit`): its
colour written as it is and sampled through an sRGB view, so what was
written is what is shown.

## Checked by

`examples/canvas.ae` draws a turning globe, lit by the sun in bands of
latitude, into a 480 x 480 canvas in the middle of the frame: the same on
Vulkan and OpenGL to 1/255 at every pixel of 576,000, with nothing from
the Vulkan validation layer. A flight over a land draws its sky and its
land this way, a grid of 128 x 128 cells its vertex shader raises into
hills and moves under the eye, and is held to reference frames drawn by
another renderer: at three places on its way, no more than 71 pixels of
307,200 more than 2/255 from them, on Vulkan and on OpenGL. A pair whose
vertex shader has no input, a sky's corners in clip space, is drawn as
well.

## A frame from a host: `ae3d.batch`

A host that is not Aether, a sae page running three.js, describes its frame
in one buffer a frame (`ae3d.batch`, its layout in the module's header): the
eye's view and lens, each draw's world matrix and material, and the meshes
that are new or changed since. `batch_submit` checks the buffer whole and
refuses one that is malformed or over the host's limits with its reason,
changing nothing; it then queues a canvas draw for each of the buffer's
draws with ae3d's own pair for its material (`ae3d.batchmaterials`: the
first is three.js's MeshNormalMaterial). `batch_draw` draws the canvas and
`batch_pixels` reads it back, rows top first, for a host that composites
the picture itself. OpenGL only so far.

```aether
b = batch.batch_new(renderer, 640, 480)          // a GLRenderer that is up, no window needed
batch.batch_set_limits(b, 256, 1000000, 4096)    // meshes, vertices, draws
why = batch.batch_submit(b, data, bytes)         // "" or why it was refused
batch.batch_draw(b)
pixels = batch.batch_pixels(b)
```

`tests/test_batch` holds it to a cube's pose worked out by hand, and draws
three.js's README cube from the batches its `AeRenderer` made on sae's
engine, held by three.js's own maths to within 1/255.
