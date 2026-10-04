### Tests: the light grid's build held to the machine it runs on

- The 256-lamp light grid build is now held to under 3 times the 64-lamp
  build in the same run, and under 5 ms (#604). It used to be held to
  2 ms flat. On a Linux runner slow throughout the test, even the fastest
  of twenty builds took 2.05 ms and failed a PR that didn't touch the
  grid. Here 256 lamps take 1.79 times 64's.
