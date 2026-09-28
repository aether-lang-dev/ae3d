### A camera that keeps out of the scene, framing, and the street in a city

- **The camera keeps out of the scene** (#470, `ae3d.viewpoint`). The camera
  the engine flies is a sphere around the eye, 0.2 m or as far as the near
  plane's corners reach, that the static geometry keeps out: each move swept
  and slid as the character controller walks (Box3D's mover: cast, gather the
  planes, solve, clip, five times), held to a radius over the static world's
  lowest surface as it is swept, so it slides along a wall, rests in a
  corner, never passes a 0.5 m wall at 200 m/s and never goes under the
  ground. It collides with the physics world's static bodies when physics is
  attached (`physics.attach` lends its world) and otherwise with a world
  built from the scene's static models -- both sides of every triangle; not
  skinned, a crowd, a particle, clip-driven, nor instanced unless
  `core.model_set_solid` says its instances stand still -- a model's mesh
  built the first time the eye comes near it (`engine_camera_prepare` for a
  large one at load) and its body let go when the eye has left. On by
  default: `engine_set_camera_collision(e, false)` to fly through; the
  editor's camera, over `engine_over`, is its own. `engine_camera_boom(e,
  pivot, wanted)` for a camera a script places, `street_drive`'s chase.
- `tests/test_camera_collision.ae`, 22 checks through injected keys on both
  backends: the road face first and by the rise axis, a wall at 200 m/s (3 m
  a frame), a 45-degree slide at 14.14 of the 14.14 m/s along the wall, a
  corner, the road's edge (no lower than the lowest surface, not under the
  road from the side), off, physics (the static wall stops it, the kinematic
  crate and the model wall do not), a boom through a model's wall and the
  physics world's, a pane facing away, instances solid only when marked;
  every frame at least the radius from every box, 0.205 m. A sweep 2.4 us.
  `AE3D_CAMERA_WANDER=n` flies any scene's camera at random and measures each
  move against the drawn triangles themselves: 5,000 frames each through
  `zombie_street` and `zombie_city` at 6-20 m/s come no nearer anything than
  0.205 m, never inside, never under the ground; a move 0.12-0.15 ms.
- **Framing** (#471). `engine_frame(e, models, share, yaw, pitch)`,
  `engine_frame_bounds` and `engine_frame_points` (eased, to follow without
  cutting) place the camera where every vertex as drawn -- transform, skin,
  instances, a crowd's poses -- fills `share` of the frame's height, near and
  far fitted. `gltf_viewer` frames any file over its whole clip (the fox, the
  arm and the box man at 55%; it opened inside the arm); `gltf_crowd` lays
  the horde out in the figure's own measure and follows it from a raised
  three-quarter view (the fox horde was a brown wall, 195-unit foxes in a
  35 m field). `tests/test_framing.ae`, 56 checks: every glTF fixture and the
  box man at 100x and 0.01x span 55% of the height, the camera outside every
  model, nothing behind the near plane; drawn through OpenGL and Vulkan they
  land within a pixel of the numbers; a crowd of foxes the same; a followed
  group stays 55-62% of the height, a jump followed at 1.7% of the gap a
  frame.
- **The street in a city** (#472). `zombie_city` draws its block, merged a
  material and instanced, around the camera's block to 400 m -- parallel
  streets and this one past its ends -- over a 3.6 km ground, with a skyline
  ring at the horizon that rides at the eye's height. The camera stands on
  the pavement at head height with the horde (spawned over 240 m around it)
  hunting it. At ten seconds, drawn as normals with no sky (`AE3D_SKY=0`),
  no clear-colour pixel below the horizon in the default, grazing, moon,
  roofs, side and low views (was 116, 430 and 18 in the default, side and
  low); the horde covers 24-25% of the default view (`AE3D_HORDE_ONLY=1`;
  was 6.3-6.5%). The default view holds 144 fps at 1280x720 on an RTX 4070
  Ti (6.2 ms scene); the city itself costs nothing measurable (1.94 ms with
  the horde removed, against 2.08); its blocks throw no shadow, which by ray
  cost 0.85 ms for shadows behind the terraces. `tools/probe_image.ae --key
  R G B [ROW]` counts one colour's pixels.
- **An instanced model is its instances, however many** (found by the
  sweep: `zombie_city` on OpenGL drew triangles stretched across the frame).
  OpenGL gave an instanced model a vertex array and instance streams of its
  own only when it was added with instances; the city's blocks, added empty
  and filled as the camera walks, went through the shared geometry cache and
  drew their instances through a vertex array with no stream. Now every
  instanced model has its own from the start, sized as its instances come.
  An instanced model with no instances draws and casts nothing on either
  backend: it was its mesh once where it stood, merged into a batch on
  OpenGL and the draw's identity instance on Vulkan. A point stream's size is
  counted at its 32 bytes an instance, not a matrix's 64 (two points raised
  to four wrote past the buffer); the colours and phases go out with the
  matrices, as Vulkan's one stream does (a count raised over instances
  coloured earlier read past the colour buffer); the shadow pass sends a
  stream that changed before it draws it. `tests/test_instance_streams.ae`:
  blocks added with none, then three, five moved and recoloured, two, five
  by the count alone, none; points raised from two to four; every place
  named by its colour on both backends, and the two frames the same place by
  place. Without the fix OpenGL fails all six frames and Vulkan the two
  empty ones. `zombie_city` no longer hides an empty set itself.
  `test_framing` read OpenGL's frame through the backend's pipelined
  readback, a frame behind; it reads the target now.
- **Window panes** (#478, not closed: no Blender here). 222 of the street's
  346 pane triangles face into their buildings -- `recalc_face_normals` over
  loose sheets in one plane -- so those windows are holes onto the hollow
  shells. `make_zombie_street.py` now winds each pane to face the street and
  keeps it; `tools/check_panes.ae` counts the panes facing in (222 today, 0
  once the street is rebuilt and exported).
