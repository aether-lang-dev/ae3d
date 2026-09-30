### Networking: what a client held (#513)

- `net.on_snapshot(session, hook, context)` tells a client's game of every
  snapshot it takes, after its fields are written and their hooks called;
  `net.fields_tick(session, id)` says which tick an object's held fields were
  sent at. What a debugger or a test lines a field's changes up against.
- `tests/test_net_fields.ae`: a hook is owed for every change a snapshot the
  client held brought, not for every change the host made. Under a burst of
  loss a client can miss every snapshot between two changes of a field, and
  a field is state: the first change folds into the second. Swept over
  15,000 seeds of the loopback's generator, five did that; the scene now runs
  under those five on the test's clock, the same run every time, beside the
  UDP run. A hook dropped where a held snapshot brought the change still
  fails the test (checked by dropping every 37th tick's hooks).
- Still open in #513: one macOS run held a tick without the change logged
  a tick before it, which no local run (250 over UDP, 15,000 over the
  loopback) has shown.
