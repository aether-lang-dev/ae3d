### Scripts rebuilt and reloaded over the agent channel (#510)

- `ae3d.script` keeps every script a program opens (`script_kind`), by
  name. `reload_named` opens the library again and swaps it under every
  object carrying it, keeping fields by name. `build_and_reload` builds
  the source first.
- The build's stdout and stderr both go to a log that is read back. A
  capture of stdout alone took a failed build, whose compiler talks on
  stderr, for one with nothing to say, and reported it reloaded.
- A source whose file name is not the library's is refused: it would build
  another library and reload the old one.
- Agent ops: `script.list`, `script.reload name [source]` and
  `script.errors`. `AE3D_SCRIPT_BUILD` names another build script.
- `test_agent_script`, new, over a socket, 10 checks: the script is
  listed, rebuilt from changed source and swapped. The console hears the
  new code with the game's field value kept. A broken source is refused
  with the compiler's words and v2 keeps running. A source of another
  name is refused.
- `docs/agent.md`, "Changing a script while the game runs".
