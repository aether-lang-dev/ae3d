### Particles (#546)

- `ae3d.particles`: an emitter at a rate or in bursts, each particle thrown
  into a cone with a speed and a lifetime, under gravity and drag, landing on
  the static world (a ray along each step's move) or a ground height, with a
  callback where it lands and the surface's normal there -- the stain. Drawn
  as point-instanced billboards with a soft disc, sized from birth to death.
  Stepped on the fixed step with the emitter's own seeded generator: the
  same particles on every run.
- `physics.ray_static_hit` answers where a ray meets the static world and the
  surface's normal there.
- `tests/test_particles.ae`: a throw tops out where v^2/2g says (to 0.01%),
  drag lowers it, bursts land on a plane and on a box's top with the right
  normals, the lifetime, the rate, the cone, the capacity, and the seed.
