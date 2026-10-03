### Motion: matching, looking, knees with a person's range, a figure on its clip

- Motion matching (`ae3d.matching`, #586).
  - It builds a database from a figure's clips: the feet, the hips and the path ahead. A trajectory spring moves the body, and the search plays the best moment through an inertialized change.
  - `figure.play_blended_at` is new: it enters a clip at a given time.
  - On the Fox the foot on the ground drifts 0.06% of the body's way walking and 2.7% running.
  - The search uses bounding boxes over runs of frames and an early out (#588). It finds the same frame as brute force, and 2,000 searches take 0.83 ms against 7.8.
- A head that looks at a point (`ae3d.lookat`, #587).
  - The turn is held within 80 degrees either side and 57 up or down, and eased by a critically damped spring. The neck takes 40% of it and the head the rest.
  - On the box man it faces a point to 2.8 degrees, holds at its limit, and is back on its clip when cleared.
- A figure following its clip is on it (#584). The joints' springs now pull toward the clip's pose with the anchors; they used to pull toward the reference pose against them.
  - An arm held up ahead sits 0.059 rad from its anchor (0.14 before).
  - An arm taken back from limp settles 0.11 rad short of its clip (0.25 before).
- Knees bend 2.3 rad from straight and no further than straight (#578); the reference ragdoll's bent 60 degrees. The bones' limits match, so `ae3d.motion` keeps its aims within them.
- A side shove is stepped out of (#481): a step counts as backwards only when the capture point is mostly behind the rear foot. 210 N·s from the side now stands after 2 steps; before, it took 1 step and fell.
- Writhing holds however a figure lands (#480). Sixteen shoves from eight directions all land and writhe in place: the hip swings at least 0.30 rad and the pelvis drifts at most 7 cm.
