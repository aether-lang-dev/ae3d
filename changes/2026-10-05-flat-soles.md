### Physics: feet that do not roll like logs

A ragdoll's foot is a capsule lying heel to toe. Its rolling resistance was
the reference's 0.1 of its radius, a 7 mm lever, so a foot pushed sideways
rolled under the figure. `physics.flat_soles` gives each foot a rolling
resistance of its whole radius (`FOOT_ROLL`), about half a sole's width,
when a ragdoll is made or refitted.

Measured on the box man, shoved from the side (`build/scratch/side_probe.ae`,
feet traced at the middle of the foot capsule):

| shove | feet slid before | after | steps before | after |
|---|---|---|---|---|
| 0.6 m/s | 0.23 m | 0.05 m | 0 | 0 |
| 1.0 m/s | 0.77 m | 0.46 m | 5 | 3 |
| 1.2 m/s | 1.34 m | 0.52 m | 5 | 3 |
| 1.4 m/s | 1.23 m | 0.50 m | 8 | 4 |

The face-down writher no longer pushes itself along the ground: 0.03 m
over two seconds, where it was 0.39 m. The knee-led face-down writhe that
worked around that is gone.

Feet that hold also hold more. Standing still, the figure now takes
1.0 m/s from behind and 0.8 from the side and from in front. Stepping, it
catches 1.3 from behind and 1.6 from the side. The suites follow:

- `test_balance` sweeps 0.6 to 1.3 m/s from behind and pushes 1.0 and
  1.2 from the side. Its push from in front is 1.0, which the step back
  does not yet catch (#606).
- `test_stagger` shoves with `motion.shove`: 1.4 m/s from behind, 1.8 past
  what the steps catch, and 1.2 to 1.6 from the side.
- **Step back.** It now waits until the capture point leaves the feet by
  0.45 m (it was 0.35). At 0.35 the figure fell stepping back from a push
  it stood without a step.
- **Stagger lean.** A stagger falls only past 0.7 rad (it was 0.6). The
  body pitches further over feet that hold, and a forward stagger the
  figure stood out of flicked its protective fall on and off.
