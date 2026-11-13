### Faces: eyes that lead the head, saccades, blinks in the pose (#910)

- **Eyes turned by the look** (`ikrig.look_solve`): a rig's eye joints
  (`pose.EYE_L`, `EYE_R`, found by the names VRoid, Mixamo, MetaHuman and
  Rigify give them) each turned onto the point on its own line to it, so
  near points converge, within 40 degrees of the way the head faces (an
  eye's own range; past it the head takes over). A gaze shift (over 2
  degrees) is the eyes' saccade at once, its length the main sequence, and
  the head's turn 70 ms after it; smaller changes are followed by both.
  On VRoid's base female: the eyes within 1e-14 degrees of points 0.25 to
  2 m away and up to 60 degrees aside, converging 9.3 degrees at 25 cm;
  a 35 degree shift moves the eyes at once and the head 71 ms later, its
  saccade 104 ms over 30 degrees a second.
- **Saccades** (`face.Saccades`): fixations of 200 to 400 ms, then a
  saccade to another point within 5 degrees of what is looked at or a
  microsaccade under a degree, on a minimum-jerk profile lasting 24 ms
  plus 2.5 ms a degree. Over two minutes at 1 kHz: 363 saccades (155
  microsaccades, the largest 0.79 degree), every one on the main sequence,
  fitted at 24.4 ms plus 2.52 ms a degree. The animator turns the eyes by
  them (`animator.face_on`).
- **Blinks as an animator layer** (`animator.face_on`, `blink`): the
  figure's face targets become the rig's curves when the animator is
  attached; the blink goes over the eyeBlink curves of the frame's pose
  (the larger of the two) and reaches the weights through `pose.apply`,
  16 a minute; a gaze shift over 30 degrees brings one a third of the time
  (`face.blink_on_shift`: 948 of 3000, and 118 of 400 through the
  animator).
- **VRoid figures**: `pose.SCHEME_VROID` maps VRoid's skeleton as a
  humanoid, `gltf` reads target names a primitive carries
  (`primitive.extras.targetNames`, as VRoid and UniVRM write them), and
  `face.shape_of` takes VRoid's `Fcl_EYE_Close_L` and `_R` as the blinks.
- **A CC0 face**: VRoid Studio's base female (`tests/fixtures/people/
  vroid_base_female.vrm`), its pictures stripped and its morph targets
  made sparse by `tools/gltf_strip.ae`: 1.1 MB of the original's 16 MB,
  every number the tests read the same. No face with ARKit's 52 shapes under
  CC0 or CC BY was found.
