### The local gate's two flakes (#547)

- The editor driver's script checks act on the cube, chosen and shown
  before anything is read. They acted on whatever the terrain section left
  selected: sometimes the terrain, where no script is offered, and the
  inspector was read mid-change. Main failed them three runs in three, the
  branch before this one run in two; now five in five pass on OpenGL, and
  Vulkan passes.
- A scene parity comparison that fails now says which scene went away --
  still running, or exited and with what status -- and its last lines,
  before the logs are deleted.
