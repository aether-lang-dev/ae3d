# Held item kinds

What `ae3d.items` reads (#925): each a kind of thing a figure holds by its
handle. Lengths are metres and masses kilograms, from real ones; every
point is in the item's own frame, its handle along +y from the butt (or
the pommel) at the origin, its front (the edge's way, the muzzle's) +z.

| file | what | length | mass |
|---|---|---|---|
| `knife.item` | a kitchen knife: a 11 cm handle, a 15 cm blade | 0.26 | 0.15 |
| `sword.item` | an arming sword, one-handed: a 10 cm grip, a 76 cm blade | 0.93 | 1.1 |
| `longsword.item` | a longsword, two-handed: a 26 cm grip, a 94 cm blade | 1.22 | 1.5 |
| `axe.item` | a felling axe, two-handed: a 90 cm haft, a 2.2 kg head | 0.91 | 3.2 |
| `bat.item` | a baseball bat, two-handed | 0.84 | 0.9 |
| `pistol.item` | a 9 mm pistol, its grip raked 18 degrees, a trigger | 0.19 | 0.85 |
| `rifle.item` | an assault rifle: a pistol grip, a fore-end for the other hand, a trigger | 0.95 | 3.6 |

A kind declares:
- `mass`, and `centre` (of mass);
- `handle <from> <to> <radius>`: the part a hand closes round, a segment;
- `front <x y z>`: the way the fingers' knuckles face holding it;
- `grip main <from> <to>` and `grip off <from> <to>`: where along the
  handle (0 its from end, 1 its to end) the main hand's middle goes, and
  the stretch the second hand is free to slide along; a `grip off` on
  another part with its own `radius`, `segment <a> <b>` and `front` (the
  way that hand's knuckles face: a rifle's fore-end, held from under it);
- `trigger <x y z>`, for the index;
- `edge <from> <to>`: a blade's edge or a club's striking face;
- `socket <name> <joint> <offset> <up> <front>`: where it is carried, by a
  joint named as UE5's mannequin names it, offset from the joint and turned
  in the body's frame (x to its left, y up, z ahead), its handle along `up`
  and its front along `front`;
- `swing <animation>`: a take that swings it (its strike where the main
  hand goes fastest).
