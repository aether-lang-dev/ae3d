### The runners compile only what changed (#511)

- `build.sh` compiles each file of a program to an object, then links, and
  runs `AE3D_CC_LAUNCHER` in front of every compile. The runners set it to
  `ccache`, with its directory kept between runs: a suite whose imports a
  change did not touch generates the same C byte for byte, and its object
  comes back at once. A second build of `test_net` took 5.9 s where the
  first took 19.6. Compiling is most of a run: 821 of the Linux leg's 1,136
  seconds of test suites were builds.
- The editor draws its viewport at half size on a runner
  (`AE3D_RENDER_SCALE`, which the editor now honours as a program does):
  its frame there was 600 to 850 ms of shadows and scene in software. The
  driver's 166 checks pass at half size.
