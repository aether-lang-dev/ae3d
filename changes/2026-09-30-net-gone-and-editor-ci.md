### A destroyed object goes on the snapshots' word, and its id is given again (#515, #500)

- **The snapshots say an object went.** The destroy message is reliable,
  and a lost one lands only with its resend: under 10% loss a client held an
  object for over a second after the host let it go (#515). Each destroyed
  object -- its time, its place, and its last fields where it had any -- is
  carried by every snapshot against a base older than the destroy, until each
  client has acknowledged a snapshot of that tick; the client lets it go on
  whichever word comes first, the same way. `hub_set_reliable_delay` holds the
  loopback's reliable parcels back to test it: a destroy a second late is let
  go 0.13 s after the host's, where it took 1.03 s.
- **Ids are given again** (#500), once every client has acknowledged a
  snapshot after the destroy, lowest first. A client stops carrying the old
  object's state forward past the snapshot that said it went, reads a record
  for the index after it as the new object's, and finishes an old object still
  leaving when the new one is created. Ten thousand objects created and
  destroyed one after another over 10% loss used 27 ids, every one reached the
  client and stayed where it was made there, and each was let go.
- `tests/test_net_events.ae` keeps its ledger by object life rather than id.

### The editor's CI step, cut (#511)

- GTK draws the editor's window through desktop GL on the Linux runner
  (`GDK_DEBUG=gl-prefer-gl`): Mesa's software GLES has no half-float vertex
  data, so GTK's GL renderer never started and cairo painted every frame on the
  CPU, 600 to 850 ms of it.
- A runner drives the editor on Vulkan, the default backend, alone; the local
  gate drives both.
