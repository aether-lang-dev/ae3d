### Locomotion: it turns round before it walks off, and steps round on the spot

Fixes for the turn round (#611). Measured on the box man walking at
1 m/s and asked to go back the way it came.

- **No more moonwalking.** Asked to go behind it, a figure at full
  speed turned its 180 degrees while walking backwards at almost its
  full walk, its feet stepping the wrong way.
  - It now faces where it's asked to go, not the way it is still moving.
  - It goes that way only as fast as the cosine of the turn allows, and
    at 10% of its speed (`TURN_CRAWL`) past a quarter turn.
  - So it slows, turns, and walks off the way it faces.
  - The fastest it goes backwards in a turn round is now 0.098 m/s.
- **Stepping round on the spot.** Turning on the spot on the idle's one
  planted foot swung the body round that foot. The foot lock moved the
  body 2.5 cm further each frame until it reached its 0.5 m limit, and
  then the foot slid.
  - Turning on the spot now plays the walk at 0.8 of its pace
    (`TURN_STEP_PACE`), so it steps round.
- **Standing still holds its feet.** After a stop, the clip blending
  into its idle changed the lowest foot. No new foot was held, and the
  lock's offset, bled out while standing, slid the planted foot 3.5–5.5
  cm.
  - Standing still with nothing asked, the lowest foot is always held.
  - The offset waits there until the figure walks on.

On the box man, while turning round the planted toe slips:

| posed | before | now |
|---|---|---|
| by speed | 49–64% of the body's way | 41% |
| by matching | 67% | 25% |

Stopping, it slips nothing.

`test_locomotion` now asks that a turn round slips under 50% (it was
70%), and that it never goes backwards faster than `TURN_CRAWL` of its
walk. That makes 36 checks.

Still open: the lock offset left after a turn can only bleed out by
sliding the planted foot. Locomotion moves the hips, and the hips carry
both feet. Keeping that foot planted while the offset bleeds needs the
swing leg solved onto its place, which is what `ae3d.feet` does.
