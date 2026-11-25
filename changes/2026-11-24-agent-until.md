### The agent runs to a moment and watches the way there (#510)

- `ae3d.agentwatch`, new: expressions over a game's objects. A field of a
  component is read by object name, quoted name or `#id`, then kind and
  field, quoted where a name has a space. Expressions can also read
  `position` and its axes, numbers, `true`, `false` and `frame`, combined
  with `+ - * /`, comparisons, `&& || !` and parentheses. A path with
  nothing there is false, not 0. A malformed expression is refused,
  naming where and what was expected.
- Agent ops, new:
  - `object.find` (by part of a name, a tag, a component kind; 256 at
    most, with a count);
  - `frame.until expression [timeout]`, which runs until the expression
    holds, then holds at that frame and answers it, or times out with met
    false; nothing asked after it is answered before it;
  - `watch.add`, `watch.get` (1,024 samples an answer, with more/next),
    `watch.list` and `watch.remove`. A watch keeps the last 4,096 frames.
- `test_agentwatch`, new, headless, 19 checks: fields, quoting, ids,
  positions, precedence, missing paths, and errors with their columns.
- `test_agent_until`, new, over a real socket, 11 checks: object.find,
  until stopping at the first frame its condition holds and holding there,
  the watch's every frame on the way, a timeout, a malformed expression,
  removal.
- `docs/agent.md`: the ops (generated), and "Running to a moment, and
  watching the way there".
