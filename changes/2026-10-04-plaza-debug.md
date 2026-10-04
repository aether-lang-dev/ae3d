### Motion: the plaza's motion drawn on demand, and matching after a fall

`tools/plaza_showcase.ae` (#509):

- **F1 shows what each walker's motion is made of** (`AE3D_DEBUG=1` from
  the start). Drawn over every walker:
  - each foot's target where `ae3d.feet` puts it, on the ground under it:
    green while the foot is held, red while it swings;
  - where its body will be a second on, from locomotion's velocity, in
    blue.
- **Matching after a fall.** Locomotion taken up again by motion matching
  (`set_paused(l, false)`) now has its matcher search afresh.
  - The frame the matcher was playing when the walker was struck is not
    where the figure's clip is once a ragdoll and its get-up have had it.
    Followed on from that frame, it blended from a pose not on the screen,
    and a planted foot turned under the walker.
  - With 24 matched walkers and the car crossing:

    | | before | now |
    |---|---|---|
    | toe slide per stance, mean | 0.44 cm | 0.26 cm |
    | struck walkers' stances over 1 cm | 21 | 12 |
    | struck walkers' toes 3 cm or more past the ankle | 14 | 6 |
