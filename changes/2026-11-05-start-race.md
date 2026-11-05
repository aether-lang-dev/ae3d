### Starts that keep their pace (#937, #969)

- **A start's clock held to its pace** (`animator.clock_most`). A start
  clocked by the distance come is held to 1.25 times its own pace; once
  behind, it plays on by the distance gone each step, so its planted feet
  keep to the ground, and a new condition, `animator.BEHIND`, hands it to
  the gaits in step once it trails its distance by 0.25 s. The people's
  StartStop start raced up to 28 times its pace.
- **A take that begins on the move** is read from where it first stands
  (`clips.moving_at`, each stand and move held 0.1 s): the StartStop start
  walks in, stands, and walks off at 1.55 s, and its "start" had been the
  slowing tail of the step before.
- **A use entered with both feet down**: a turn's step still in the air as a
  seat's enter began landed 10 mm from where it touched.
- Set off from a stand at 1.2 and 2.6 m/s, ahead, to the sides and behind
  (test_humanoid): the fastest joint 196% of the takes' own plus the
  easing's, now 95%; a foot 116 mm past the hips' middle, now never. The
  plaza's three seeds: feet crossing 112, 70 and 77 mm, now 18, 0 and 3; a
  toe thrown setting off 11 to 19 m/s, now 4.7 and 3.9 (seed 1's 16.8 is
  a lock let go in a steady 1.55 m/s gait, not a start); the fastest joint
  52 and 35 rad/s, now 23 and 22. Seats' worst toe skate 1.0 mm, now 0.19.
