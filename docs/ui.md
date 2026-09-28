# The game UI layer

A game needs a HUD and menus: health and ammo, a crosshair, a prompt, a
pause menu, a lobby. The engine drew no text and nothing in screen space,
and the editor's panels are aether-ui, which does not belong in a game's
frame. #449 built the layer in four slices; this page describes it.

| Slice | What | Where |
|---|---|---|
| 1. Glyphs | A TrueType reader and a signed-distance-field atlas baked from it | `ae3d.glyphs` |
| 2. The overlay pass | Text, rectangles and images in the window's pixels, one draw after post, on both renderers | `ae3d.hud` |
| 3. Layout | Anchors, DPI-scaled offsets, alignment, wrapping, clipping panels, images (#459) | `ae3d.ui2d`, `ae3d.hud` |
| 4. Input | Hit testing, focus, widgets and a menu stack through `ae3d.input`, shared by the game and the editor's play mode (#484, #460) | `ae3d.ui2d`, `ae3d.input` |

What a game writes:

```aether
ui = engine.engine_ui(e)
hud = ui2d.layer(ui)                                        // drawn over the frame, after post
bar = ui2d.rect(hud, ui2d.BOTTOM_LEFT, 24.0, -24.0, 300.0, 18.0, colour)
ui2d.set_fill(bar, health / 100.0)                          // a bar is a rect with a fill
label = ui2d.text(hud, ui2d.CENTER, 0.0, 60.0, "E to get in", 28.0)
ui2d.image(hud, ui2d.TOP_RIGHT, -20.0, 20.0, 256.0, 256.0, minimap)
```

`examples/game_hud.ae` is that and a pause menu: the frame rate, a minimap
the program redraws every frame, a health bar, a crosshair, a prompt, and
Escape for Resume, subtitles, a volume, a name and Quit.

## Glyphs

```aether
import ae3d.glyphs

face = glyphs.load("resources/fonts/PT_Sans-Web-Regular.ttf")
atlas = glyphs.bake(face, glyphs.DEFAULT_SIZE, glyphs.DEFAULT_SPREAD)
width, height = glyphs.measure(atlas, "E to get in", 28.0)
quads = glyphs.layout(atlas, "E to get in", 28.0)
// quads.count quads of 8 floats in quads.data: x0 y0 x1 y1 in pixels,
// y down from the text's top-left, then u0 v0 u1 v1 in the atlas
glyphs.quads_free(quads)
glyphs.atlas_free(atlas)
glyphs.typeface_free(face)
```

Text is drawn from a texture, and a texture of coverage -- the glyph as a
rasteriser fills it -- is sharp at the one size it was made at and
blurred or jagged at every other. A texture of distance is not: each texel
holds how far its centre is from the outline, signed, and the outline is
wherever the filtered value crosses the middle, at any scale (Green,
SIGGRAPH 2007). The same field gives an outline or a glow for a threshold
in the shader.

### The font

`resources/fonts/PT_Sans-Web-Regular.ttf` is PT Sans Regular (ParaType,
SIL Open Font License 1.1, the licence beside it in
`resources/fonts/PT_Sans-OFL.txt`): 443 KB, 720 glyphs, Latin and
Cyrillic, 1000 units to the em. It is a static TrueType font with its
kerning in a `kern` table, 24,030 pairs, which is what this reader reads.

### What is read

The table directory (a `.ttc` collection's first font), `head`, `maxp`,
`hhea`, `hmtx`, `cmap` formats 4 and 12, `loca`, `glyf` and `kern` format
0. A simple glyph is its quadratic contours, on-curve and control points,
with the on-curve points implied between two controls; a compound glyph is
its components, each through its 2x2 transform and placed by an offset or
by matching a point of its own to one already placed, nested up to eight
deep. GPOS is not read (an OpenType layout engine is not what a HUD needs),
nor CFF outlines (`.otf`).

Every read is bounds-checked against the file and its table. A font that
fails loads as null, and `glyphs.last_error()` says which table: "head
table missing or short", "table directory runs past the end of the file",
"not a TrueType font (unknown sfnt version)". A glyph that fails is left
blank and counted in the atlas's `broken`. A format-0 `kern` subtable
with more than 10,921 pairs overflows its u16 length (PT Sans's does), so
its size is taken from its pair count.

### The field

Each glyph's contours are flattened to segments: a quadratic is cut into
as many equal-parameter chords as its bend needs to stay within 0.02 atlas
pixels of the curve (a chord over a step h strays at most
|P0 - 2 P1 + P2| h² / 4). Each texel takes the distance to the nearest
segment, and its sign from the winding of the row's crossings left of it,
by the non-zero rule: that is the rule TrueType fills by, and a compound
glyph whose components overlap is solid where they overlap under it and
a hole under even-odd. Values are 8 bits: 0.5 is the outline, 0 and 1 are
the spread outside and in.

The default bake is 64 pixels to the em, the field 2.5 pixels either side
of the outline. Drawn at 12 px that is still half a screen pixel either
side, what antialiasing an edge needs. A regular weight's stem is about 80
units of 1000, 5.1 pixels at 64, and the texel nearest its middle is at
least 2 pixels in: it reads 0.9 or more. A game that wants thick outlines
or glows bakes with a wider spread, and the middle of a stroke then reads
less.

### The atlas

Printable ASCII, Latin-1 (U+00A0 to U+00FF: é ñ ü ¿ ¡ ° and the rest) and
the font's missing-glyph box, 192 glyphs, each in a rectangle of its own:
the outline's box in whole pixels, grown by the spread and a texel more so
the border reads 0 and a filtered sample off the edge blends with nothing.
Rectangles are packed in shelves, tallest first, into a power-of-two
texture: 1024 x 512 for PT Sans at the default bake, one byte a texel.

A glyph's metrics (`AtlasGlyph`) are in em units as the font gives them
(advance, left side bearing, box) and in atlas pixels as the quads use
them (the rectangle, its left edge right of the pen and its top above the
baseline, the advance). The font's kerning between the atlas's glyphs
comes with it, 2,645 pairs, so an atlas lays text out without the font.
A codepoint the atlas lacks draws as the missing glyph.

### Layout

`measure` and `layout` take UTF-8 (a malformed sequence is U+FFFD, one
byte) at a pixel size: each glyph's advance, the kerning between it and
the one before, and a newline returns to the left one line lower, a line
being the font's ascender to descender plus its line gap. The first
baseline is the ascender below the top. `measure` gives the widest line
and the lines' height; `layout` a quad for each glyph that has something
to draw.

`measure_box` and `layout_box` lay the same text out in a box of a width:
- **Wrapped.** A line breaks at the last space that lets it fit, and a
  word wider than the box on its own breaks where it overflows, so no line
  is wider than the box. The space it broke at is not carried to the next
  line.
- **Measured by its ink.** A line's extent is each glyph's outline box as
  the font gives it -- not the field's rectangle round it, which is wider
  by the spread -- or its last advance, whichever reaches further, its
  trailing spaces not counted. A line whose first glyph hangs left of the
  pen (a j's tail) is moved right by whole pixels, so no ink falls outside
  the box on either side.
- **Aligned** in the box, `ALIGN_LEFT`, `ALIGN_CENTER` or `ALIGN_RIGHT`,
  by a whole pixel, so a centred line's stems land on the pixel grid as a
  left-aligned line's do. A width not above zero wraps nothing and aligns
  the lines in the widest of them.

### The cache

Baking costs milliseconds a program would pay every start, so `bake`
keeps the atlas like the OBJ parse cache keeps a parse: a file under
`build/cache/fonts/` (or `AE3D_FONT_CACHE`; `off` turns it off), headed by
the font's absolute path, size and modification time and the bake's size
and spread. A bake whose font and parameters match reads it. The time is to
the second, so a font rewritten at the same size within the second of a
bake reads the older atlas. `bake_uncached` always bakes; `load_bytes`
takes a font already in memory, which is baked afresh.

### Measured

`tests/test_font.ae`, no window or GPU. The font's numbers are checked
against a separate reader of the same tables (a Python script over the
file's bytes). On the Windows machine of [performance.md](performance.md):

| What | Number |
|---|---|
| Font | 720 glyphs, 1000 units per em, ascender 1018, descender -276, 24,030 kern pairs |
| 'A' 'g' 'é' '0' | glyphs 36, 74, 171, 19; advances 585, 537, 508, 545 |
| 'A' / 'é' | 14 points in 2 contours / 40 in 3 ('e''s 35 and the accent's 5) |
| Bake, 64 px, spread 2.5 | 1024 x 512, 192 glyphs, 6.2 ms; read back from the cache 0.4 ms (4 ms the first time after it is written) |
| Stem of 'l', middle / 3 px outside it / counter of 'o' | 0.93 / 0 / 0 |
| The 0.5 contour against the outline, 41,658 crossings in every glyph | 0.40 px at most, 0.011 px on average |
| A texel's distance against the outline's, within the spread | 0.028 px at most |
| "Hello, world" at 32 px | 164.224 px wide: 5233 units of advance, 101 of kerning, exactly |
| "AV" at 100 px | 110.8 px, kerned 4.5 px closer |
| 200 copies of the font with 1-16 bytes overwritten | 139 loaded, 61 refused, 641 glyphs refused, no crash |

The worst of the 0.5 contour is at corners and joins (where the bar of
'H' meets its stems, the join of '4'): the field bends between two texels
there, and a line between their values cuts across the bend. Of the
23,662 horizontal crossings, 287 (1.2%) are more than 0.1 px off.

## The overlay

```aether
import ae3d.hud

// in a script's update, every frame
hud = engine.engine_hud(e)
hud.rect(hud, 20.0, 660.0, 280.0 * health, 22.0, hud.rgba(0.2, 0.8, 0.15, 0.95))
hud.text(hud, 20.0, 16.0, 26.0, "${fps} fps", hud.rgba(1.0, 1.0, 1.0, 1.0))
hud.text_outlined(hud, 312.0, 654.0, 26.0, "${points}", white, black, 1.5)
width, height = hud.measure(hud, "Press E to open", 22.0)   // to centre it
```

The overlay is immediate: each frame a program says what is on the
screen this frame -- the bar at its length now, the count as it is now --
and the overlay draws that over the finished picture and forgets it.
Nothing is created for a label or kept for a bar, so nothing has to be
updated or taken away. What stays is what a program makes once: the font,
and its images. The UI that stays -- layers, widgets, menus -- is
`ae3d.ui2d`, below, drawn into the same overlay.

| Call | Draws |
|---|---|
| `rect(o, x, y, w, h, colour)` | a filled rectangle |
| `rect_outline(o, x, y, w, h, thickness, colour)` | its border, inside its edge, as four rectangles that do not overlap |
| `text(o, x, y, size_px, text, colour)` | UTF-8 text, its first line's top-left at x, y, `size_px` to the em; its width back |
| `text_outlined(..., outline, outline_px)` | the same over its glyphs grown by `outline_px` in another colour |
| `text_shadowed(..., shadow, offset_px)` | the same over a copy of itself offset down and right |
| `text_box(o, x, y, width, size_px, text, colour, align)` | text wrapped to `width` and aligned in it (Glyphs, Layout); its height back |
| `text_box_outlined(..., align, outline, outline_px)` | the same with an outline |
| `image(o, x, y, w, h, image, tint)` | one of the overlay's images, stretched to the rectangle, times a tint |
| `image_region(o, x, y, w, h, image, sx, sy, sw, sh, tint)` | a part of one: an icon of a sheet |
| `push_clip(o, x, y, w, h)`, `pop_clip(o)` | nothing: what follows is cut to the rectangle, and to every clip already in effect |
| `measure(o, text, size_px)`, `measure_box(o, text, size_px, width)` | nothing: the widest line and the lines' height |
| `image_add(o, w, h, rgba)`, `image_load(o, path)` | nothing: an image into the overlay, its number back (-1 when it does not fit) |
| `image_update(o, image, rgba)` | nothing: an image's pixels replaced, the same size |
| `set_font(o, path)` | nothing: the font text is drawn in from now on, baked now |
| `frame_width(o)`, `frame_height(o)` | nothing: the size of the frame it was last drawn into, to anchor to its edges |

Coordinates are the window's framebuffer pixels, y down from its
top-left, the way a screen is addressed. Colours are display values -- the
sRGB a colour picker gives -- with alpha, `hud.rgba(r, g, b, a)`. What
is asked for later is drawn over what was asked for earlier.

### Clips

A clip cuts what is asked for after it to a rectangle as it is asked for:
a quad is an axis-aligned box and its place in an atlas runs straight
across it, so cutting its corners and interpolating its atlas coordinates
is exact arithmetic on four numbers, and the overlay stays one draw. A
scissor rectangle a clip would have split the draw at every panel for the
same pixels. A clip's edges are rounded to whole pixels, so a pixel is in
it or not, and clips nest, each inside the one before.

### Images

An image is the overlay's own: pixels handed to it (`image_add`, top row
first) or read from a PNG, JPEG, TGA or BMP (`image_load`), packed with a
pixel of its own edge round it into one RGBA atlas beside the glyphs', so
a HUD of icons, portraits and a minimap is still one draw. The atlas
starts at 512 x 512 and doubles each way when an image does not fit, up to
4096. The pixels are kept premultiplied by their alpha, which is what lets
a cut-out icon's edge filter into its transparent surround without a dark
ring; the overlay blends premultiplied (ONE, ONE_MINUS_SRC_ALPHA), which
for a colour or a glyph is the same arithmetic as before. An image a
program rewrites every frame -- a minimap it draws -- is written in place
(`image_update`), and the renderer sends the rows that changed, not the
atlas: the 16 x 16 image of the tests sends 18 rows of 512. There is no
taking an image out: a game loads its icons once, and changes a picture
in place.

### A frame

The engine makes one overlay, hands it to its backend
(`Backend.set_overlay`), and clears it after each frame is drawn, so what
`update`, `pose` and a script's `late_update` ask for is that frame's.
An engine behaviour's `late_update` runs after the draw, and what it asks
for is the next frame's. `engine_over` -- the editor's engine over its own
renderer -- has one too, cleared at the start of each `engine_update`
(In the editor, below).

What is asked for becomes vertices at once: two triangles a quad, each
vertex its pixel, its place in an atlas, its colour and what it samples
(the distance field's threshold -- 0.5 for a glyph as it is, lower for
one grown outward -- or -1 for a solid rectangle, -2 for the image
atlas), nine floats. The renderer draws them all in one call over the
output after its post chain: blended premultiplied, no depth, no culling,
the frame's own alpha kept at one. One shader does it all,
`VERTEX_OVERLAY` and `FRAGMENT_OVERLAY` in `ae3d.shaders`: the field
sampled, and blended across one screen pixel of it at the outline
(`fwidth`), whatever size the glyph is drawn at.

A source (`set_source`) is what draws the frame's retained part, the UI
of `ae3d.ui2d`: the renderer calls it once a frame when it is about to draw
the overlay, at the size it draws it at (`prepare`). So a menu is over
everything a script drew that frame, and it is laid out for the frame as
it is drawn -- what is clicked next frame is where it was seen.

- **OpenGL.** `ae3d.gl` draws it after the post pass, into the window or
  the offscreen target: the glyph atlas as an `R8` texture, the image
  atlas as `RGBA8` (the rows it rewrote sent by `glTexSubImage2D`), the
  vertices into one buffer each frame. Its own timer query says what the
  draw cost the device (`gl.renderer_overlay_ms`).
- **Vulkan.** `ae3d.vkoverlay` records it from Aether on contrib.vulkan.vk
  through `vulkan.c`'s frame hooks, at their draw stage: after the meter
  reads the scene's light (a menu does not set the scene's exposure) and
  before the readback copies the frame (a capture is of what is shown).
  Its render pass loads the frame's image and leaves it in the layout it
  found it in; the atlas goes up through a staging buffer copied in the
  frame's own command buffer; the image atlas the same way when it is new
  or grows, and its rewritten rows through a staging buffer of the frame
  slot's own, between barriers that wait for the frames before it to
  finish sampling them; the vertices are in a buffer for each frame in
  flight. Two timestamps a frame round its work say what it cost the
  device (`vkoverlay.gpu_ms`). `tools/generate_shaders.ae` compiles the
  same shader source for it at `#version 450`, where `VULKAN` is defined
  and picks push constants for the two numbers OpenGL takes as uniforms.

### Its font

The default font is PT Sans, baked the first time text is asked for, at
64 px to the em with a spread of 6 px (`hud.FONT_SPREAD`): the spread
is what an outline can grow into, 1.9 px at 24 px text and 3.8 at 48,
where the glyphs' own default of 2.5 stops under a pixel at 24. That atlas
is 1024 x 1024, 1 MB, baked in 13-15 ms and read back from the bake cache
in 1.6 ms. A program run from where `resources/fonts` is not says so once
and draws its rectangles without its text.

### Measured on screen

`tests/test_overlay.ae` draws a white rectangle, a half-transparent red
one, HELLO at 48 px and HUD at 24 px plain and outlined over a dark frame,
through each renderer's backend offscreen and through the engine on
OpenGL, reads the frame back, and asks about it in numbers. On the
Windows machine of [performance.md](performance.md):

| What | Number |
|---|---|
| The white rectangle | 255 in every channel of every pixel, ending at its edges to the pixel (y down) |
| Half-transparent red over the frame | red 137, the frame's 20 and 255 half and half, exactly |
| HELLO at 48 px | measured 137 x 62 px; 1509 pixels inked inside that box (17.8%), none beside or below it |
| HUD at 24 px | 295 pixels inked; 776 with an outline asked 2 px wide (1.9, what the spread gives) |
| The next frame, nothing asked for | none of it, every renderer |
| Vulkan against OpenGL | not a channel different, the frame over |
| 60 labels and 20 bars a frame (800 quads) | 0.02 ms of CPU to lay out |
| Draws | one, whatever is asked for |

Under the Khronos validation layer with synchronisation validation,
`examples/game_hud.ae` on Vulkan -- its pause menu up, its minimap
rewritten every frame -- reports no error (`AE3D_VALIDATE_SYNC=1
scripts/validate.sh game_hud`, and with `AE3D_HUD_PAUSED=1`).

### What it is held to

`tests/test_overlay_measure.ae` measures what #449 asks of the overlay, on
both renderers offscreen at 1280 x 720, on the machine of
[performance.md](performance.md):

- **Text at 96, 24 and 12 px, compared by pixels with the glyphs' own
  shapes.** The perfect rendering of a shape is each pixel's area inside
  it, from sixteen lines across the pixel, each filled between the shape's
  edges exactly. The shape is the atlas's own (where its field, filtered as
  a sampler filters it, is above one half) and the font's outline (by the
  non-zero rule). A pixel holds as much more ink as an edge through it
  stands further out, so the ink the drawn text and the perfect one differ
  by, over the whole text, divided by the length of its edges, is how far
  the drawn edge stands from the shape's on average, in pixels, and its
  sign says bolder or thinner. How soft the edge is drawn is the ink in
  part-inked pixels, `a(1 - a)` summed, against the perfect rendering's: 1
  is as sharp as pixels allow.
- **What it costs a frame**, for 1,000 rectangles in a grid over the
  frame and for 5,000 glyphs in a hundred labels of fifty at 12 px: the
  CPU's time to lay them out (a clear and the calls, over 200 frames) and
  the device's to draw them, from its own timers (OpenGL's timer query,
  Vulkan's timestamps), over 40 frames after 6 to warm up.
- **The renderers against each other**, at the backend-parity test's
  tolerance: fewer than 2% of the channels more than 8 of 255 apart, and
  the lit areas within 5%.

| Text | Edge from the atlas's shape | From the outline | Bolder by | Part-inked, of perfect |
|---|---|---|---|---|
| 96 px | 0.044 px | 0.054 px | -0.006 px | 0.91 |
| 24 px | 0.062 px | 0.060 px | 0.014 px | 0.82 |
| 12 px | 0.106 px | 0.106 px | 0.008 px | 0.62 |
| The same atlas as a coverage bitmap, scaled to 96 px | 0.347 px | | | 2.40 |

The field is sharp at any size: at 96 px its edge is no softer than a
perfect one (0.91), where a picture of the same glyphs baked at the same
64 px and scaled up, what a bitmap font draws, is part-inked 2.4 times as
much and stands 0.35 px off. At 12 px a stroke is a pixel wide, and a
field sampled at each pixel's centre departs most from the pixel's area
there: 0.11 px on average, and no bolder or thinner (0.008). The suite
holds each size to a third again over these (0.06, 0.08, 0.14 px), no
bias past 0.03 px, and part-inked under 1.

| A frame of | CPU to lay out | Device, OpenGL | Device, Vulkan |
|---|---|---|---|
| 1,000 rectangles | 0.012 ms | 0.090 ms | 0.022 ms |
| 5,000 glyphs | 0.16 ms | 0.093 ms | 0.076 ms |

Held under 0.5 and 3 ms of CPU (the time here, ten times over, for a
slower runner) and under a millisecond of the device's. A software
rasteriser's timer measures a CPU rasterising, and its number is printed
and not held to a device's. Vulkan and OpenGL draw all three frames with
not a channel different.

## The game's UI

```aether
import ae3d.ui2d

ui = engine.engine_ui(e)                      // in a script's start
hud = ui2d.layer(ui)
bar = ui2d.rect(hud, ui2d.BOTTOM_LEFT, 22.0, -32.0, 280.0, 22.0, green)
ui2d.set_back(bar, hud.rgba(0.05, 0.05, 0.07, 0.9))

pause = ui2d.menu(ui)
card = ui2d.panel(pause, ui2d.CENTER, 0.0, 0.0, 340.0, 330.0, dark)
resume = ui2d.button(card, ui2d.TOP, 0.0, 66.0, 280.0, 40.0, "Resume")
volume = ui2d.slider(card, ui2d.TOP_LEFT, 110.0, 160.0, 200.0, 22.0, 0.0, 1.0, 0.8)
name = ui2d.field(card, ui2d.TOP_LEFT, 30.0, 200.0, 280.0, 36.0, "Your name")

ui2d.set_fill(bar, health)                    // in its update
if input.pressed(in, "pause") { ui2d.push(ui, pause) }
if ui2d.clicked(resume) { ui2d.pop(ui) }
```

`ae3d.ui2d` keeps what it is given: a bar is made once and its fill set as
the health changes, a menu built once and pushed when it is wanted. What
is kept is what can be pointed at, focused and typed into, which a thing
that exists for one frame cannot be. The engine makes one screen
(`engine.engine_ui`) and draws it into its overlay, as the overlay's
source.

### Placing

A node is placed in its parent -- a layer is the whole frame, a panel its
own rectangle -- by an anchor and an offset from it: `TOP_LEFT`, `TOP`,
`TOP_RIGHT`, `LEFT`, `CENTER`, `RIGHT`, `BOTTOM_LEFT`, `BOTTOM`,
`BOTTOM_RIGHT`. The node's own point that sits on the anchor is the same
one, so `TOP_RIGHT` with (-20, 20) puts its top-right corner twenty in from
the right and twenty down, whatever the window's size, and `BOTTOM_LEFT`
with (24, -24) its bottom-left corner twenty-four in and up. Offsets run
the way the overlay's pixels do, x right and y down. A node can stretch
across its parent instead, inset by four margins (`stretch`).

Offsets and sizes are the UI's units: pixels times the scale, which is the
monitor's content scale (`platform.window_content_scale`: 1 at 100%, 1.5 at
150%, 2 on a Retina display) unless the game sets one (`set_scale`). A
button is as big to the eye on each. Every edge is rounded to a whole pixel
once scaled, so a rectangle is crisp at any scale and exactly where it was
asked for at 1. Text is its size times the scale, wrapped to its width
when it is given one (`set_wrap`) and aligned in it (`set_align`), else as
wide as it is.

