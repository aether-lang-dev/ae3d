### Motion: a fall's order of contacts, held

`test_falls` now records the first step at which each part of a falling
figure reaches the ground (#578):
- the knees (a thigh's low end);
- the hands (a forearm);
- the hips (the pelvis);
- the head.

Over the 30 protected falls each way:

| way | first down | a hand before the head | the unprotected twin |
|---|---|---|---|
| over backwards | hands in all 30 (the head never lands) | 30 | 10 |
| forwards | knees in all 30, a hand next in all 30 | 30 | 19 |
| sideways | hands in 20, knees in 10 | 30 | 30 |

Forwards, it comes down in stages, knees then hands, not as a plank.

The test now checks, with a margin of one fall:
- every way, a hand is down before the head in at least 29;
- forwards, the knees are down first and then the hands, in at least 29.

21 checks pass.

With this, every item #578 listed is covered:
- the knees give (#585);
- crossing side steps (#481);
- the step back after a weight shift, held by `test_balance`;
- the joint limits, measured and ruled out;
- the order of contacts, in this change.
