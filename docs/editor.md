# The editor

```bash
git clone https://github.com/aether-lang-dev/aether-ui.git ../aether-ui
./editor/build_editor.sh
./build/ae3d_editor                         # the scene it last saved
./build/ae3d_editor build/street.json       # a scene file
AE3D_SCENE_OUT=build/street.json ./build/street_drive   # any program writes one
```

![the editor on Windows](images/editor-windows.png)

The chrome is one dark theme on every platform: neutral greys, three tones
apart -- the viewport's ground, the panels a step lighter, the bars and
fields a step darker -- with one accent for the primary action and the
selected row, the way Unity's, Blender's and Unreal's dark themes are
built. It is a style sheet in `editor.ae` (`theme()`), so there is one
place the colours live. On Windows the toolkit paints every widget on the
ground behind it and scrolls the panels; the inspector's sections past the
window's bottom are reached with the wheel or the bar.

## Controls

The viewport has to have focus for a key to reach it, so click in it first.

| | |
|---|---|
| drag | orbit the camera |
| scroll | zoom |
| click | select the object under the cursor |
| drag a gizmo axis | move, rotate or scale the selection along it |
| `W` | translate gizmo |
| `E` | rotate gizmo |
| `R` | scale gizmo |
| `F` | frame the selection, and everything under it |
| `D` | duplicate the selection |
| `Z` | undo |
| `Shift` `Z` | redo |
| `Delete` or `Backspace` | delete the selection |

Picking casts the cursor ray against a model's exact triangles, rejecting each
against its bounding sphere first, so selection stays cheap with a full scene.

## Panels

**Scene** is the hierarchy: the scene itself first, as a row named Scene,
then a tree of the scene's objects, roots in scene order, an object's children under it behind a disclosure, closed until
opened -- the street of `examples/street_drive.ae` opens as its five
blocks, its car, its crate walls and its bystanders, ten rows for 1,212
models, and expands where you look. A parent is any object another's
model is parented to; a **group** is an object with a transform and
nothing to draw (`engine.object(e, "Block 3", null)`), the way a program
folders what it builds, and the scene file carries the parents. The
filter box above the tree narrows it to the objects whose names have the
text, flat, as every editor's outliner searches. A click selects one
object; holding shift or command adds to the selection; selecting an
object under a closed parent opens the way to it. Delete takes an object
out with everything under it, Duplicate copies the subtree with its
parents kept. **Group selection** (Cmd+G) puts what is selected under a
new group at its centre, each object staying where it is in the world;
**Ungroup** (Shift+Cmd+G) takes a group's contents out from under it and
the group away; Add has a **Group** of its own, empty, for what is put
under it later. Either is one edit to undo, however many parents it
changed. The inspector shows the last object clicked and an edit
reaches everything selected, so typing a height with three objects
selected puts all three at that height, each keeping its own place.

**Inspector** is the selected object's components, a panel each, drawn
from their kinds ([components](components.md)):
- **Transform first**, as in Unity, then the rest in the object's order.
- **Each panel** has an enable switch, its name, and a menu (⋮) of Reset,
  Move Up, Move Down and Remove. The Transform is reset, never removed.
- **Every field is a row by its type:** a switch, a slider with a box, a
  box, three boxes with coloured axis letters (a rotation in degrees), a
  colour chip with its hex, a row of choices, or a text box. An asset's
  box has a "..." listing what the editor knows of that kind (the engine's
  skies, the textures) and Browse for anything else.
- **Add Component** lists every kind the object may be given, the engine's
  and the game's, one per object where the kind says so.
- **Rows follow the value, whoever changed it:** a script, the gizmo, the
  physics, the agent, an undo. Each frame a row compares what it shows with
  what the component holds, and a box being typed into is never rewritten
  under the caret.
- **Selecting an object of the same shape** keeps the panels and shows the
  new object in them.
- **Undo:** every edit, add and removal is one step, however many objects
  it reached.

