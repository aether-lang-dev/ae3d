### Networked players meet alike on host and client in the street

- **`examples/net_street.ae` held again on a machine up for days**: no
  reconciliation moves a player (walkers were corrected up to 1.9 m since
  players became solid, 62def79f, #664) and every client sends under
  4 KB a second (a driver sent 5.2). Found by `./ci.sh` on an M6 up five
  days: the scenes run only on a developer's machine, and a CI runner's
  clock is minutes from its zero.
  - **The host's times go as 64-bit floats (protocol 8).** A snapshot's
    time, the previous tick's, a gone object's and a create's or destroy's
    were 32-bit floats of `platform.time()`, a monotonic clock counting from
    boot: five days on that is 31 ms coarse, so a client placed the others
    a step from where the host did. `tests/test_players.ae` runs its two
    players walking into each other at a clock of 0 and five days on: on
    main the second is corrected 13.7 mm (over its centimetre), here 0.
    Four bytes a snapshot; the budget counts them.
  - **A move meets only the players both sides hold alike.** Two players
    meet once both have been in the game a second (`MEET_AFTER`; a spawn
    carries the tick its player joined at): the host spawned a player on a
    walker and pushed it 0.37 m that its client never saw. A client keeps
    the times of the last 64 ticks it took a snapshot of, and takes a held
    walk's view a step on only onto one of them; a command whose view
    falls between two ticks the client does not both hold meets no one on
    either side (a lead of 0): a lost snapshot left a player's samples
    around the view not the host's, 4 to 30 cm off.
  - **A command's view and lead are a bit where they follow** from the
    command before's (input flag 4, a mask of its own), the first command's
    from the one before the message, with one input in eight giving its
    first its own; a host lacking that one keeps none that follow from it
    and asks once a later one comes. Driver 5.2 KB a second up, now 3.8 to
    4.0; a walker 2.6 to 3.0 (2.3 before players were solid); down at most
    10.9 KB in the second a client joins.
  - Measured on Aether 0.834.0, M6: net_street's sixteen players, ten
    seconds, `prediction_worst_um` 0 over every run, `commands_asked` 0;
    the thirteen net suites and test_players pass.
