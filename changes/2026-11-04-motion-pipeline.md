### The animation pipeline: people, physical animation, items and the ground (#853, #921)

- **A person in one call** (`ae3d.character`, #903). `character.humanoid`
  builds a figure on a mover, a capsule, feet, a look and an aim, on
  100STYLE-style gaits:
  - matched stop and start entries (a stop slid a planted toe 472 mm, now
    2.9);
  - motion warping with the pelvis lifted for a seat's height and the feet
    raised with it, and a hand's slot reached by the whole body;
  - stands cut from a capture's calmest stretch.
  - `character.graphed` puts it on a graph file instead, `character.match_add`
    on a motion-matching database of whole captures (it walks, stands and
    strafes, toes skating under 0.01 mm). `character.hit` gives it a flinch
    for the part struck.
  - In a world with physics it moves by its capsule: turned on the spot in
    20 degree steps, and up and down 0.2 m stairs and a 20 degree ramp,
    toes under 5 mm.
  - `examples/people` is the README's example; every showcase figure is a
    person now.
- **Physical animation body by body** (`ae3d.physanim`, #858).
  - Each body is kinematic, driven at a strength, or simulated, with a weight
    per body and named profiles read from a file (Unreal's physical
    animation profiles, PuppetMaster's pin weights). At weight 0 a body is
    drawn as the animation has it, within 1e-6 of a twin with none.
  - A walker struck in the chest at 40 N s keeps walking where its twin
    walks (0 mm), the chest 14 degrees off at most and back.
  - The fixed step runs scripts, then animation, then physics (#845).
  - Hips and legs are kinematic: driven, the legs met the floor in 60 to 72%
    of a walk's frames, now 0.000005 mm off the pose.
- **Usable objects** (`ae3d.usable`, #908): kinds as data files; slots
  found by where and tag over a grid, and held by one figure at a time.
  2,000 searches over 1,000 objects take 5.4 ms and give brute force's
  answer every time.
- **Weapons and tools by their handles** (`ae3d.items`, #925): seven kinds
  as data.
  - Drawn from the hip and sheathed with the hand on the handle at the
    contact, with no jump; every finger closed onto the handle.
  - A two-handed axe fitted along the take's two palms.
  - The edge swept for hits in 17 microseconds a swing; a 3.2 kg axe swings
    at 0.76 of the take's pace against a knife's 1.25.
- **Motion matching** (#906): an exact box search over a style's whole
  takes. 65,075 frames take 0.049 ms a search against brute force's 0.35,
  the same frame on all 840.
- **Graphs as data files** (`ae3d.animgraph`): a file's graph is driven like
  the same graph built by calls, every joint within 5e-8 rad for 8 s.
- **Inertialized from the speed it had.**
- **CMU's ASF/AMC read beside BVH** (#912): every bone within 0.0004
  degrees of the BVH conversion.
- **The feet** (#926, #934):
  - Stops keep the planted foot planted. A toe pushing off is held through
    a blend (a sprint at 8.5 m/s slid one 18 mm, now 0.09), and a foot set
    down toe first is held on its toe.
  - The ground probe passes surfaces steeper than 50 degrees
    (`physics.ray_static_ground`).
  - A foot in the air keeps its lowest sole 15 mm over the ground once its
    toe goes 1.5 m/s (it went 0 mm over it, and Siltreach's run stop swung a
    toe 0 to 4 mm over the floor at 3 to 4.6 m/s).
- **Hands, looks and aims** (#931):
  - Palms on a held thing, on a figure with fingers and on one whose motion
    made its own bodies.
  - A look turns and nods within a neck's limits and lets go behind.
  - Fingers a capture lacks rest relaxed, and the pistol aimers hold their
    pistols by the grip.
  - No arm pop as a figure sits or takes a bowl: a straight limb's pole is
    read off its hinge.
- **ae3d.motion's figures** (#928):
  - A figure given a motion stays where it stands, drawn exactly as an
    undressed twin.
  - A POWERED figure is handed back facing as its bodies do, for as long as
    its largest turn needs.
- **The meter** (`ae3d.metrics`, #927, #926):
  - A foot gliding with the figure skates: a walker carried 13 m read 0 mm.
  - A stance ends at lift-off.
  - The ground is read as the feet read it, and a sole inside a solid by
    `physics.static_depth`. Under a plate tilted 60 degrees over the track
    it reads 0 mm, where it read 594 mm.

### A foot under something stands on what is under it (#934)

- **`physics.ground_below`** reads the ground from just under whatever hangs
  over a foot with room for one under it (5 cm), not from 0.6 m over it.
  - A figure stood with its heels under a bench's edge stood with its heels
    on the bench, 45 cm up, and its leg turned 74 rad/s walking off. Now
    its heels are on the floor and its fastest joint is 29.4 rad/s, as off
    the open floor (`tests/test_feet_overhang`).
  - A foot come into a solid from under it (a heel risen into a bench or a
    log's rounded flank) stands on what is under it.
  - One pressed into a solid from over it, or inside one resting on the
    ground (a ramp, a tread, a block set under a foot), stands on its top
    as before.
  - test_humanoid's stairs and ramp read as before.
  - A point is in a solid only 1 mm or more under its surface. A heel
    standing on the floor had read 600 mm into it.

### Characters a game can drive (#940, #942, #944, #949)

- **`character.physical(c)`** puts a figure's bodies on at once, not at its
  first blow: unhurt, it had none, and ae3d.items' edge passed through it.
  test_items: a person standing where a sword's edge passes is hit once
  physical.
- **`character.pause(c)` and `resume(c, at, facing)`**: held by something
  else, the character leaves its object, mover and capsule alone, and is
  put where the body was left on resuming. A paused character asked to walk
  moves 0 mm (it walked on under the body before).
- **Takes shared** by every character of one figure on one set of gaits,
  made once and kept by the gaits: 20 mannequins, the first made in 227 ms
  and the others in 72 ms each, all walking alike within 6e-8 rad.
- **A slot that names no takes** is held as it is reached, facing its way,
  until the figure leaves (it was refused).