Selecting **Scene** shows the scene's own components: Environment (the sky
image or colour, the sun by the hour, clouds, overcast, fog) and Rendering
(the post passes, shadows, reflections, occlusion, TAA). They are the
settings of the engine the viewport is drawn with, so a scene opened, a
preset or an undo shows in the rows as it lands. The key light is the
scene's Light. The scene's other sections (the weather, the render
presets, the shading switches and the viewport's own camera) show with it
too. The grid and the selection
outlines are the editor's own geometry: the renderer draws them, but
they are not objects and do not appear here.

**Add** creates a cube, sphere, plane, water surface, light, spot light,
group or terrain.

One terrain, not five. Which shape a terrain takes is a property of the terrain,
chosen in its own inspector section and changed there afterwards, the way a
landscape works in Unreal and in Unity. The panel's job is to say that a terrain
is a thing a scene can have; knowing what a desert looks like is
`src/ae3d/terrain`, a module rather than editor code, so what each shape
produces is measured without a window in `tests/test_terrain.ae`: hills have
more relief than plains, a desert is smoother than both, and caves are the only
one with rock over open space.

A terrain is drawn as **blocks** or as a **smooth** surface. Blocks are a cube
per filled cell; smooth meshes the same field into one surface. Voxels are one
way of meshing a terrain rather than what a terrain is, and both come from the
same world, the same seed and the same five shapes.

**Sculpting.** Under the style is the brush: Off, Raise, Lower and Smooth
out, and its reach in metres. With the brush on, a press on the selected
terrain moves the ground under the cursor and a drag keeps moving it, once
per cell the cursor crosses -- the brush is a rate of change of the ground,
so a slow drag is not a deeper one. Raise and Lower move each column within
reach by up to two cells at the centre, falling off to nothing at the edge;
Smooth out pulls each toward the mean of its neighbours. A raised column
grows in the kind its top was, so grass stays grass and sand stays sand, and
a lowered one uncovers what was under it. The terrain is rebuilt after every
touch, blocks or smooth. A stroke, press to release, is one undo step, whose
before and after are the terrain's column heights. Changing the shape, the
seed or the style fills the world again from its seed, which is to say it
discards the sculpting; undo brings it back.

Changing the shape, the seed or the style fills the same world again and gives
the model that is already there its new geometry, so the object keeps its place
in the scene and its place in the undo history. The renderers decide a model's
buffers when it is added, so the model leaves the backend and comes back around
the change; `core.model_set_mesh` and `core.model_disable_instancing` say so
where they are defined.

**Assets** lists the meshes under `resources/obj`, then the animated figures
under `resources/figures` (glTF, `.glb`). Clicking one loads it into the scene
and frames it. A figure comes in as a group at the origin with the figure
under it (`ae3d.figure`), playing its first clip.

**Behaviour** attaches a script to the selected object. A script is a
component ([components](components.md#scripts)): an Aether source file in
`resources/scripts` whose state is a struct of its own, one for every object
it is on, whose fields are what the inspector shows and the scene saves, and
whose phases are Unity's, by Unity's names:

```aether
import ae3d.core
import ae3d.behaviour
import ae3d.component

exports (Spin, create, destroy, fields, update)

struct Spin {
    speed: float                   // degrees a second
}

create() -> ptr {
    s = heap.new(Spin)
    s.speed = 60.0
    return s as ptr
}

destroy(p: ptr) { heap.free(p as *Spin) }

fields(k: *ComponentKind) {
    component.float_field(k, "speed", offsetof(Spin, speed), 0.0 - 720.0, 720.0)
}

update(p: ptr, go: *GameObject, delta: float) {
    s = p as *Spin
    core.model_rotate(behaviour.object_model(go), 0.0, delta * s.speed, 0.0)
}
```

`scripts/build_script.sh resources/scripts/spin.ae` compiles it into a shared
library, and the editor opens what it finds and registers each as a
component kind listed under Scripts. A button in the section puts that
script on the selected object in place of any other (None takes them off);
Add Component gives an object more than one. The script's panel in the
inspector is its fields, edited, reset and undone like any component's, and
two objects running the same script are two states: two bobs at two
heights, two orbits at two radii.

**New script** writes a template into `resources/scripts` and says where it
went. Building it is the same step that builds every other script, and the
editor picks the library up when it appears.

A script rebuilt while the editor is open is reopened without restarting it.
Every object carrying it -- and every one deleted and kept for undo -- keeps
its fields: they are read out, its state is freed by the old library and
made again by the new, the fields are written back by name (one the new code
renamed takes its default), and its start runs again. The editor compiles
nothing: it watches the library rather than the source, so a source saved
with an error in it leaves the last good behaviour running until the build
succeeds.

The scene saves a script as a component, with its fields, so a project that
still has the file gets the script back as it was set. A scene naming a
script this project does not have keeps it, and writes it back when saved.

A script links the same engine library the editor links,
`build/libae3d_native`, so a call into the engine reaches the one copy the
editor is running rather than a second copy with an empty GL loader in it. The
three platforms each offered a different way to arrange that, and two of them
would have let a script carry its own engine; this is the arrangement that is
the same everywhere.

CRITICAL: build a script with the tree that will run it. A script carries its
own copy of the Aether it imported, so it and the editor agree about what a
`Model` is only while both were built from the same sources.

**Edit** is undo, redo, duplicate, frame, delete, and saving or loading the
scene. The file is the one the editor was opened on -- its argument, or
`AE3D_SCENE` -- and `build/editor_scene.json` otherwise; meshes that came
from no file are written beside it, in a directory named after it. Loading
replaces the scene rather than merging into it, and clears the history,
since the steps in it refer to models that are gone.

**Simulate** (also File, Cmd+P) runs the scene's bodies: `ae3d.physics` is
attached to the editor's engine, every object with a body gets one from
its record (see the physics section below), and the frame steps the world
the way a program's loop does, so crates fall, cars roll off kerbs and
towers topple in the viewport. Pressed again it stops, the world goes, and
every model is put back exactly where it stood: the simulation is for
looking at, and what it did to the scene is not kept. Loading a scene
while one runs stops it first.

**Play** (#476) tries a multiplayer game the way it is played: by several
players at once. The PLAY section under Edit picks how many clients join
(one to four, a slider with a notch a count) and the link between them --
latency, jitter and loss, over `ae3d.net`'s loopback
([networking.md](networking.md)); a link slider moved while it plays
changes the link at once, and the count holds until Stop. Play runs the scene as a host
and each client as an engine of its own, in this process:

- the host is the editor's engine over its scene, simulated as Simulate
  simulates it, and plays too;
- a client is an engine over the same renderer, with a physics world of
  its own holding the scene's static bodies (the rows' own meshes, which
  never move) and the simulation's floors, a stand-in for every row the
  host moves -- a body that is not static, or a script -- networked in the
  same order, and its players;
- every world's players are capsules, one colour a client, standing at the
  nearest free places to where the viewport looks: on static ground (a
  figure or a crate is not ground), with room for a player, no two side by
  side. Where nothing is under that point, they stand on the grid's plane
  on a floor laid for the play.

The bar over the viewport shows one world at a time -- Host, Client 1 ...
-- its players, and every networked row where that client draws it (at
its view time, interpolated; hidden until it has been told it). The
camera follows the shown world's player, and the keys go to it: W, A, S
and D walk along the way the camera looks, space jumps, predicted on a
client and reconciled against the host. Stop lets every world and session
go, the players and the floors with them, and puts the scene back as
Simulate's stop does -- which now also takes a ragdoll's twelve bone
objects out of the engine and the renderer, where every stop used to
leave them.

**Console** keeps the last few messages. The status line under the viewport
carries the newest, and the stats bar beside it says what the last frame
cost: the rate, then the device's own time for each pass -- the shadow map,
the scene, the effects -- in milliseconds, then draws, triangles and the
size. A rate says a scene is slow; the split says which pass made it so.

**Inspector** changes with what is selected. Under the title, the name:
typing into it renames the object, its row follows, and the letters
typed are one edit to undo. Transform (with **Visible** and **Casts
shadow** switches on the object, each an undo step reaching everything
selected), material and
physics are always there (colour, metallic, roughness, and reflectivity --
how much of the wet road's mirror a surface gets on Vulkan, under
Reflections); water, light, camera, behaviour and rendering sections
appear when they apply.

The material's colour is a chip, a hex field and a picker under them: a
saturation-value square over a hue strip, as wide as the panel. Dragging
in either sets the colour of everything selected as it moves; letting go
is one undo step, so an undo puts back the colour the drag began from. A
colour typed or pasted into the hex field (`#3366CC` or `3366cc`) is
another. The red, green and blue sliders under the picker follow it, and
the picker follows them, an undo and the hex; it keeps its hue through
grey and black, where the colour alone has none.

The physics section is the body an object is, as the scene file records
one and `ae3d.physics` reads it back: five buttons for the kind, on two
rows -- No body, Static, Kinematic; Dynamic, Character -- and five for the
collider, which is made
from the object's own mesh: Box (its bounds), Sphere and Capsule (of them),
Hull (the convex hull of its vertices, what a prop wants) and Mesh (its
triangles, for the static world -- a building, a kerb). Under them, three
rows: the surface's friction and bounce, and the density the collider
weighs. A Character is a capsule that walks the world
(`physics.character_controller`): as wide as the mesh's widest half and as
tall as the mesh, its feet the mesh's lowest point, so a figure modelled
standing on its origin or centred on it stands on the ground; its collider
is always that capsule. Simulated, it stands under gravity until a script
walks it. A kind is one undo step, as the weather's is; the rows undo like
any row. The record is a component of the object (`mesh · dynamic body`
under its name), so it is duplicated, deleted and undone with it, and the
scene file carries it as the model's `physics` record -- the same record a
program's scene writes (`AE3D_SCENE_OUT`), so a scene built by a program
opens here with its bodies and one built here loads into a program with
them.

The figure section is an animated figure's (#439), shown when the
selection is one:
- a button for each of its file's clips, the first eight, named for them,
  with the playing one lit;
- Loop, lit while the clip starts again at its end;
- the speed it plays at;
- how far into the clip it stands, as a share of the clip, which scrubs it.

A figure stands in its pose while the scene is edited, and plays while it
is simulated. A clip and Loop are one undo step each, as a body's kind is;
the rows undo like any row. Its meshes come and go with its group (delete,
undo, redo), and are not rows: the scene file carries the group with its
`figure` record, the file and the clip at its speed and time, and a scene
read back makes the figure again from its file.

A section is the rows that belong to it rather than a run of them: the
water rows are not contiguous, because the foam, wave scale and shore rows
were added after the row indices below them were spoken for, so which section
a row is in is a question asked of the row and not of its number. The water
section is the whole simulation: amplitude, speed, opacity, foam, the wave
scale (how many times longer than the table's kilometre swells the waves
are), and the shore -- the metres of water the bottom shows through and the
metres the foam line runs out over. Rendering has the fog switch with
its two rows, where the fog starts and where it is whole in metres (its
colour is the sky's), the clouds switch and,
under it, the cover: how much of the sky they take, a slider like any row,
undone like one, and saved with the scene, and the overcast, 0 to 1, that
pulls the sky toward a flat grey; the sky section has, under its
three colour channels, a **Sun by time** switch and the hour: on, the key
light takes the sun's direction, colour, strength and fill for that hour
and the sky is drawn from the same sun, so a scene can be dragged from noon
to dusk to night and back, and the scene file carries the hour; and the
ambient occlusion switch
with its two rows, how dark the occlusion goes and how far in metres a thing
shadows what stands beside it. Occlusion is the view's, not a model's: it is
drawn from the scene's depth over everything opaque, by either backend.

The weather section is the engine's weather module over the viewport:
five buttons for the kind -- Clear, Rain, Snow, Dust, Storm -- lit like the
gizmo's modes, and three rows: the strength, 0 to 1, the wind's heading in
degrees (from +X toward +Z) and its speed in metres a second. A kind
brings what it brings in a game -- its particles falling around the
camera, its fog, its cloud cover and overcast, a dimmed sun, a storm's
lightning -- and Clear gives the scene's own sky back, the clouds and the
overcast the rows above hold. While there is weather the sky is the
weather's, so the clouds and overcast rows wait until it clears; the light
rows still act, and the weather dims from whatever they set. The kind is
one undo step, the rows undo like any row, and the scene file carries all
of it (`weather`: the kind by name, the strength, the wind). Underneath,
the editor holds an `engine.engine_over` -- an Engine wrapped around the
viewport's renderer, camera and light, with no window or loop of its own,
stepped by the frame with `engine_update` -- so what is written for the
engine runs in the editor unchanged.

The light section is the light itself: three buttons for its kind -- Sun
(directional, over the whole scene), Point (a lamp in a room) and Spot (a
headlight down a street) -- then its intensity and colour, its
reach in metres, and, for a spot, the cone: the angle its light is whole
within and the angle it is gone at. The rows act on the selected light,
or on the scene's key light when none is selected, and the cone rows are
there only when there is a cone. The kind is one undo step; the scene
file has carried the mode, the attenuation and the cone all along.

## Undo

An adjustment is one step, not one step per event: dragging a slider from 0 to 34
records a single step spanning the whole move, so undo steps back the adjustment
rather than a pixel of it. Adding and deleting are undoable too, which means a
deleted object stays alive as long as the step that removed it.

The history is `src/ae3d/history`, a module rather than editor code, so it is
tested without a window: `tests/test_history.ae`.

## Behaviours

Spin, bob, orbit and pulse are scripts in `resources/scripts`, attached to any
object and run in the frame loop. Each keeps its state per object: bob's
clock, orbit's angle and the radius it started at, pulse's size to breathe
about. Bob moves by the derivative of its own curve rather than to an
absolute height, so it needs no memory of where the object started and still
works after the object is dragged somewhere else. Orbit starts from where the
object stands, at its own distance and angle, rather than jumping onto a
circle.

## What a scene keeps

Saving writes more than the models. Each model records what is attached to it,
which is how a water surface comes back as water rather than as a mesh with a
wave table nothing reads:

| | |
|---|---|
| component | `water`, `voxel`, `light` or `mesh` |
| light | the light a marker stands for: its kind, colour, strength, reach and a spot's cone -- its own, not the scene's key light |
| script | the behaviour running on it, if any |
| physics | the body it is (`static`, `kinematic`, `dynamic`), its collider from its own mesh (`box`, `sphere`, `capsule`, `hull`, `mesh`), the surface's `friction` and `restitution`, and the `density` |
| water | every knob of the simulation driving it, the wave scale, the shore and the sky image it reflects included |
| material | colour, metallic, roughness, reflectivity, alpha, and the texture and normal map paths |
| rendering | FXAA, bloom, reflections (SSR), clouds and their cover, the overcast, ambient occlusion with its strength and reach -- the view menu's switches, applied on the backend that has them |
| weather | the kind by name (`clear`, `rain`, `snow`, `dust`, `storm`), its strength, the wind's heading in degrees and its speed |

The SKY section is the sky: three colour channels, the image it is drawn
from -- None, Desert, Dusk or Night, the skies that ship with the engine --
and Sun by time, which draws it from the sun at the hour beside it and
takes the viewport while it is on. A scene that arrives with a sky of its
own that is none of those keeps it: no button is lit and the path is
spelled out under them, so opening a program's scene and saving it never
trades its sky for one of these.

and the file records the view: where the camera stood, its field of view and
clip planes, whether face and frustum culling were on, the reflections'
road height and strength, the fog -- whether, where it starts and is
whole, and its colour, the sky's -- and the sky itself: its colour, the
hour the sun is set by, and the image it is drawn from when it is drawn
from one (`skybox.image`, what `engine.engine_set_sky` was given). A
program that sets a sky -- five of the examples do -- had its scene open
here under the clear colour until the file carried that name. Each model names its `parent` by index,
and a `group` is a model with no mesh: a transform its children are
placed by. A system's own models -- a ragdoll's bone capsules -- are not
in the file at all; the program makes them again.

A voxel world is written as what it takes to fill one again, its size and its
seed and its terrain, rather than as its grid: six numbers reproduce it exactly,
where the grid they replace is a megabyte and a half. What a hand did to it
afterwards is written beside them as `columns`: every column whose height is
not what the seed makes, as x, z and height, which is a few numbers for a
stroke of the brush and nothing at all for a world nobody touched. Loading
fills the world from its seed and then sets those columns.

The bar under the viewport is what the frame cost: the backend's name, the
rate, the renderer's passes (shadow, scene, post), the readback where the
viewport is blitted rather than presented, the draw calls, the triangles
and the size it was rendered at. A bounded run writes the same figures to
`AE3D_EDITOR_REPORT` as `fps`, `first_fps`, `paint_ms` (the editor's whole
frame callback), `passes`, `draws` and `blit_ms`, and `ready_ms`: how long
from the start of the program to the first frame drawn with the scene in
it, which is what someone opening a scene waits for (the street of
`examples/street_drive.ae`: about 1.7 s, against 0.84 s for the editor's
own scene). `first_fps` is the first
frame after a scene opens and carries its upload to the GPU -- the street
shows 4 fps there and settles at 90 -- so it answers "did the viewport
ever draw", not "how fast is it".

`AE3D_EDITOR_SCENE=roundtrip` builds the component scene, saves it and opens it
again before the run starts, so the report describes what came back rather than
what was built. CI asserts the same component counts for it as for the scene
built directly, which is what catches a component the file does not carry.

A scene written by a program is the same file. `AE3D_SCENE_OUT=path` makes
any program write its scene on its first frame -- once every script has
started and built its objects, before anything moves -- with every model
the renderer draws, the lights, the view as the program set it (the
camera, the sky and its hour, the post chain, the occlusion) and the body on
every object that has one, which `ae3d.physics` answers through the
engine's attachment providers. `./build/ae3d_editor path` opens it: the
street of `examples/street_drive.ae` is 1,347 models and 299 bodies, and
opens in a few seconds, since a source file shared by many entries is read
once and copied. The agent channel's `scene.save` writes the same file
from a running program.

## Running it bounded

The editor takes a few environment variables, which is how CI drives it.
The Linux job fetches aether-ui at the commit `.github/workflows/ci.yml`
pins (`AETHER_UI_REF`) and GTK4, builds the editor against it, runs it
bounded on both backends and the roundtrip scene, and presses its
widgets through `tools/drive_editor.ae`; the other runners have no
toolkit checkout and skip it, and so does a machine without one.

| | |
|---|---|
| `AE3D_EDITOR_FRAMES=n` | stop after `n` frames and exit |
| `AE3D_EDITOR_SNAPSHOT=path` | write the viewport to a PNG on the last frame |
| `AE3D_EDITOR_REPORT=path` | write what the editor built to a text file |
| `AE3D_EDITOR_SCENE=components` | start with water, voxels, a light and a behaviour |
| `AE3D_EDITOR_SCENE=roundtrip` | the same, saved and loaded again before the run |
| `AE3D_EDITOR_PLAY=n` | Play with `n` clients from the first frame, each world shown in turn a frame at a time |
| `AE3D_SCENE=path` | open this scene file (or pass it as the argument); Save writes it back |
| `AE3D_EDITOR_DRIVER=1` | serve the widget tree on `127.0.0.1:9222` |
| `AE3D_EDITOR_BACKEND=opengl` | use the OpenGL renderer; Vulkan is the default where a driver exists |

A report always plays, after the run's frames and before its other
checks: the play the frames began (or a host and two clients started
then), every player walking a circle of its own for two and a half
seconds and standing, on the play's own clock at the fixed step. Then W
is held half a second in client 2's view, and then Stop. It writes:

| | |
|---|---|
| `play_clients` | the clients |
| `play_views` | the worlds the viewport drew in the run's frames |
| `play_welcomed` | the clients the host welcomed |
| `play_prediction_um` | the most a reconciliation moved a client's player, micrometres |
| `play_own_um` | at rest, the furthest a client's own player is from the host's |
| `play_remote_um` | at rest, the furthest a client draws another's player from the host's |
| `play_focus` | 1 when the keys walked client 2's player, and no other |
| `play_leaked` | sessions and hubs alive, and renderer models and engine objects not given back, after Stop |
| `play_restored` | 1 when every networked row stands where it stood before Play |

`ci.sh` runs every editor run with `AE3D_EDITOR_PLAY=2` and holds it to
three worlds drawn, two clients welcomed, a reconciliation under a
centimetre, a client's own player at rest within a millimetre of the
host's and the others it draws within a centimetre, the keys' focus, and
nothing left behind. On this machine: 3 worlds, 2 welcomed, 0 um (a
reconciliation moves a player under a micrometre), 0 um, 43 um (the
snapshot's tenth of a millimetre), 1, 0 and 1, on both backends and the
roundtrip scene.

The driver is how the layout is checked without being able to see it. aether-ui
cannot rasterize widgets to pixels, so `GET /widgets` and its geometry is the
only way to tell whether a panel is where it should be.

## How the viewport works

![The viewport: the scene drawn into the toolkit's GPU view, the gizmo on a canvas over it](images/editor-viewport.png)

aether-ui hosts a real GL context
([aether-ui#92](https://github.com/aether-lang-dev/aether-ui/issues/92)), so the
scene is drawn straight into it. The viewport is two layers: the GPU view
underneath, and a canvas over it carrying the gizmo. The canvas keeps every
event it ever had, so orbiting, picking and dragging are unchanged; what it no
longer carries is a copy of the scene.

That is worth more than the readback it saves. A canvas can only ever hold the
canvas's own point size, so the blit path rendered the scene at 880x622 on a
display whose viewport is 1760x1244 pixels and let the window scale it up. The
GPU view is given the framebuffer size, so the picture is the screen's.

Two sizes follow from that, and mixing them is a bug the compiler cannot catch:
the renderer and the camera work in the framebuffer's pixels, and the gizmo is
drawn and picked in the canvas's points.

Where there is no GPU surface to draw on, the scene is drawn into a framebuffer
of its own, read back and blitted into that same canvas, which is what every
run did before and what a Vulkan run still does: Vulkan cannot draw into a GL
context. `ci.sh` reads `viewport_path` out of the editor's report and fails an
OpenGL run on macOS that took the blit, because falling back is invisible in a
picture. It checks the snapshot's size against the size the scene was rendered
at for the same reason.

The one thing the GPU path does not carry is the gizmo in a snapshot: a
snapshot is the frame the renderer produced, and the gizmo is on the canvas
above it.