### Drawing

The layers are drawn in the order they were made, then the menus open,
from the bottom of the stack up, each over a dimming of what is under it
(`set_dim`, half black unless changed); all of it after what scripts drew
through `ae3d.hud` that frame, and laid out at the size the frame is drawn
at. A panel clips what is in it and can scroll it (`set_scroll`,
`set_scrollable` for the wheel). Where each node was drawn -- its
rectangle and the clip it was drawn under -- is kept, and a click is
tested against that: what is clicked is what was seen.

| Makes | Is |
|---|---|
| `layer(ui)` | a layer over the frame, drawn while visible |
| `menu(ui)` | a layer drawn while it is open, over a dimming, taking the input on top |
| `panel(parent, anchor, x, y, w, h, colour)` | a rectangle that holds nodes, clips them, can scroll; solid where its colour shows |
| `rect(parent, anchor, x, y, w, h, colour)` | a rectangle; with `set_fill` and `set_back`, a bar filled from a side (`set_fill_from`) over its well |
| `text(parent, anchor, x, y, words, size)` | text, as wide as it is or wrapped (`set_wrap`, `set_align`, `set_outline`) |
| `image(parent, anchor, x, y, w, h, image)` | one of the overlay's images (`load_image`, `add_image`, `update_image`), tinted by its colour |
| `button(parent, anchor, x, y, w, h, label)` | `clicked` the frame it is pressed and let go over, or activated |
| `toggle(parent, anchor, x, y, w, h, label, on)` | a box and its label; `is_on`, `changed` |
| `slider(parent, anchor, x, y, w, h, low, high, value)` | `value`, `changed`; stepped by a twentieth of its range (`set_step`) |
| `field(parent, anchor, x, y, w, h, hint)` | a line of text; `field_text`, `caret`, `changed`, `submitted` |

