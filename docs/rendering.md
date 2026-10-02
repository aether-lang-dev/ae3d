# What the engine draws, and how

The feature list in full, with the reasoning behind each. The [README](../README.md) is the short form.

## Features

- **Two renderers behind one interface.** `Backend` is a vtable both the OpenGL
  and Vulkan renderers fill in; a program picks its renderer with a constructor
  argument and nothing else changes. `tests/test_backend_parity` draws the same
  scene through both and compares them channel by channel across materials,
  textures, instancing, transparency, skybox, FXAA, bloom, shadows, multiple
  lights, a Gerstner ocean, an instanced voxel chunk, the clouds, the
  occlusion and instances placed as points. They agree to within 0.7% of
  channels, and CI fails if the generated Vulkan shaders fall behind the GLSL
  they are made from. The scenes a person looks at are held to each other
  too: `tools/scene_parity.ae` draws `zombie_city` from its seven views,
  `zombie_street` and `street_drive` on both at a fixed tick and compares
  them region by region ([testing.md](testing.md#the-scenes-on-both-renderers)).
- **The sun by the hour.** `engine_set_time_of_day(hours)` puts the sun where
  the hour does and sets the key light, the fog and a sky drawn from the same
  sun -- blue at noon, gold and red at dusk, moonlit at night -- so the sky,
  the clouds and the light agree; the editor has it as a switch and a slider,
  and the scene file carries the hour. Once the sun is 0.10 under the
  horizon the key light is the moon, across the sky on the sun's arc, and
  the night is lit and shadowed from above; the sky stays the hour's whatever
  the key light is, with the stars and the moon's disc over it at night
  (#526). A light's back fill, the light it lends the side turned from it,
  is never shadowed: under the sun's map, cast up through the ground, it
  had been a night's whole light, and a shadow took a third of it.
- **Instances as matrices or as points.** An instanced model carries a
  matrix, a colour and a phase per instance, or -- `model_enable_point_instancing`
  -- a position, a scale, a colour and a phase in eight floats, with the
  model's own rotation and scale applied to all of them in the shader. A
  million grains of sand that all move in a frame are a 32 MB stream
  instead of an 80 MB one built matrix by matrix, on both backends. An
  instanced model is its instances, however many: it can be added with none
  and filled later (`model_set_instance_draw_count` up and down its
  capacity, a city streamed around the camera), and with none it draws and
  casts nothing, not its mesh where it stands (`tests/test_instance_streams.ae`
  holds the two backends to the same frames as the count, the places and
  the colours change).
- **Skinned crowds in one draw.** A figure's walk is baked once into a pose
  bank (a texture of bone palettes); every instance carries its own phase and
  is posed from the bank in the vertex shader. A crowd of the real 26,636-
  triangle zombie is one instanced call per distance tier, and the bake is
  *in place*: the clip's travel is taken out of the poses and handed back to
  the simulation as speed, so feet plant instead of skating and nothing
  snaps at the loop.
- **A data-oriented ECS** (`ae3d.ecs`): entities as integer handles, components
  in dense columns a system walks in one pass, a crowd rendering straight from
  the position column's buffer. The crowd step, separation grid and
  distance bucketing are `ae3d.horde`, over those columns and the job pool.
- **Physically based shading**: metallic/roughness materials; the key light
  and any directional light reach every pixel, and every point and spot
  light the scene registers, however many, lights what it reaches through
  clustered shading (`ae3d.lightgrid`, [Lamps](#lamps)); a spot light
  (`core.light_spot`) is a point light confined to a cone about its
  direction, whole within an inner angle and gone at an outer with a smooth
  fall-off between, which is what a headlight is -- normal mapping, baked per-vertex occlusion and
  screen-space ambient occlusion from the scene's depth (`engine_set_ssao`,
  both backends), the key light's shadow in four cascades that a moving camera does not
  move ([Shadows](#shadows), both
  backends), volumetric clouds and their shadows, a sky drawn from the sun by
  the hour or a painted one, fog applied after tone mapping and the key
  lamp's light scattered in the fogged air (the haze stands around a lamp
  and thins away from it, marched along the view ray; both backends,
  `rendering.set_frame_haze`), MSAA, FXAA and bloom. Screen-space
  reflections on wet surfaces on Vulkan.
- **A wet road, not a mirror.** The reflection (`engine_set_ssr(e, on,
  road_height, strength)`) is Fresnel-weighted -- little from a camera
  looking down at the road, most at a grazing look -- over a puddle mask in
  the road's own metres: still water in the puddles mirrors sharply, the
  damp tarmac between them dimmer and blurred by a cone over the distance
  the ray travelled (eight taps on a disc turned per pixel). The base
  reflectance sits above water's 0.02 because the frame is display values:
  a lamp is white in it, and two percent of white is nothing where two
  percent of the lamp is the streak every wet street has. The critique
  counts the reflection as the share of the road band the mirrored scene
  lifts by a visible step (13.6% in the street, wanted 5%), not as cells
  that go white -- the mirror did that; a wet road does not.
- **Models compose.** A model keeps its own transform and composes it onto its
  parent's, so bones are ordinary models: a clip exported from Blender drives a
  bone exactly as it drives a part, and `ae3d.ik` solves a limb of bones
  without being told they belong to a skin.
- **Water that is water.** A Gerstner sea with deep-water dispersion, shaded
  as one physically based surface: Schlick fresnel between the body of the
  water and the reflected sky (the scene's own skybox image, where it has
  one), GGX glitter from the sun, light through the crests, whitecaps on the
  steep faces, ripples finer than the mesh from scrolling noise slopes, tone
  mapped and fogged the same way as the shore beside it. The shore itself
  comes from the scene's depth, captured after the opaque pass on both
  backends: shallows go clear over the sand and a foam line runs along the
  waterline. From underneath, the
  surface is the sky through the swell and the seabed is lit by a two-scale
  caustic web with a chromatic fringe.
- **Volumetric clouds.** A layer of cloud marched in the sky shader over
  whatever sky is set, built the way a production sky builds it: a weather
  map says where cloud is and what kind, from a low stratus to a tall
  cumulus; a tileable Perlin-Worley cube gives the body and a Worley
  fractal erodes its edges, wisps at the base and billows above; each
  sample is lit by the sun through the cloud over it, in three octaves of
  Beer's law with the powder darkening and a two-lobe phase, and by the
  sky. The noise is baked once at start into a 2D and a 3D texture
  (`ae3d.cloudnoise`), so the march is a fetch a sample and the
  clouds are a millisecond and a half of the frame. The ground computes
  the same weather field where the sun's ray meets the layer, so their
  shadows cross the terrain as they drift. One call,
  `engine_set_clouds(cover, wind)`, on either backend.
- **Weather.** `ae3d.weather` puts rain, snow, dust or a storm over any
  scene with one call: `weather_set(w, STORM, 0.8)`. The particles are point
  instances -- a position, a scale, a colour and a phase each, the stream
  the sand's grains use -- stepped over the job pool in a box that rides ahead of the
  camera, so a hundred thousand drops cost a fraction of a millisecond
  wherever the eye goes; rain is a thin streak falling fast, snow a flake
  swaying down, dust a mote carried by the wind. Each kind sets the fog it
  brings, the cloud cover, the sky's overcast (`engine_set_sky_overcast`:
  the sky pulled toward a flat grey or ochre at its own brightness, which
  the clouds' ambient follows) and dims the sun; a storm adds lightning, the
  key light thrown up for three frames every few seconds at the storm's own
  beat. What the weather takes it gives back when set clear: the scene's
  own fog, clouds and overcast as they stood when the weather came
  (`engine_clouds`, `engine_sky_overcast` and their colour and drift are
  what the engine last set), and the key light's intensity, re-taken by
  `weather_relight` when the scene sets its light under the weather. The
  weather is a behaviour the engine runs; `tests/test_weather` holds the
  counts, the box, the sun, the fog, the sky given back and the lightning
  to their numbers. The editor runs the same module over its viewport
  through `engine_over`, an engine wrapped around a renderer somebody else
  draws with ([docs/editor.md](editor.md)); the agent channel sets the
  sky a weather brings by hand (`render.set` with `clouds`, `cloud_wind`,
  `overcast`, `overcast_color`) so a frame under it can be held against
  the clear one.

  ![Rain, storm, dust and snow over the island](images/weather.png)

- **Voxel worlds as a face mesh.** Only the faces that show, each corner
  carrying the sky it can see from the three voxels that crowd it -- the
  darkening in a crevice and the light on an edge a voxel world reads by --
  with the block kinds told apart through a palette image the world registers
  in memory. Surface nets over a signed distance field for the smooth kind.
- **Images the engine paints.** The skies, the sand and its normal map, a
  voxel palette, an island's albedo baked from its own height and slope: made
  by the engine from its own noise, registered under a name any texture path
  can use, nothing downloaded and nothing written to disk that need not be.
- **A camera that keeps out of the scene, and frames what it is shown.** The
  camera the engine flies is a sphere the static geometry keeps out: swept
  and slid, never inside a wall or under the ground, at 200 m/s as at a
  walk. One call places a camera where a model or a group fills a share of
  the frame from a chosen angle, its near and far planes fitted to it,
  whatever its size ([The camera](#the-camera)).
- **Also:** Perlin terrain, an OBJ/MTL loader, ray casting, keyframe animation
  in glTF's shape (step, linear, cubic), scenes that save and load with
  everything attached to them, a scene editor, and `AE3D_API=vulkan` to run
  any program on the other renderer.

![Twenty thousand zombies filling the street from end to end, seen from above the pavement](images/zombie-horde.png)

*`AE3D_CROWD=20000 AE3D_NEAR=28 ./build/zombie_city`: the near tier draws the
full mesh, the far tier the build's own 168-triangle stand-in, and past
eighty metres each zombie is a picture; the draw count does not change with
the crowd, and the simulation runs over the engine's job pool on every
core. Twenty thousand hold ~120 fps on an RTX 4070 Ti at 1280x720 with
the GPU shared, half a million 79.*

### Impostors

The third tier of a crowd is a picture. `tools/bake_impostor` bakes a
figure into an atlas: the figure seen from eight angles around it by eight
frames of its walk, posed exactly as the crowd poses it (its gait baked in
place into a pose bank, one instance at the origin), through a lens narrow
enough that the picture is near orthographic. Two atlases, read back
through the engine's capture channel (`engine_set_capture_channel`; no
effect -- post chain, reflections, occlusion -- runs over a channel): the
figure's **albedo**, before any light, and its **normals** in its own
frame. A crowd model whose mesh is one upright quad, given the atlases and
`model_set_impostor(m, cols, rows, width, height)`, draws each instance as
that quad turned to the camera, showing the cell for the angle the camera
sees the instance from (measured around its facing, the instance's own +X,
which is the crowd's yaw zero) and the frame its phase is at; the fragment
cuts it out by the atlas's alpha, turns the baked normal into the world by
the facing, and lights it with the scene's lights, shadow, occlusion and
fog like any surface. A lamp that warms the mesh beside it warms the
picture the same. The transparent pixels of an atlas carry the colour of
the nearest opaque ones (bled outward at the bake), so the texture's filter
and mip levels never blend a key colour into an edge.

### The crowd sorted on the device

On Vulkan a crowd's per-frame sort into its tiers is a compute pass. The
simulation keeps its columns -- a figure's position, yaw, phase and tint
-- and hands them to the device as eight floats a figure
(`device_crowd_update`); `crowd_sort_vk.comp` runs one thread a figure:
its distance to the camera on the ground, dropped past the cull, its tier
by the near and mid bands, its instance matrix from its yaw and the
tier's model's scale (the same matrix the CPU path builds), packed with
its colour and phase into that tier's stream, and counted into the tier's
draw command -- a workgroup at a time, so half a million figures are two
thousand atomics and not half a million. Every model that draws a tier
-- a body and its clothes, the fifteen parts of a modular character --
is a part with an indirect command of its own, its own index count over
the tier's instances, the sort's count copied into each. The tiers' models
(`device_crowd_bind`; two can share a tier, a body and its clothes) draw
by those counts through `vkCmdDrawIndexedIndirect`, the shadow pass too
over the same streams with the depth proxy's index count, and nothing
about the sort comes back to the CPU: no matrix is built, sorted or
uploaded there. The renderer records the fill and the sort at the frame's
start, before the shadow pass, once per crowd however many models draw
its tiers, with the barriers between last frame's reads, the reset of the
commands, the dispatch, the copy of the counts to the shadow commands and
the draws. `device_crowd_count` reads the counts of the last frame the
device finished, for a diagnostic. OpenGL 4.1 has no compute and keeps the
CPU sort (`crowd_tiers`); `device_crowd_new` returns null there.

### Motion vectors

Beside its colour, every scene draw writes where its pixel's surface was
last frame: a second colour attachment of the scene pass (R16G16, texture
space, this frame's unnudged position less last frame's; multisampled and
resolved like the colour on Vulkan, a second draw buffer of the post
framebuffers on OpenGL), cleared to zero, so a pixel nothing drew has not
moved. The vertex stage carries the vertex's clip position now and then:
a model from its own matrix of last frame (`model_frame_done` keeps it at
every frame's end) and the last frame's view-projection, unjittered; a
merged batch or an instance stream, which carries no history, from the
camera's motion alone; a crowd figure -- whose slot in the stream is not
its own from frame to frame, since the sort reorders -- from where its
walk puts it: `model_set_crowd_walk(m, seconds)` names the cycle, and the
figure's previous pose is its phase a frame earlier, its previous
position a frame's travel back along its facing, from the pose bank's own
travel; an impostor the same; the sky from the camera's turn. A skinned
palette's previous pose is not carried (a second palette is the OpenGL
uniform budget over); a skinned model's motion is its model's and the
camera's. Capture channel 3 (`engine_set_capture_channel(e, 3)`,
`AE3D_CAPTURE=3`) draws the vector in pixels, a hundred either way across
the byte and 128 for still, and `tests/test_velocity` holds it against the
camera's own projection to the pixel. On Vulkan `vkframe.velocity_texture`
is the resolved target, which is what an upscaler is handed (#324).

### Render scale

`engine_set_render_scale(e, scale)` (0.25..1; `AE3D_RENDER_SCALE=50` for
half) draws the scene at that fraction of the window's size: on both
backends the scene's own targets -- its colour, depth and motion vectors,
and the camera depth, the reflection and the temporal textures over them
-- are made at the scaled size and every pass but the composite runs at
it, and the composite draws the result to the window at the window's
size, which is the upscale. The answer is the scale adopted (clamped), so
a program stepping down a quality ladder knows which rung it got. An
upscaler that knows more than a bilinear sample -- DLSS (#324) -- sits
where the composite samples, handed the scene's colour, depth and motion
vectors at the scaled size and asked for the window's.

### Ray-traced shadows

`engine_set_ray_shadows(e, on)`, or `AE3D_RAYS=1`, on Vulkan where the
device has `VK_KHR_ray_query` (`engine_ray_query(e)` says): a ray from
every lit surface toward the sun through the scene's acceleration
structure, in the shadow map's place for the static scene. Every static
mesh gets a bottom-level structure at upload, from the same vertex and
index buffers the draws use; each frame the renderer adds the traced
models -- the ones that cast, drawn on their own or through a matrix
stream -- with their matrices, and the top-level structure is built
from them before any pass, in a ring of two. The scene fragment's
ray-query variant (`scene_rq_vk.frag`, GLSL 4.60, SPIR-V 1.4, the
structure at binding 5) traces one opaque ray, first hit, from a
little off the surface: lit, or the shadow's share of the light, exact
at any distance and with no map's texel to fit the world into. What the
structure does not hold -- a point stream, a crowd not in the rays, a
skinned figure past the rays' budget -- stays in the shadow map, which is
drawn with those alone while the rays are on, and the two shadows
combine, the darker winning; where the rays hold everything that casts,
the key light's cascades are not drawn at all (the frame's shadow stage is
the crowd's sort and the structure's build, and any lamp's own faces). Off,
or on a device that does not trace, nothing changes;
`AE3D_NO_RAYS=1` keeps the extensions off. `tests/test_ray_shadows`
holds the rays' shadow to the map's -- the same ground shaded to the
same depth, the same edge -- and past the edge, a ray's ground fully lit
where a map's filtered edge is still part way.

A crowd sorted on the device goes into the rays too:
`crowd.device_crowd_rays(dc, far, bank)` skins the far tier's mesh (a
hundred and sixty-eight triangles) at every frame of the pose bank on
the CPU, once, into a bottom-level structure each, and from then on the
sort's compute pass writes a ray instance for every figure it keeps
that is drawn as a mesh -- where it stands, turned as it walks, the
structure of the frame its walk is at -- straight into the frame's
instance buffer, after the static scene's. The impostors past the far
tier are left out (a card's shadow is not worth a ray), and so is any
figure past the shadow map's distance, which is as far as the map ever
shadowed. The buffer is sized before the sort from what the last frames
wrote back -- the count the sort reaches, kept in a host-visible word,
with a quarter's margin and a floor of four thousand -- and its room is
zeroed first so a slot the sort does not fill is an inactive instance;
the top-level build then takes the whole room, since the instance count
cannot come from the device on hardware without indirect builds.
`tests/test_ray_shadows` stands a device-sorted figure beside the ball
and checks the ground it shades by ray against the map's shadow of it.
The near band goes in as the mesh it is drawn with:
`crowd.device_crowd_rays_near(dc, near, bank)` bakes the near tier's mesh
at every frame of the bank the same way, and the sort points a near
figure's instance at those, at the near tier's scale, where the far mesh
stood in for it before -- a zombie beside the camera threw a
hundred-and-sixty-eight-triangle shadow. The structures are built to be
compacted and copied into the size they need (a build sizes a structure
for the worst its triangles could take), and the posed vertices are let
go once built: the city's zombie, 26,636 triangles at 48 frames with its
far mesh, takes 35 MB of structures a figure (94 MB uncompacted with the
posed vertices kept). `tests/test_ray_shadows` draws a figure near the
camera as a quad twice the width of its far mesh: with the far mesh
standing in, its shadow by ray is 1,760 pixels off the map's 4,251; with
the near structures, 1 pixel. A crowd none of whose models casts writes
nothing into the rays, as it draws nothing into the map.
Measured in the city (`AE3D_NEAR=3 AE3D_NOPROPS=1 AE3D_SEPN=4`, the
device sort drawing every part whole): at 400 figures nothing changes;
at half a million the frame goes from 78 to 63 fps with the whole visible
horde in the rays -- that scene packs a thousand figures a square metre,
so a shadow ray crosses hundreds of overlapping structures, a density no
game scene has -- and 20,000 at a 28 m near band stays at 110.

A skinned figure -- a player, anything drawn by its own skeleton -- is
posed into the rays each frame (`engine_set_ray_skinned(e, n)`, 32 by
default, 0 leaves them to the map): the nearest within the shadow
distance, each skinned on the device by a compute pass
(`skin_vk.comp`, a thread a vertex) from its bind pose and the palette
its draw is posed by, into a buffer its bottom-level structure is then
refitted from, every figure in one build call, and built afresh every
sixteen frames (the figures taking turns) so a pose far from the one the
tree was built in does not loosen it. Its instance takes the model's
matrix as the draw does. `tests/test_ray_shadows` stands a slab on two
bones with its top carried twenty metres sideways, and reads each shadow
as what the slab's casting darkens (the frame against the same frame with
it casting nothing): its shadow by ray has the footprint of its shadow in
the map to within eight pixels -- measured at 0 of 635 -- and lies 295
pixels from the upright slab's, so the pose traced is the one drawn;
posed again, the ray's shadow follows (0 pixels off); and with the slab,
the ball and the ground all in the rays the map is not drawn. In the
street, posing the zombie and its clothes (30,364 triangles) costs the
device 0.12 ms a frame (0.30 against 0.18 ms of the frame's shadow stage,
the median of three runs each at 720p) and the CPU 0.02 ms; with the
rays on it used to cast no shadow from the key lamp at all, since a lamp
the rays cover has no map and the figure was in neither. A figure whose
palette has not changed since it was last posed keeps its structure and
costs its instance alone. In `street_drive` the thirteen bystanders (26
skinned models) are all in the rays at the default budget and the map is
not drawn: the device's frame is 2.28 ms, against 2.29 ms with them left to
the map (`AE3D_RAY_SKINNED=0`), their shadows now the rays' like the
street's.

The sun has a size: `engine_set_sun_size(e, degrees)`, the angle its
disc subtends (`AE3D_SUN_SIZE=n` in tenths of a degree; the real sun is
about half a degree, and zero, the default, is a point sun and a hard
edge). With a size, a lit pixel traces four rays into the cone the disc
subtends, on a spiral turned by a per-pixel noise and by the frame's
jitter, and takes the blocked share: a shadow sharp where it meets what
casts it and soft where the caster stands far off, the way shadows are,
since a far caster covers the disc only partly. A still frame shows the
penumbra as a fine grain; under the temporal pass the frames' taps fold
into a smooth one. `tests/test_ray_shadows` holds a twenty-degree sun to
half-lighting the ball's hard edge while the shadow's middle stays as
dark and the far ground as lit, and a point sun to the hard edge again;
`AE3D_RAY_DUMP=<dir>` writes both frames. The four rays cost about a
millisecond of scene time in the city at 720p (3.4 to 4.5 ms with 400
figures); the shadow map's penumbra is untouched, since only what the
rays shadow takes the size.

Occlusion by ray: `engine_set_ray_occlusion(e, on)`, or `AE3D_RAY_AO=1`,
with the rays and the occlusion (`engine_set_ssao`) both on. The scene
shader traces four cosine-weighted rays into the hemisphere over every
lit pixel, each stopped at the occlusion's reach, on the same turned
spiral as the sun's taps, and darkens by the share that hit -- the share
of the sky the point does not see, from the scene itself, with no screen
edge or hidden surface for a depth-based estimate to miss -- and the
screen-space pass is not drawn. The rays start a hand's breadth out,
since a crowd figure is drawn from its near mesh and traced against its
far one, a few centimetres apart, and a ray from the skin found the
proxy. A still frame shows the grain; under the temporal pass it folds
smooth. `tests/test_ray_occlusion` stands a wall on a plane under a sun
from straight above: the ground at its foot goes darker by ray, the open
ground and the wall's top do not, and off again the screen-space pass is
back. In the city at 720p the opaque pass goes from 1.23 to 1.81 ms
(best of five) and the 0.11 ms screen-space pass is skipped.

Every lamp throws its own shadow. On the map path each lamp the budget
holds has a cube of maps of its own ([The lamps' own
shadows](#the-lamps-own-shadows)); by ray, each
point light that reaches a pixel casts one ray from the surface to a spot
on the lamp's face (`engine_set_lamp_size`, the face's width in metres,
twelve centimetres unless set), stopped sixty centimetres short of the
light so the fitting it hangs from -- the head, the arm -- does not
shadow the whole street with a grain. The spot turns by the golden angle
every frame (`rayFrame`; the projection's jitter was tried for this and is
a fraction of a pixel, which turned nothing), so the temporal pass folds
the frames into the lamp's penumbra. `tests/test_ray_shadows` puts the sun
out and a lamp over the ground beside the ball: the ground past the ball
goes from 598 with the ball casting nothing to 403, on the map path and by
ray alike, and the ground under the lamp stays lit on both. The city runs with the
rays on where the device traces, a light under every lamp head its tiles
place (twenty-one lamps; the nearest fifteen light a frame), the wet road's
reflection (`engine_set_ssr`), the occlusion by ray and the temporal pass:
400 figures 139 fps, 20,000 at a 28 m near band 54 (113 with the map alone,
`AE3D_RAYS=0`).

With the rays holding the skinned figures and the near band (#492), the
city draws no map at all (0 of 590 frames at 400 figures and at 20,000).
At 400 figures the frame stays at the display's 144 fps and the device's
time falls from 6.60 to 6.43 ms; at 20,000 with a 28 m near band it goes
from 18.4 to 19.05 fps, the device's time from 54.2 to 52.4 ms: the
near band traced as the figures drawn there costs the opaque pass less
than their stand-ins did. (The median of three runs
each, alternating with the tree before, at 720p on an RTX 4070 Ti. The
139 and 54 fps this page gave before were measured on 18 September;
the city has changed since -- at 20,000 its 28 m near band now holds
some 4,500 figures drawn whole, 137 million triangles a frame -- and on the same
machine the tree before this change draws it at 144 and 18.4, #498.)
The scene parity check (#494) then found the horde missing from the lamps'
own shadows on Vulkan -- a crowd sorted on the device was bounded by one
figure at the origin -- and put it there: at 20,000 the frame is 17.5 fps,
the lamps beyond the rays' reach each drawing the horde into their faces
(the shadow stage 9.6 ms, from 2.3), until each lamp's faces draw only the
figures within its reach (#505). At 400 it stays at 144.

What is left for the rays to do next: reflections by ray (#323).

### DLSS

NVIDIA's DLSS, through Streamline, on Vulkan: `engine_set_dlss(e, mode)`
before `engine_run`, or `AE3D_DLSS=n` (1 performance, 2 balanced, 3
quality, 4 ultra performance, 6 DLAA; ultra quality is not offered by the
current DLSS). The scene is drawn at the render size the mode wants --
the render scale above, with the scene's textures sampled a mip finer by
`log2(scale)`, so the detail the frame's pixels deserve is in the samples
DLSS reconstructs from, and with no multisampling, since a resolved sample
has none of that detail left -- and DLSS makes the frame from the scene's
colour, its resolved depth and its motion vectors, in the temporal pass's
place, with the same nudged projection (more phases: eight times the
square of the scale). The composite samples what it wrote.

How it is wired (`native/dlss/streamline.cpp`, C++ against the SDK's headers,
behind the C surface of `native/dlss/streamline.h`): the Streamline runtime is
loaded before Vulkan starts and its interposer stands in for the Vulkan
loader, so the instance and the device made through it carry what DLSS
needs; each frame the camera's matrices (column-major here, row-major and
row-vector there: the same sixteen floats), the jitter in render pixels
and the motion vectors' scale (texture space, and the other way round:
from where a pixel is to where it was) go in as constants, the four
images are tagged, and the evaluation is recorded between the scene's
passes and the composite. The runtime -- `sl.interposer.dll`,
`sl.common.dll`, `sl.dlss.dll`, `nvngx_dlss.dll` -- is NVIDIA's and not
shipped here: build with `AE3D_STREAMLINE_ROOT` naming the SDK
(github.com/NVIDIA-RTX/Streamline; the C++ shim is compiled only then,
a stub otherwise, so every other machine builds the same), and put the
SDK's `bin/x64` beside the program or in `AE3D_STREAMLINE`. Where DLSS is
not built in, not there or not for the card, the program is told why,
draws as before, and the temporal pass stands in for the multisampling
that was turned off for it. `tests/test_dlss` skips there; on an RTX it
holds the performance mode's frame, from half the pixels, to more than
the composite's own scaling of them and to within a fifth of the native
frame's sharpness.

What it buys depends on where the frame's cost is: `zombie_city` at
1080p with half a million figures, vertex-bound, goes from 73 fps under
the temporal pass to 76 at quality and 84 at performance; a scene bound
by its pixels gains by the render scale.

### Temporal anti-aliasing

`engine_set_taa(e, on)`, or `AE3D_TAA=1`. The projection is nudged a
fraction of a pixel each frame (a Halton sequence over eight frames), so
over frames every pixel sees its surface at eight points within itself,
and a temporal pass folds each frame into a history: each pixel's motion
vector says where its surface was on the screen last frame -- the
camera's motion, the model's, the figure's walk -- and the history read
there is held to the range of colours the pixel's neighbourhood has this
frame, so what the vector does not know of trails no ghost. An edge that
was a staircase is a ramp, and the shading's own aliasing goes with it.
On both backends; the pass runs between the reflection and the composite,
and the two history textures are written in turn.

### An exposure that follows the frame

A scene lit for a noon sun and a street lit by lamps want different
exposures, and a figure stepping into a headlight beam wants less than the
street behind it: tuning each scene's lights to one exposure is tuning the
next scene all over again (#378). With `engine_set_eye_adaptation(e, true)`
(`AE3D_EYE=1` for any program) the renderer measures what it drew and the
frame's exposure is steered from it, the way an eye adapts:

- the measure: the finished frame blitted into a texture and mip-chained
  down to 320 texels across (OpenGL: a blit and `glGenerateMipmap`; Vulkan:
  a blit chain after the last pass), read back two frames late through a
  ring of buffers, so nothing waits on the frame just drawn -- its mean
  linear luminance and the share of it near white;
- the steering (`ae3d.exposure`, arithmetic a test drives by numbers): part
  of the way toward a mid-grey key (a night street stays night), down half a
  stop for every doubling of the near-white share past 0.2% of the frame,
  never up while lamps or a lit face are in view, faster down (0.4 s) than
  up (1.2 s), between two stops under and one and a half over;
- the result, `frameExposure`, multiplies every material's exposure before
  the tone curve, in the default shader and the sea's.

The street's chase frame, 240 frames in, 1280x720:

| | clipped pixels (>= 250) | mean |
|---|---|---|
| Vulkan, fixed | 1,076 | 57.9 |
| Vulkan, adapting | 10 | 35.9 |
| OpenGL, fixed | 1,016 | 42.4 |
| OpenGL, adapting | 454 | 32.4 |

It costs nothing a frame can see (Vulkan 142.5 fps against 142.6). The
meter's buffer is in cached memory: read from the write-combined kind, the
quarter megabyte it is halved the frame rate. `street_drive` and
`zombie_city` run with it; it is off by default, so a scene lit for its
exposure keeps it and a test's pixels do not move under it
(`tests/test_exposure`).

### Billboards

`model_set_billboard(m, mode)` turns a point-instanced model's mesh to the
eye at every point: upright (mode 1), spun about the world's up alone, so
a streak of rain stays a streak; or full (mode 2), tipped to face the eye
as well, for a flake or a mote. The weather's particles are a quad with a
soft disc for a texture, drawn this way.

### Rain on the surfaces

`engine_set_wetness(e, amount)` is rain on the scene: every surface that
faces up goes darker (its pores filled), smoother, and a mirror at a
grazing angle, so the lamps smear down a wet road; walls, which water
runs off, hardly change. The weather sets it with the rain and the storm
and takes it back with the clear.

### The camera

**It keeps out of the scene** (#470). The camera the engine flies by the
input (`engine_set_camera_input`, on by default) is a sphere around the eye,
0.2 m unless the near plane's corners reach further (they widen it), that
the scene's static geometry keeps out. A move is swept and slid the way the
character controller walks -- Box3D's mover in aephysics: the sphere cast
along what is left of the move, the planes it then touches gathered and
solved out of, the rest of the move clipped against them, five times -- so
the eye slides along a wall at the speed its move has along the wall,
stops in a corner a radius from both faces, and does not pass through a
0.5 m wall at 200 m/s, three metres a frame. It never goes under the
ground: a move is held to a radius over the lowest surface of the static
world as it is swept, so past the ground's edge the eye cannot drop below
the street and look up at it. `engine_set_camera_collision(e, false)`
turns it off; the editor flies its own camera, which passes through
everything, over `engine_over`, which starts with it off.

What it collides with is `ae3d.viewpoint`'s. With physics attached
(`physics.attach` lends its world), the physics world's static bodies --
what the scene says stands still; not a crate, a car or a figure. Without,
a world of its own made from the scene's static models: every model the
renderer draws that nothing moves -- not skinned, not a crowd or its
picture, not a particle, not driven by a clip or hung off something that
is, and not instanced unless `core.model_set_solid(m, true)` says its
instances stand still (a city's buildings drawn a part at a time) -- as
its own triangles, both sides of each (a pane an export wound the wrong
way round let the eye into the hollow building behind it), at its own
transform or each instance's. The scene is read once a frame the camera
moves, a couple of milliseconds the first time for a street of 1,500
models and then only what moved; a model's collision mesh is built the
first time the eye comes near it (`engine_camera_prepare` builds a large
one as the scene loads instead), and its body is let go when the eye has
been away for a while, so a city streamed around the camera never fills
the world. A move through the street costs 0.15 ms on average.

A camera a script places each frame -- `street_drive`'s chase camera --
asks `engine_camera_boom(e, pivot, wanted)`: the sphere cast from over
what it follows toward where it wants to be, so a wall that comes between
them brings the camera in front of the wall rather than through it.

`tests/test_camera_collision` flies the camera by injected keys into a
road, a wall and a corner at 60 and 200 m/s, and holds it, every frame,
to at least its radius from every box measured from the boxes themselves
(0.205 m, the radius and the solver's slop); at 45 degrees into the wall it
slides at 14.14 m/s of the 14.14 its move has along it; with physics it
keeps out of the static body and passes the kinematic crate; a pane
facing away stops it; an instanced model stops it only when marked solid;
a sweep costs 2.4 us. `AE3D_CAMERA_WANDER=n` flies the camera at random
through any scene for n frames by the same injected keys and measures every
move against the drawn triangles themselves, closest point by closest
point, with a ray's crossings for whether it is inside anything: thousands
of frames through `zombie_street` and `zombie_city`, up to 20 m/s, come
no nearer anything than 0.205 m, never inside, never under the ground.

**It frames what it is shown** (#471). `engine_frame(e, models, share,
yaw, pitch)` puts the camera where the models -- every vertex where it is
drawn: through its transform, its skin's pose, each instance, a crowd's
figures at their phases -- fill `share` of the frame's height seen along
yaw and pitch, centred, further back where they would be wider than the
frame, never inside the sphere about them, with the near plane at half the
nearest point's depth and the far at four times the furthest's.
`engine_frame_bounds` frames a box, and `engine_frame_points` points a
program gathered (`viewpoint.points_add_*`), eased over a time so a
framing that follows something moving does not cut. `gltf_viewer` frames
whatever file it is given over its whole clip; `gltf_crowd` frames its
horde from a raised three-quarter view and follows it. `tests/test_framing`
frames every glTF file in the repository -- the box man, the fox a hundred
units long, the arm as `.glb` and `.gltf` -- and the box man a hundred
times over and a hundredth: each spans 55% of the frame's height by its
projected vertices, the camera outside every model's bounds, nothing
behind the near plane; drawn through OpenGL and Vulkan off the screen, each
lands on the rows the numbers give, within a pixel; a crowd of foxes at
their own poses the same; a walking group followed stays 55-62% of the
height and never moves the camera further in a frame than it moved.

### The scene's depth

The occlusion, the reflection and the water read the scene's depth. On
OpenGL it is blitted out of the frame after the opaque draws; on Vulkan the
frame's multisampled depth is resolved into a one-sample target between
the two halves the scene pass is drawn in, the nearest of the samples a
pixel. Both are the depth of what was drawn -- the near figure's real
silhouette, the picture of a far one -- and neither draws anything twice.

## Lamps

Every point and spot light a scene registers lights what it reaches, and
nothing else, wherever the camera is. The renderers used to light a frame
with the sixteen lights nearest the camera, so a street's lamps lit their
pools while the camera stood near them and went out as it walked away.

It works by clustered shading (`ae3d.lightgrid`, #468).
- **The grid.** Every frame the view is cut into 16 columns × 9 rows ×
  24 depth slices. The slices are logarithmic, so a cell is about as deep
  as it is wide at any distance.
- **The lists.** Each lamp is listed in every cell its sphere of reach
  overlaps: the distance from the lamp's view-space centre to the cell's
  box against its reach, taken axis by axis. A pixel shades with its own
  cell's list, so its cost is the lamps near it, not the lamps in the scene.
- **The reach.** A lamp reaches where its attenuation falls to 1/64 of its
  value at the lamp, the fall-off the shader used to cut at, and its light
  fades to nothing over the last quarter of that distance, so a pool ends
  in a gradient.
- **The layout.** The lamps (five vec4s each) and the cells' lists are
  built once on the CPU in one layout. Vulkan reads them as storage buffers
  at bindings 6 and 7. OpenGL 4.1, which has no storage buffers, reads the
  same floats from two textures.
- **The rest.** The key light and any directional light reach every pixel
  and stay in the shader's small uniform array.
- **The shadow.** A lamp's record carries the slot of its own shadow, or
  -1 where it has none ([The lamps' own shadows](#the-lamps-own-shadows)),
  and the slots' data follows the lamps in the same buffer.

Held to numbers:
- `tests/test_light_grid.ae`, headless:
  - 20,000 points through the view, each checked against a street of 256
    lamps by brute force: of the roughly 800,000 lamp-point pairs in reach,
    none is missing from its cell's list, from either of two cameras;
  - a cell lists about 45 lamps where about 40 reach its points;
  - a build takes about 1.3 ms for 256 lamps set 4 m apart.
- `tests/test_lamp_clusters.ae`, 64 lamps down a street on both renderers:
  - the ground under a lamp reads the same from 25 m and from 120 m on one
    line to it, within 1.3 of 255 (on the old renderer it lost 58);
  - OpenGL and Vulkan agree there exactly;
  - the scene pass costs about 0.02–0.03 ms with 64 lamps and about
    0.08 ms with 256.

## Shadows

A light is shadowed by its own map and by no other light's. The key light,
when it is the sun or the moon, is shadowed in cascades; every lamp the
budget holds, the key light too when it is one, by a cube of its own
([The lamps' own shadows](#the-lamps-own-shadows)); the other directional
lights, the fills, not at all.

The key light's shadow is drawn in cascades (`ae3d.cascades`, #469). One
shadow map fitted around the camera and snapped on the world's axes slid by
fractions of a texel whenever the camera moved, so every edge crawled, and
past its distance there were no shadows at all.

- **The splits.** The view is cut in depth into four slices, out to the
  shadow distance (`engine_set_shadow_distance`), or as far as the scene
  reaches when none is set. The cuts are three-quarters logarithmic and a
  quarter uniform, so the near slice is short and sharp and the far one
  long.
- **One map each.** Every slice gets a 2048-texel map in one 4096-texel
  depth atlas, two by two.
- **The fit.** Each map is fitted to the smallest sphere around its slice
  of the view. The view's angle does not change a sphere's size, so a texel
  stays the same size as the camera turns.
- **The grid.** Each map's origin is kept on its own texel grid: the
  world's origin, projected into the map, is moved to the nearest whole
  texel. As the camera moves the map moves by whole texels, and a shadow
  edge lands on the same texels whatever the camera does.
- **The casters.** A map's depth runs back toward the light as far as the
  scene reaches, so what stands between the light and a slice still casts
  into it. A caster is drawn into a cascade only where its shadow can land
  on what that cascade shades: its slice of the view and the band of the
  slice before that blends it in, put through the cascade's matrix and
  widened by as far as the shader reads from a receiver (the normal
  offset, up to 33.5 texels, and the filter's taps). Tested against the
  sphere's whole square instead, a street's casters went into three and
  four cascades each: `zombie_street`, its shadow reaching 18 m and its key
  lamp still drawn in cascades then, drew 339 calls where one map drew 255,
  and 250 with the test. Vulkan draws the casters kind by kind -- plain and batched,
  skinned, crowds, point streams -- each into every cascade in turn, so each
  pipeline is bound once.
- **The seams.** The scene shader picks a pixel's cascade by its depth
  along the view and blends the next one in over the last tenth of each, so
  no seam shows where the texels change size.

Held to numbers:
- `tests/test_shadow_cascades.ae` puts a 6 m post under a slanting sun,
  with an 80 m shadow distance, on both renderers:
  - the shadow's edges, read in world metres from 1280×720 frames, stay
    within 1.5–2.3 cm over twelve camera poses moved in 13 cm steps and
    turned (a texel there is 1 cm). The previous renderer's edges wandered
    by 13 cm;
  - a post 59 m away still casts;
  - OpenGL and Vulkan put the edges in the same place;
  - the four cascades cost about 0.08 ms on OpenGL and 0.11 ms on Vulkan.
- `tests/test_engine_shadows.ae`: through the engine, a floating box's
  shadow darkens the ground under it by 42%, and lit ground beside it does
  not move.

### The lamps' own shadows

A lamp had no shadow map, and the shader multiplied every lamp's light by
the key light's shadow instead (#490). A wall in the moon's shadow went dark
under the lamp beside it; a figure lit by three lamps threw no shadow from
any of them; and a street whose key light was a lamp -- `zombie_street`'s --
was shadowed along one direction from the lamp to wherever the camera
looked, so every shadow swung as the camera moved.

Now each lamp the budget holds has a map of its own (`ae3d.lampshadows`):
- **The cube.** A lamp shines every way, so its map is the six faces of a
  cube around it, 90-degree perspective views of 512 texels, from 0.6 m out
  (the fitting the lamp hangs in casts nothing, as the rays stop the same
  distance short) to the lamp's reach.
- **The atlas.** The faces share one 4096-texel depth atlas, eight by eight:
  ten lamps a frame.
- **The budget.** The key light when it is a lamp, always; then the lamps
  whose light reaches into the view, nearest the camera first, within 50 m
  of it (or the shadow distance, where that is further). A lamp keeps its
  slot while it stays chosen. A lamp past the budget is not shadowed at
  all -- never shadowed by another light -- and the last fifth of the range
  fades a lamp's shadow out, so one leaving the budget does not pop. Where
  the device traces, a lamp whose light lies wholly inside the rays' reach
  is left to the rays.
- **Two layers.** A face's static casters -- plain models, whose world
  stamp says when they move -- are drawn into a static atlas only when what
  stands still in the face changes. The atlas the shader reads is that
  layer copied up a tile at a time, with what moves on its own -- a skinned
  figure, a crowd, an instance stream -- drawn over the copy every frame it
  is there. A lamp over a walking figure costs a copy and a draw a face, not
  its street again: `zombie_street` draws 87 calls a frame on OpenGL and 88
  on Vulkan, where the one map it had drew 255.
- **The lookup.** Each clustered lamp carries its slot; the slots' data --
  where the lamp stands, its reach, its shadow's strength and the six
  faces' matrices -- follows the lamps in the lights' buffer. The shader
  picks the face a point lies in from the lamp, moves the sample off the
  surface along its normal by a face texel at that distance (and more on a
  surface the lamp grazes), and compares depths in metres from the lamp,
  since a perspective map's depth crowds toward its far plane.

Held to numbers: `tests/test_lamp_shadows.ae`, offscreen on both renderers.
- A lamp that is the key light, over a box: the box's shadow ends at
  4.934-4.938 m from four camera poses, where the ray from the lamp past the
  box's top edge meets the ground at 5 m, less 1.25 cm for every centimetre
  the sample is lifted (4.945 m). The poses move it by 0.3 cm, under a
  texel (1.95 cm), and OpenGL and Vulkan end it in the same place.
- A lamp over ground in the moon's shadow gives it 91.75, as the same lamp
  gives open ground 91.75; the moon alone, the wall's shadow reads 41 there
  against 110 in the open.
- Of twelve lamps down a street, the ten nearest have a shadow; past the
  nearest lamp's post the ground reads 30 against 83 with the post casting
  nothing, past the farthest's (outside the budget) 73 against 73.
- A frame in which nothing moved draws no static layer; a post moved under
  a lamp draws two; a cube as an instance stream hung under a lamp darkens
  the ground behind it to 29 (77 without it) with no static layer drawn,
  and moved away leaves 77.04 against 77.04.
- `tests/test_ray_shadows`: the map path and the rays shadow the ground
  past the ball from a lamp alike (403 each, 598 with the ball casting
  nothing).

## How it is put together

- **Aether never handles float32.** A model owns a native mesh holding
  interleaved position, uv and normal data and, when instanced, a native buffer
  of per-instance matrices. Aether's `float` is a C double; the columns the
  crowd systems walk are doubles and the GPU buffers are floats, converted
  once at upload.
- **The frame's uniforms go up once per program, not once per model.** Of the
  uniforms a draw needs, all but one are the same for every model in the
  frame. Draws that share geometry and a material -- its colour, its normal
  map and its numbers -- are merged into one instanced draw automatically
  (`core.set_draw_merging(false)` turns it off). A merged draw goes after
  every model drawn on its own, and sets everything it is shaded and posed
  by itself rather than keep what the draw before it left.
- **The frame allocates nothing.** `benchmarks/bench_frame.ae` runs the
  heaviest per-frame work two thousand times with no window: 578us to upload
  two hundred thousand instance matrices, under a microsecond each for
  transforms, camera, frustum and water, zero leaked bytes.
- **Only exposed voxels become instances**, and **the viewport readback is
  pipelined** (two pixel buffers, so the CPU never waits on the GPU; the editor
  runs a frame behind, anything comparing what it just drew takes the waiting
  read).
- **Vulkan links nothing.** The loader is opened at runtime, so a program built
  with the Vulkan backend still starts where no driver exists and says so.

