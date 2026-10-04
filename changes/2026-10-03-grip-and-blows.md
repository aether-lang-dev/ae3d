### Motion: feet that grip, a blow sized to the speed it gives, a stagger that ends when it is caught

- `deps/aephysics` is at aephysics main (#583), so the feet grip
  (aephysics#59, the soles' friction was 0.1) and the shoulders reach wider
  (aephysics PR #60). The suites are retuned to what that physics holds:
  - The box man standing still holds 210 N s from behind.
  - Stepping, it staggers out of 300 (it used to manage 360) and falls at 330.
  - From the side, standing still holds 180 and stepping holds 195 (it used
    to hold 210).
  - Shoves from behind of 330–380 N s fell it forwards; the protected head
    is the slower in 27 falls of 30.
  - `build.sh` and the editor's build find aephysics's inline header.
- A blow costs the bone as much as the speed it gives it (#595), full at
  1.6 m/s. A tap on the hip used to take the pelvis's balance down to
  60 N m of 1200; now it leaves 1104. A tap before a 120 N s shove no longer
  fells the figure. The struck pelvis keeps half its balance, not none.
- The protective fall waits until 34 degrees in a stagger instead of 29. On
  the IK rig, the catch of 230 and 240 N s from behind leaned just past
  29 degrees. The fall cut the catching step short and the figure went
  down, where 220 and 250 stood. Now it stands every push from 200 to 280.
  The falls protect the head as before.
- A stagger ends once the capture point is over the feet again. The
  rocking on the feet that caught the figure is the balance's to hold. On
  the IK rig, 210 and 220 N s took three and four steps; now they take
  two. A shove of 250 still shuffles nine steps on the rig's stride
  (#598).