`destroy` takes a node and everything in it away; `set_position`,
`set_size`, `set_visible`, `set_enabled`, `set_colour`, `set_text` and the
rest change one. The widgets are drawn in the screen's theme (`theme`):
face, hover, pressed, the well, the accent, the focus ring.

### Input

Once a frame the engine blocks the game's input while the UI holds it,
polls `ae3d.input`, and hands the UI its part (`screen_input`), before any
script runs:

- **Clicks.** A press lands on the topmost widget under the pointer, inside
  the clip it was drawn under, and on nothing behind it: while a menu is
  open only the top menu is tried, else the layers from the last made. A
  press on a widget, or on a solid node, is swallowed from the game's
  input until the button is let go. A button is clicked by a press and a
  release on it, a toggle flips, a slider follows the pointer while held,
  a field takes its caret where it was pressed.
- **Focus.** One focused widget a layer, drawn with a ring. Keys,
  characters and the pad go to the top menu, or with none open to a field
  that has the focus (a chat box). Tab and Shift+Tab step through a
  layer's widgets in the order they were made, round; the arrows, the
  d-pad and the left stick move to the nearest widget that way, round
  (a pad direction held steps again after 0.4 s and every 0.08 s after);
  Enter, Space and the pad's A activate; Escape and the pad's B close the
  top menu (unless `set_closable` said not). Left and right step a slider
  and move a field's caret. A menu opens with its first widget focused.
