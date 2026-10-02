### The shadow stage split, and a crowd left out of the lamps' faces where the frame traces (#498)

- The Vulkan frame is timed by ten stamps, not eight. The shadow stage is now
  split into the crowds' sorts, the rays' structure and the maps
  (`perf stages ... sorts= rays= maps=`, and the agent's `frame.stats`).
- That split found zombie_city's shadow work: 0.03 ms of sorts and 0.2 ms
  of structure build, and 9 to 13 ms of maps, from the horde drawn into
  every face of every lamp.
- Where the frame traces, a lamp's faces leave the crowd out. Within the
  shadow distance the shader takes the ray, which holds the crowd; past it
  a crowd casts nothing, as it casts nothing past it from the moon.
- At 20,000 figures and the default band, the shadow stage falls from 9.6
  to 0.4 ms and the frame rate from 32.9 to 48.1 fps. The frame drawn is
  unchanged to within run-to-run noise.

### A fall caught on the hands and knees keeps its balance (#479)

- A caught figure holds its shape at full strength and now keeps its
  balance too. With the balance let go it slumped onto its face and took
  three seconds more to settle. It counts as caught after a third of a
  second still, where it took half.
- Forward fallers lying still within 3 s of landing: 28 of 30, up from 21.
  Their heads never touch the ground.
