# ae3d documentation

The engine's documentation, one page a subject, each written to be read
on its own and each holding to the same rule as the code: a claim is a
number, a command or a file the reader can check. The [README](../README.md)
at the root is the front page; this is the map.

## Reading order

| Page | What it answers |
|---|---|
| [Architecture](architecture.md) | How the engine is put together: the modules, the frame, the two renderers, the job pool, what is still C and why |
| [Building](building.md) | Toolchain, dependencies per platform, `build.sh`, `ci.sh`, the editor's build, the shader generator, the environment variables every program honours |
| [Rendering](rendering.md) | Every rendering feature, with the reasoning and the measurement behind each: shading, shadows, ray queries, DLSS, impostors, the crowd sorted on the device |
| [Physics](physics.md) | `ae3d.physics` over aephysics: rigidbodies, colliders, ragdolls, vehicles, hit events; the four reference scenes and the driven street |
| [Crowds and navigation](crowds.md) | Pose banks, the horde's kernels, the flow field, the ECS, the job pool the simulation runs on |
| [The asset pipeline](pipeline.md) | Blender to engine: the exporter, the manifest, the critique, glTF from anywhere |
| [The agent channel](agent.md) | The JSON channel a program, a test or an AI agent drives a running scene through |
| [Audio](audio.md) | `ae3d.audio`: sources on game objects, the listener, distance, pan and Doppler, buses and ducking, held to numbers through a headless mix |
| [Motion](motion/README.md) | How a figure moves, layer by layer (#853, #1027): [getting a figure moving](motion/getting-started.md), [clips and retargeting](motion/clips.md), [the animator and its graph](motion/animator.md), [IK](motion/ikrig.md), [the mover and the character](motion/character.md), [physical animation](motion/physical.md), [networking motion](motion/networking.md), [performance](motion/performance.md), [measuring motion](motion/measuring.md), [engine and game](motion/engine-and-game.md); every example built by `ci.sh` |
| [Networking](networking.md) | `ae3d.net`: a host and its clients, the transports (loopback with simulated conditions, TCP), replication and interpolation, and the numbers they are held to |
| [Components](components.md) | Game objects as their components, the scene as an object: the registry of kinds the inspector, the scene file and the agent read, and the engine's own kinds |
| [Scenes in code](scenes-in-code.md) | `ae3d.scenedsl`: a scene written as nested builders, nesting the hierarchy; placing it; the editor writing every saved scene as that code, and the test that holds code and file to one scene |
| [Props placed by rule](scatter.md) | `ae3d.scatter` (#918): a district's props from tagged areas, roads, places kept clear and palettes, the same from a seed on every machine; one instanced model per prop; the scatter file; what it costs |
| [Streaming a world](streaming.md) | `ae3d.worldbake` and `ae3d.stream` (#917): a world cut into cells and their far stand-ins, the cells loaded on workers around the camera and the players and let go behind them, a cell's states, its budget, what it holds, and the `stream.cells` op |
| [The editor](editor.md) | The scene editor: panels, controls, undo, scene files, how the viewport is drawn |
| [The game UI layer](ui.md) | Text and screen-space UI for a game: the TrueType reader, the distance-field glyph atlas, layout, and what they are held to |
| [Performance](performance.md) | How a frame is measured, and where the frames are on the machine the numbers were taken on |
| [Testing and verification](testing.md) | The suites, the benchmarks, the critique, the frame budget, and how a scene is verified by number rather than by eye |
| [Saving and loading](persistence.md) | `ae3d.persist`: save slots with pictures, saved off the frame; a system's own state (the bodies' motion); checkpoints and roll back; versions and migrations; what each costs |
| [Scripting](scripting.md) | A game's scripts: from an empty folder (`tools/new_game`) to a moving, tunable object; a struct's derived schema as its fields, the phases, collisions and triggers, building, the layout check, hot reload |
| [Writing Aether in this engine](writing-aether.md) | The conventions and the language's edges the engine is written around |
| [The black hole](black-hole.md) | A worked example: Kerr geodesics per pixel, and what checking them taught the engine |

## Where things are

```
src/ae3d/     the engine, one module a directory (docs: architecture.md)
native/       the C that remains, by role: gpu/, image/, platform/, dlss/ (native/README.md)
deps/         aephysics, the physics engine, as a submodule
examples/     runnable scenes; examples/lib/ what they share
tests/        one program a suite, each printing its own verdict
benchmarks/   per-frame cost measured without a window
tools/        the agent client, the viewer, the critique, the bench, the bakers
scripts/      export, critique, perf, the build's platform and native halves
editor/       the scene editor
docs/         this
docs/images/  the pictures the pages and the README show
```

## Conventions

Every page states what a thing costs where a cost was measured, names the
machine, and quotes pairs taken in the same run. A feature that is not
measured is described as such. Numbers older than the code they describe
are dated.
