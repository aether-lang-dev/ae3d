### Plaza: a body the car throws meets the walkers near it

Walkers' ragdolls stay parked until the car strikes them: every walker's
bodies in the world cost 65 ms a frame at 200. So a body the car threw
passed through anyone in its way (#648).

- **Woken near the action.** A walker within 2 m of a struck body still
  moving gets its bodies, following its clip, so a thrown body meets it.
  After a second with none within 3 m, it is parked again.
- **Struck in turn.** A woken walker that a thrown body meets at 1.5 m/s
  or more is struck too: handed to its ragdoll, feeling the blow where
  they met. It does not walk on through the body that hit it.

In the plaza showcase over 60 s with 20, 24 and 28 walkers:

| | Before | Now |
|---|---|---|
| Thrown bodies through walkers | 6.8 s | 4.0 s |
| Walkers woken | none | 228 |
| Walkers knocked down by a thrown body | none | 21 |
| Struck walkers walking again | 44 of 53 | 68 of 75 |

The frame is unchanged at 6.94 ms. The report adds these lines.
