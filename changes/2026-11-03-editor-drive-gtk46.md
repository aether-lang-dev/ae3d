### The editor drive passes on Ubuntu 22.04 (GTK 4.6.9), and checks its layout for real

- Seven drive checks failed on 22.04, arm64 and x86_64 alike (#885). None
  was GTK 4.6 against 4.14: the two layout checks fail the same way on
  GTK 4.24, and the other five pass on GTK 4.6.9 once the scripts exist.
- Five were scripts that were never built. The editor opens
  `build/scripts/<name>` once, when it starts, and only ci.sh built the
  scripts first. The drive now builds any script whose library is missing
  or older than its source, and fails, naming the script, when one does
  not build. The five checks: choosing a behaviour, Simulate, orbit's
  centre row, and the scene recording a script and giving it back.
- Two were aether-ui's GTK backend reporting a widget with edge insets
  shifted left and up by its own inset and that much too large
  (aether-ui 58e9fa15). The pinned aether-ui laid out no headless window
  and reported every box as 0 x 0, so the checks had passed without
  measuring anything. The pin moves to that commit.
- With real geometry, the editor's inner divider turned out to be placed
  from the 1480 px window it asks for, not the window it gets. Xvfb's
  1280 px window left the inspector 180 px of its 360. The divider now
  goes 360 px from the far end of the splitter the window actually gave
  it. The colour picker's "laid out across the panel" check runs on Linux
  as a check again, not as a note (#412).
