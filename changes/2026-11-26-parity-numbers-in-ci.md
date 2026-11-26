### The backend parity suite's numbers in the CI log (#1101)

- A suite's lines beginning `ci: ` are printed by `ci.sh` under its name,
  passing or failing, in the suites and under the validation layer.
  `test_backend_parity` prints every frame comparison so, with its bound:
  "two lights" failed two runs in three on the Linux runner's llvmpipe with
  only its FAIL line in the log, which says nothing of by how much.
- A comparison that fails says where the frames differ: the differing
  pixels in each cell of the frame cut eight across and six down.
- "two lights" asks that the lamp reach the OpenGL frame as well as the
  Vulkan one. Measured on Mesa 26.1.8 (llvmpipe and lavapipe), the lamp
  adds 31 differing channels to the shadows case's 2149 of 147456, the
  same on main and the motion branch over four runs each, while its light
  changes about 15300 channels of either frame: a failure past the case's
  5% (7373) is a region lit differently on one side, not the shadow edge
  its comment allowed for, which went with the lamps' own maps (#490).
