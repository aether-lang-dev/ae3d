### Knees no longer bend backwards, and figures stay out of the ground

The plaza showcase now prints a scorecard of what a player sees wrong, in
figure-seconds: knees bent backwards, figures inside each other, feet or
bodies sunk in the ground, bodies in the car, heads spinning, and bodies
walked through. Measured over 20 s with 20 walkers, four fixes:

| | Before | After |
|---|---|---|
| Knees bent backwards | 442 s | 1.1 s |
| Feet or bodies sunk in the ground | 72 s | 15 s |

- **ae3d.feet bends the knee the way the clip bends it.** The knee's IK
  pole was the root's +z. The box man's clips walk along its own x, so
  its knees were solved bent backwards whenever it walked. The pole is
  now taken off the line from hip to ankle, where the clip has the knee.
  Near straight it keeps the way the knee last bent. `tests/test_feet.ae`
  holds a walk frame's knees on a slope bent the clip's way.
- **A character controller walks through its own figure's ragdoll.**
  `physics.character_ignore(c, ragdoll)` excludes that ragdoll from the
  controller's casts and contact planes. With the walker's bodies in the
  world, the capsule stood inside them, was pushed out of them down
  through the ground, and walked on below it.
- **A ragdoll's rig puts the hips on the pelvis.** When physics poses a
  rig from its bodies, it now places the hips bone where the pelvis body
  is, as well as turning it. A clip held under the ragdoll moves the hips
  about the root, and every drawn bone followed them: 0.3 to 0.6 m off the
  bodies, the knees and toes in the ground as a struck walker got up.
- **Handed back on the ground.** A struck walker taken back by its
  locomotion stands on the ground under its body, not at the height the
  ragdoll had carried its root to.
- **Handed back, the hips go back to the animation's place.** Restoring
  the animation's pose now sets the pelvis bone's position as well as the
  root's. Left where the bodies had put it, a clip that keys no hips
  translation drew a walker handed back with its hips under the ground.
  Its bodies, woken by a body thrown nearby, followed them through the
  floor: one walker was 202 m below the plaza a minute on. None fall
  through now.
- **A drawn toe stays on the ground.** When physics draws a figure from
  its bodies, a drawn toe that would go under the ground has its foot
  turned up about the ankle: the ankle the bodies lack, since a calf's
  body carries its foot rigidly. The ankle gets its own turn back when
  the animation's pose is restored. Without that, a zombie given back to
  the horde kept a foot 305 mm off its pose. Feet sunk in the ground:
  673 s to 534 s a minute over 20, 24 and 28 walkers. Most of what is
  left is a clip held under a struck walker re-posing the drawn legs
  after physics draws them. Stopping the held clip takes it to 24 s, but
  then 60% of struck walkers walk again instead of 96%, so the clip is
  held for now.
