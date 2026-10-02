### A body lives and dies with its object (#549)

- The Rigidbody component has a destroy hook: destroying the object
  (`engine.destroy`) or taking the component off destroys its body -- its
  shapes, contacts and joints with it -- takes the record out of the
  physics, and releases the hulls and meshes its shapes were made from
  where no other body's shape holds them. The body stayed in the world,
  colliding where the object had been, and every fixed step wrote its
  transform into the freed object: a crash right after a crate was
  destroyed from a fixed update.
- `physics.rigidbody_remove(o)` takes the body off and keeps the object;
  `physics.collider_remove(o, shape)` takes one shape off, the body's mass
  following. `physics.body_count`, `shape_count` and `rigidbody_count` say
  what the world holds.
- Hulls and meshes are a body's now, not the world's until it is freed: an
  object made and destroyed over and over leaked one each time.
- `tests/test_physics_lifetime.ae`: a thousand crates of four collider
  kinds, hulls shared between them, made and destroyed over 153 frames
  leave the world with the bodies and shapes it had; a crate destroyed
  from a fixed update, then 120 steps; the body taken off an object kept;
  one collider of two taken off.
