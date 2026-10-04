### Motion: a box man that walks, and locomotion upright on it

- The box-man fixture (`tests/fixtures/gltf/humanoid.glb`) has Walk and
  Run (#611). They're gaits on the spot, made by
  `tools/make_gltf_fixture.ae` rather than keyed by hand:
  - each foot, relative to its hip, slides straight back along the ground
    through its stance and comes forward lifted through its swing;
  - the legs are solved onto those places with two bones each, and the
    feet kept level;
  - the hips are at the height the foot on the ground holds them: lowest
    at the ends of a stride, about 4 cm down, as an inverted pendulum's;
  - the arms swing against the legs.
  - A walk is 1 s a cycle and a 0.5 m stride (1 m/s), lifting 0.14 m; a
    run is 0.7 s and 0.76 m (2.17 m/s), lifting 0.25.
  - The foot's lift had to clear the 5% of the figure's height that marks
    a foot in a clip made in place, or locomotion read no speed off it.
- `test_humanoid_fixture` holds the walk: the foot on the ground goes from
  0.25 m ahead to 0.25 m behind with its ankle at 0.07 m and the foot
  level, both to 7 µm, and it lifts 0.14 m mid-swing.
- Locomotion gave the hips back their clip's place and turn only when both
  were still what it had written. A walk keying the hips' height but not
  their turn had last frame's lean kept and leant on again, until the
  figure stood on its head within a second. Each is now given back on its
  own.
- `test_locomotion` walks the box man straight four seconds:
  - posed by speed, the toe on the ground drifts 1.4% of the body's way;
  - posed by matching, 3.8% (held under 5%);
  - it stays upright, its head over its hips, every frame.
- On the biped the skating through turns (#611) is plain: the planted foot
  slides 40–65% of the body's way in a turn, against under 2% straight.
