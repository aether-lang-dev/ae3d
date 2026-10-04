### Motion matching: 2,000 figures within a millisecond, measured

`benchmarks/bench_motion_matching.ae` adds a benchmark for two of #509's
done-when items. It uses the Fox fixture's Survey, Walk and Run, headless.

- **2,000 figures within 1 ms on the job system.** 2,000 matchers over one
  database each search once per frame. Each figure asks for its own way and
  pace, from standing to a run, and faces its own way. The fastest of 100
  frames:

  | | time for 2,000 searches |
  |---|---|
  | one thread | 5.5 ms |
  | the job system, 24 threads | 0.54 ms |

  The search reads the database and writes only its own matcher, so the
  matchers search in parallel as they are. On one thread the varied queries
  prune less than the single walking figure `test_matching` times (2,000 of
  its searches take 0.94 ms).
- **No leaks across 1,000 database builds and frees.** Each build takes
  1.4 ms. Every database is freed, and ci.sh's leak check on macOS holds the
  benchmark to leaving nothing behind at exit. On CI the benchmark runs
  `AE3D_BENCH_FRAMES` builds and frames, like the others.

`matching.build` now returns early on a clip count at or below zero, not
only at zero. Inlined into the benchmark, GCC could not rule out a negative
count reaching `calloc`, and warned (`-Walloc-size-larger-than`).
