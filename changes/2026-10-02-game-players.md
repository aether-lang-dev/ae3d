### A game's own player in the network session (#531)

- `set_player_object_maker`, `set_player_mover`, `command_axis`,
  `command_bits` and `player_command`: a game's players carry the game's own
  command, moved by its own mover on the host and in the client's prediction,
  reconciled through its own save and restore. The character controller is
  the default of all of them, so `set_player_maker` and `player_input` are as
  they were.
- A command with an action set carries the tick the client's view had
  reached (`seen_tick`), for the host to resolve it where it was aimed (#499).
- After every command a player's state is rounded through the mover to the
  32-bit floats the snapshot carries, on both sides -- for the controller its
  fall and footing too, which only its place was before.
- The command's fields are coded alike, each as its change less the change
  before; a controller's input costs 0.85 KB a second where it cost 0.78, the
  jump now a field of its own rather than a bit on the walk.