- **Typing.** A field takes the characters typed -- `ae3d.input`'s
  character events, so the keyboard's layout and shift are its --
  Backspace and Delete, Home and End, as UTF-8; Enter submits it.
- **The game.** While a menu is open, or a field on a layer has the focus,
  the game's actions read nothing: not down, not pressed, not released,
  zero, and the mouse's movement and wheel zero. Whatever was held stays
  swallowed until it is let go, so the click that pressed Resume fires no
  shot on the frame the menu closes, and a key held through a menu is the
  game's again only once it is pressed anew.

`ae3d.input` gathers what the UI reads as events, in order: the keys
pressed and repeated, the characters typed (GLFW's character callback),
the mouse buttons pressed and released. A tap or a click inside one frame
is only ever an event; a press seen as one counts as down for the poll
that takes it, so a game's action sees it once too. All of it can be
injected (`inject_cursor`, `inject_char`, `inject_key_press`,
`inject_scroll`), and the agent channel's `input.set` takes a cursor, text
and the wheel ([agent.md](agent.md)).

### In the editor

The editor's engine, over its viewport's renderer (`engine_over`), has
the same overlay and screen, cleared at the start of each `engine_update`
and drawn after the scene, so a HUD shows in the viewport as in the game.
A script on an object reaches them through the object's scene --
`behaviour.object_overlay(go)` and `behaviour.object_ui(go)` -- as it has
to: a script is a library of its own, importing the overlay rather than
the engine and everything the engine draws with. `resources/scripts/
health_bar.ae` is one: attached to any object, a bar anchored to the
bottom-left corner.

In play mode (Simulate) the viewport is the game's screen: the pointer,
the buttons, the keys and the wheel go into the editor's engine's input,
scaled from the canvas's units to the viewport's pixels, so the game's
menus take their clicks and typing there exactly as in the game. A press
the UI takes -- a menu is open, or it lands on a widget -- is the UI's
alone, with no orbit and no pick; the keys are the game's while it plays.
Stopping closes the game's menus and lets go of what the viewport
pressed. The toolkit's canvas names keys rather than typing characters,
and on Windows its names drop shift and punctuation and it never sees
Tab (aether-lang-dev/aether-ui#214): until it gives a canvas the text
typed, a field in the editor's viewport takes letters, digits and spaces
there, where the game itself takes anything. On macOS the canvas is not
told a key was let go (aether-lang-dev/aether-ui#215), so there a key is a
tap, down for the one frame that takes it: all a menu needs, where a game
action held down flickers with the keyboard's repeat.

### Measured

`tests/test_ui.ae`: an `ae3d.ui2d` screen drawn at two window sizes and two
scales and asked where everything went; driven a frame at a time the way
the engine drives it, with injected cursor, clicks, keys and characters;
drawn through both renderers offscreen and read back; and a game on the
engine that opens a pause menu and has Resume clicked. On the machine of
[performance.md](performance.md), 65 checks in 0.6 s:

| What | Number |
|---|---|
| Nine anchored rectangles at 320 x 180 and 1280 x 720, scales 1, 1.5 and 2 | 36 of 36 to the pixel; on screen 72 of 72 edge probes, in at every corner and out a pixel past every edge |
| A bar 200 wide, 30% full | 60 pixels of fill, its well the other 140 |
| Text wrapped to 120 and 140 px, left and right aligned | its widest line 113.2 of 120; 2184 and 2174 pixels inked in the boxes, none outside; lines reaching x 10 and 309 of boxes from 10 and to 310 |
| A panel's contents past its edges | 4184 pixels inside it, none outside; scrolled 40 units, they move 40 pixels |
| An image at its size, and rewritten in place | 256 of 256 texels exact, both times; the rewrite sends 18 rows of the atlas's 512 |
| A cut-out icon scaled 4x over white | darkest luma 76, red's own: no dark fringe |
| Clicks at the centres of widgets, a pixel outside them, where one covers another, and on a HUD under a menu, at 320 x 180 and 1280 x 720, scales 1, 1.25 and 2 | 40 of 40 land on the widget under them and on none behind |
| Tab and Shift+Tab over six widgets, two columns, one in a panel; the arrows | 12 of 12 and 6 of 6, wrapping round |
| The d-pad held 0.6 s; the stick pushed for a frame; A, B and Enter | 4 steps (0, 0.4, 0.48, 0.56 s); 1 step; A and Enter click the focused button, B closes the menu |
| A settings menu over a pause menu | a click where only the pause menu has a button lands on nothing; Escape closes settings alone, and the pause menu has its focus back where it was |
| A field typed into and edited ("Héllo wörld", two back, three left, X, Home, <, End, Delete, !) | "<Héllo Xwör!", its caret at byte 14 |
| The game's actions while a menu is open, under clicks, keys, characters, movement and the wheel | heard something in 0 of 22 frames; the click on Resume fires nothing after; a key held through the menu is the game's again only once pressed anew |
| The engine: a script's pause menu, a field clicked and typed into, Resume clicked | the menu open 7 frames, the game hearing nothing; "Ada" in the field; the HUD's bar at green 229, 115 under the menu's dimming; the UI at the window's content scale |
| Vulkan against OpenGL, the four frames | not a channel different |

The agent channel is held too: `tests/test_agent.ae` clicks a menu's
field, types "Zoë 7" into it and clicks Resume, over the socket. The
editor checks itself (`overlay_stuck` in its report, held to zero by
`ci.sh` on both renderers): the health bar script drawing over the
rendered viewport, a layer of the game's UI there to the channel, and in
play mode a click through the viewport's own handlers on a menu's button
clicking it with the game hearing nothing, and Stop closing the menu.
