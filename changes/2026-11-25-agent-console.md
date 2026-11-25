### The program's console on the agent channel (#510)

- `native/platform/console.c`, new: while the channel is open, stdout and
  stderr go through pipes. A reader thread for each stream passes every
  byte through to where it went before, and keeps the last 4,096 lines.
  Each line carries its frame (a marker the engine writes at each frame's
  end) and, for a script's line, its object (marks the behaviours write
  around each script phase that runs, buffered, with no system call each).
  At exit the streams are put back and drained, so a program's last lines
  reach the terminal. A crash puts them back before its stack trace, using
  only async-signal-safe calls. `AE3D_CONSOLE=0` turns it off.
- Agent ops: `log.tail [count]` and `log.since seq [count]`, 1,024 lines at
  most an answer, with `next`, `more` and `oldest`.
- `test_agent_console`, new, over a socket, 10 checks:
  - a script's line carries the frame it saw and its object;
  - the program's lines name no object;
  - stderr is kept;
  - since and count behave;
  - no marker in any line;
  - the verdict printed after the engine reaches stdout.
  Checked by hand: a program that aborts with capture on shows its last
  line and the stack trace.
- `docs/agent.md`, "The console" (generated around tools/agent_doc_text.md).
