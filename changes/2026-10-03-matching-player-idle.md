### Motion: matching for a player's figure, contacts, network state; idle life; fonts through std.truetype

- `locomotion.use_matching(l, db)` (#591) poses a figure on a character
  controller by motion matching. `matching.follow` searches, plays and paces
  the clip for a body something else moves, without moving it. On the Fox
  the foot on the ground drifts 0.29% walking, 0.17% at half the stick and
  2.3% running. Staying with the playing clip now keeps the playing frame;
  before, the next query took its pose from the best frame, which wasn't on
  screen.
- Foot contacts from the database (#593): `matching.contact(m, foot)`. A foot
  is down when it is low in its rise and fall and slow over the ground.
  Walking, each foot is down 30–42% of the time and never all four at once,
  and a planted foot moves 1.8 cm at most.
- A matcher's state, 144 bytes (#594). `state_write` and `state_read` let a
  second matcher over the same clips pose its figure exactly as the first
  does: every bone, to the bit, in all 240 frames of the test.
- `ae3d.idle` (#592): over the clip, a standing figure breathes (the chest
  2 degrees at the top of a breath, every 4.2 s or so, its pace drifting)
  and shifts its weight (the hips ±2.5 cm over 7.3 s, out of step with the
  breath). Both fade out as the figure moves.
- `ae3d.glyphs` reads fonts through `std.truetype` (#570): the reader it
  carried moved into std. The module goes from 1788 lines to 950. CI builds
  against Aether v0.768.0.
