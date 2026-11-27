# Engine and game

The engine gives generic ways to animate a figure, hold things, take blows and get up; what they mean in a game is the game's. This page draws the line, and shows it with how the first game on ae3d, Siltreach, uses each layer. Siltreach's uses are described by what they ask of the engine, not by its design.

## The rule

- **The engine decides how a body moves**: how a clip is played, blended and carried onto a rig; where a foot goes on the ground; how far a joint bends; how a ragdoll follows a pose and falls; what a peer is sent. These are the same for every game and are held to numbers in the suites.
- **The game decides what the body is asked to do**: when to walk and how fast, what to look at, which blow lands where and how hard, when a figure dies, which takes are its people's, what a slot or an item is for.
- **A defect is fixed where it lives.** A game that works around an engine defect (clamping an arm after every step, nudging a capsule after a get-up) hides it from every other game and from the suites. Siltreach files the defect upstream with the numbers it saw; the engine fixes it and its suite holds the fix. `ae3d.motion`'s `set_part_strength` exists because a game had been clamping a crippled arm after every step (#573).
- **The engine is not shaped after one game's calls.** A game's request is fitted into the layer it belongs to, the way UE5 and Unity would offer it, measured; a request that only one game's design needs stays in the game.

## Who owns what

| | the engine | the game |
|---|---|---|
| takes | reading, retargeting, contacts, root motion, compression; the gaits' roles (`character.gaits`) | which captures and files its people use; a style's own stop or start (`gaits_set`, `gaits_add_stop`) |
| locomotion | the mover's springs, distance-matched starts and stops, the 2D blend, turning on the spot, feet on any ground | the velocity and facing each frame (`character.move`), where to go (`character.use`), how fast |
| the graph | states, blends, transitions, layers, aims, matching, graph files | the graph file, its parameters, its triggers (`animator.set_float`, `trigger`) |
| looking and aiming | the turn shared over head and spine within limits, the aim offset, hands on grips | what to look at and aim at, and when (`character.look`, `aim`) |
| items | grips, handles and triggers, held on a joint; weight leaning the trunk and slowing the pace (`ikrig.hands_load`, `character.laden_pace`) | what an item is and does |
| blows | a hit's chain let go by its newton seconds, a shove's stagger, a knockdown's protective fall, a death's ragdoll (`character.hit`, `shove`, `knock`, `die`) | which blow, where and how hard; what it costs in game terms |
| getting up | choosing the get-up by how the body lies, laying it onto the body, waiting for room, pairs not drawn inside each other | which get-up takes its people have (`get_up_add`), and when to call `get_up` |
| the network | inputs, events, states, snapshots, late joins, corrections | which peer owns which figure; the session |
| cost | the job pool, the LOD budget, banks for crowds | how many figures, and the budget's milliseconds |

## Siltreach's uses, as examples

What Siltreach asks of the engine, as its issues on ae3d have put it:

- **A camp of people on shared takes.** Twenty settlers on the same figure file and gaits. The engine made each character read and retarget every capture once per character until #944 shared the takes per file; the game changed nothing.
- **People at the game's scale.** Its figures are scaled to 1.75 m. Made at the file's size and scaled after, a figure kept a capsule and strides for the size it was made at (#943); `character.humanoid(..., scale)` makes every layer at the asked size.
- **Sitting, holding and eating.** A settler sits on a log, holds a bowl by its grips in both hands and eats from it. The seat, the bowl's grips and the bite are generic: a usable's slot (`ae3d.usable`) and an item's handles (`ae3d.items`). Palms off the bowl's grips were measured by the game and reported (#858: 0.41 m, then 0.215, then 0.078 m against a 3 cm bound by 2026-11-02, fixed in the engine's physical animation).
- **Walking to a spot.** A settler sent to a slot to sit, work or stand guard is `character.use` with the slot's stand point: it walks there, stops on the point facing the slot's way, its feet turned in steps (#949, #825).
- **Fights.** Blows land with a cost the game chooses: `character.hit` takes a share of the struck body's muscle by the blow's newton seconds; a punch to the head moves it hard and should cost little. What a fight is (who strikes, when, combos, damage) is the game's; how a body takes a blow is the engine's.
- **Knockdowns and get-ups among others.** Two figures knocked down side by side get up without being drawn inside each other (#835); the waiting and the order are the engine's, so every game gets them.
- **Its own scorecard.** The game measures what a player sees with the engine's meters (`ae3d.metrics`), not copies of them, and files what it finds with those numbers ([measuring.md](measuring.md)).

## What a game should not do

- Write a figure's joints. The animator is the one writer; a game drives parameters, layers and IK goals, and a step after the graph (`animator.add_post`) for anything drawn on top.
- Move a figure's object while its character moves it. Ask the mover (`character.move`, `mover.ask`) or let root motion move it.
- Keep a second copy of a meter, a foot rule or a bound. Use `ae3d.metrics` and the module's constants.
- Hold an engine pointer past the call that frees it: a character before its gaits, an animator before its takes' last user.
