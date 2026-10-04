### Motion: a side shove caught by a crossing step

- Shoved from the side, a figure now crosses its far foot in front of the
  near one, and the near one steps out after it (#481). The near foot
  carries the shove's load, so it can't be lifted. On soles that grip it
  moved 9 cm of a 50 cm step, and the figure fell from 220 N s.
- The foot that steps is now the one further from the capture point, the
  same rule as forward steps. The crossing foot lands 15 cm ahead so the
  shins pass. It crosses only when the figure is going well sideways (twice
  as much as forwards), because the IK rig stands turned on its stride and
  read a shove from behind as sideways.
- A POWERED figure's legs pass each other below the thighs too: the shins,
  and each thigh against the other's shin (`physics.ragdoll_cross_legs`).
  Held off by the shin it passed, the crossing foot was lifted but never
  moved.
- From the side, stepping holds 240 N s, up from 200. Falls are softer too:
  sideways the protected head meets the ground at 0.58 m/s, down from 1.27;
  forwards at 1.71, down from 1.96.
- Stepping now catches some forward shoves up to 335 N s, so `test_falls`
  shoves 345–395 forwards to keep every pair falling. `test_balance` holds
  the side case at 240.
