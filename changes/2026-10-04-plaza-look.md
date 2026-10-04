### Motion: the plaza's walkers watch the car, their ragdolls built ahead

`tools/plaza_showcase.ae` (#509):

- **Ragdolls built at the start.** Every walker's active ragdoll is built
  when the plaza is, then parked; a strike unparks it and stands it on its
  rig.
  - Before, the ragdoll was built at the first strike, and that frame took
    65 ms with 200 walkers. The worst frame is now 23.6 ms, and the
    average is 6.9 ms at the 144 Hz vsync.
  - Building all 200 takes 2.9 s at the start.
- **Watching the car.** A walker within 10 m of the car as it crosses
  turns its head and neck to it (`ae3d.lookat`). With 200 walkers, 49
  were watching it at the end of the run.
- **Motion matching.** `AE3D_MATCHING=1` poses every walker by motion
  matching, each over a database of its own, since a database poses the
  figure it was built from.
  - With 24 walkers a stance slides 0.64 cm (34.7 cm at most), and the
    toe slides more than the ankle (0.39 cm). The foot turns while
    planted; that is still to fix.

`matching.find_feet` now returns early for no bones. GCC, inlining it into
the plaza, could not rule out a negative count reaching `calloc`, and
warned.
