### Physics and walks made visible to the agent (#510)

- Agent ops from `ae3d.physics`:
  - `physics.bodies [region]`: each rigid body's object, kind, position,
    velocity, whether it is awake, its mass and colliders;
  - `physics.contacts [object]`: each touching pair once, with its point,
    normal, depth and the step's impulse;
  - `physics.ray origin direction [reach]`: the first thing met, static
    included, with its distance, point, normal and object.
  All three answer at most 256 entries, with a count and `more`.
- `nav.flow_path(field, from, to)`, new: an A* walk between any two places,
  by the flood's own step rule and prices, its corners string-pulled. It
  reads the field and leaves the walkers' target and ways alone.
- `ae3d.navagent`, new: `expose(field, name)` puts a game's field on the
  channel for `nav.fields` and `nav.path`. ae3d.nav stays free of the
  channel and the renderers it imports.
- `test_nav`:
  - the walk through a wall's gap;
  - an open walk's cost equal to the octile's;
  - ends in a wall or walled in;
  - the field's own costs and ways untouched.
- `test_agent_world`, new, over a socket, 11 checks:
  - the bodies and their kinds, and a region filter;
  - the crate's contact with the ground, reported once and pressed;
  - rays onto the crate and onto the ground;
  - a ray with no direction refused;
  - nav.fields and nav.path through the gap, and into the wall.
- `docs/agent.md` (generated) and `docs/crowds.md`, "A walk between two places".
