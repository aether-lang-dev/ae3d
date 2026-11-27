### Starts that keep their pace (#937)

- **A start counted from its move-off** (`animator.clock_from`). A take
  played by the distance come counts that distance from the time given, not
  from its first frame: the people's StartStop start stands 0.3 s before it
  moves off, and counted from its first frame its stand was raced through in
  a frame or two. A transition matching its feet never enters it before then.
- **The figure sets off at its start's pace** (`mover.set_start_pace`,
  `animator.clock_pace`, `clips.speed_at`), as it stops at its stop's: no
  faster than 1.25 times the start take's own speed where it is, as UE5's
  distance matching clamps a start's play rate. On the springs alone the
  figure outran the take from its move-off and its clock ran up to twice its
  pace.
- **A take that begins on the move** is read from where it first stands
  (`clips.moving_at`, each stand and move held 0.1 s): the StartStop start
  walks in, stands, and walks off at 1.55 s, and its "start" had been the
  slowing tail of the step before, which its clock raced through at up to 28
  times its pace.
- **A start ends at its first footfall once its walk-off is up to pace**
  (character `start_end`, within 90% of the fastest it goes): the StartStop
  start runs into its next stop after its 0.47 m/s peak, down to 0.14 m/s,
  and kept to its pace the figure slowed with it and handed over to its walk
  at 0.23 m/s; walking off a log, a toe skated 20.0 mm, now 0.63 mm.
- Set off from a stand at 1.2 and 2.6 m/s, ahead, to the sides and behind
  (test_humanoid): the fastest joint 196% of the takes' own plus the
  easing's, now 95%; a foot 116 mm past the hips' middle, now never. The
  plaza's three seeds at 60 Hz: feet crossing 112, 70 and 77 mm, now 1.0, 0
  and 2.6; the fastest joint 52 and 35 rad/s on seeds 0 and 2, now 21 and 19.
- **A foot caught again after a flicker keeps its heading** (ikrig), as it
  keeps its point: taken from the clip, a planted toe slid 14.4 mm as a
  get-up's stand eased in.
- **`physics.static_depth` of a point within its skin under a solid**: a heel
  0.9 mm under a bench's underside read 351 mm into the bench.
- **Toes on the ground are not in it** (ikrig `toes_flat`, within a
  micrometre): a foot standing flat has its toes on the ground to the last
  digit, and one 1e-16 m in it by the rounding of where the figure stood was
  bent 8.5e-5 rad (the bend's least), so twenty figures asked alike 2 m apart
  drew their balls that far apart; now within 5.2e-8 rad.
- **test_physanim reads the walk's own fastest over the frames it eases
  back in**, from its twin, not over the next second: by the stride phase the
  strike fell on, the next second's fastest was 11.9 to 14.5 rad/s and the
  bound failed at 7 of 61 phases before these starts, at 8 others with them;
  read over the same frames it holds at all 61 both ways (88% to 94%).
