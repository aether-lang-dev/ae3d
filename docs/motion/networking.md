# Networking motion

A figure is not sent a pose at a time. Every peer runs the same character (its mover, animator, feet, look, aim and ragdoll) from the same inputs, so what crosses the wire is what the owner's game asked of it, as Unreal's character movement sends its moves and Unity's Netcode its input commands (`ae3d.netanim`, #911). The session underneath is `ae3d.net` ([networking.md](../networking.md)). The program is [`examples/docs/net_figure.ae`](../../examples/docs/net_figure.ae).

## A figure on two peers

Every side makes the same figures the same way and adds them to its `NetAnim` in the same order. The owner's side adds its figure as local (`true`); every other side adds the same figure as remote.

<!-- example: examples/docs/net_figure.ae#sessions -->
```aether
hub = net.hub_new()
host = net.host_loopback(hub)
net.hub_set_conditions(hub, 0.15, 0.03, 0.05)          // 150 ms latency, 30 ms jitter, 5% lost
nh = netanim.netanim_new(host)                         // every side, at the same point among its registrations
oe, oc = world(g)
owned = netanim.add(nh, oe, oc, true)                  // the host's own figure
```

The owner asks through `netanim` instead of the character (`move`, `look`, `look_ahead`, `look_free`, `aim`, `aim_off`, `keep_place`, and the events `hit`, `knock`, `get_up`, `act`, `die`), steps its engine, and closes the tick:

<!-- example: examples/docs/net_figure.ae#owner -->
```aether
ask(owned, t)                                  // as character.move, through netanim
engine.engine_update(oe, STEP)
netanim.sent(nh, now)                          // after the engine's step: the tick closed and streamed
```

A peer that joins late adds the same figure as remote; the owner sends it a snapshot, and it lays its figure at the snapshot's tick and plays on from the inputs streamed:

<!-- example: examples/docs/net_figure.ae#join -->
```aether
client = net.join_loopback(hub)
nc = netanim.netanim_new(client)
seen = netanim.add(nc, we, wc, false)          // the host's figure, laid from its snapshot
```

<!-- example: examples/docs/net_figure.ae#peer -->
```aether
while nc != null && netanim.due(nc, now) && netanim.playing(nc) + 1 < t {
    netanim.play(nc)                               // the next tick's inputs and events to its figures
    engine.engine_update(we, STEP)
    netanim.played(nc)                             // held to the owner's state at that tick
}
```

On 2026-11-19 at `bea4c991`, `examples/docs/net_figure.ae` (the mannequin standing, walking 1.2 m/s ahead, then to its side, then stopping; the client joining at tick 90 over 150 ms latency, 30 ms jitter and 5% loss): one snapshot taken, no tick played without its inputs, and the client's figure 0 mm from the host's at the end.

## What crosses

- **Inputs, quantised before the owner takes them.** Velocities to a millimetre a second, facings to a ten-thousandth, points to a millimetre, so the owner evaluates exactly what every peer does. Events go stamped with their tick, their numbers as 32-bit floats the owner takes rounded the same way.
- **A stream, not messages.** `net.send_stream` sends a block unreliably every 2 ticks (`SEND_EVERY`, 30 a second), each carrying the inputs of the last 12 ticks as runs (`CARRY`: a walk held is one run, two bytes) and every event of the last half second (`EVENT_CARRY`), so a lost block costs nothing while one of the next arrives in time.
- **Played behind, never guessed past a buffer.** A peer plays a tick at the owner's time of it over the link's fastest way plus a buffer (0.12 s by default, `BUFFER`: the jitter, the send interval and a lost block or two). A tick whose inputs never came is played with the last ones and counted (`ticks_missed`).
- **Drift found and eased out.** Twice a second (`STATE_EVERY` 30 ticks) a compact state: the object's place (a tenth of a millimetre), the mover's velocity and facing, the graph's state and its time in it, and each planted foot's lock. A peer compares it with what it had at that tick; past 2 mm (`CORRECT_ABOVE`), its place and facing are eased onto the owner's (a half-life of 0.1 s, at most 0.5 m/s: never snapped), its springs' velocity taken (`mover.correct`), and its graph played at the owner's state and time, inertialized over 0.2 s. A planted foot held elsewhere than the owner's is eased onto the owner's lock (a 0.03 s half-life).
- **A ragdoll as physics state.** While a figure is down, ten times a second (`RAGDOLL_EVERY` 6 ticks; once a second once a dead one rests) each body's place (a tenth of a millimetre about the first body) and turn (the three smallest components of its quaternion in 15 bits each). A body off by more than 1 mm is drawn onto the owner's over the next 6 ticks, at most 5 mm a tick, keeping its velocity, so nothing is thrown. While a body falls faster than 0.3 m/s its ragdoll goes every block.
- **A client's figure.** A figure can be a client's (`add_owned`); its blocks go to the host, which plays them as any peer does and relays them to every other client.

## What a snapshot holds

A snapshot is everything a figure is, sent reliably to a late joiner, and to a peer whose figure a state found parted (a resync): its object; the mover's state (`mover.state_write`); the character's (`character.state_write`: what it was asked, what it is doing, how it last steered); the animator's whole state with its feet, look, aims and springs (`animator.state_write`, [animator.md](animator.md#state)); physanim's (`physanim.state_write`); every body of the ragdoll, its drive powered or not with each joint's settings; and the ragdoll as its solver holds it (`physics.ragdoll_state_save`: anchors, joints' warm starts, contacts with their caches); its last inputs and the first event still to come. The graph, takes and rig are not in it: each peer builds them the same way.

Sizes measured on 2026-11-18 at `6f921c0c` (on this head; #997): 12.2 KB for a standing figure, 16.6 to 17.3 KB lying or dead (a ragdoll's body set 11.9 to 12.7 KB of it); saving 12 to 62 µs, laying 20 to 49 µs.

## Determinism

Late joins and resyncs are exact only if two peers given the same state step to the same bits. The rules every motion module keeps:
- **One figure's evaluation reads only its own state and the static world**, so poses are the same to the bit whatever the job pool's size, and with no pool.
- **Core's math** (fdlibm in Aether), not the platform's libm, so every platform computes the same.
- **Nothing hashed by address.** Figures are added in the same order on every side; an animator's graph is built call for call.
- **Physics state whole.** A ragdoll's bodies alone are not its state: the solver's warm starts and contact caches are (aephysics#189), so the snapshot carries them.

`tests/test_net_anim.ae` holds it: from the same input stream every joint of the client's figure is the host's to the bit at every tick (its trail of hashes goes into the determinism trail); under 150 ms of latency, 30 ms of jitter and 5% loss over three seeds of the hub, the client's feet and hands are the host's at every tick. At `6f921c0c` (2026-11-18, #997) every late join was bit for bit: seeded joins over 1,401, 1,680 and 1,198 ticks, joins while knocked down 1,092 of 1,092 ticks, dead 101 of 101, turning on the spot 670 of 670. Before #997 a peer joining a knocked-down figure started 656 mm and 77 degrees off it.

### Canonical contact order

**Changing in #1030.** Two figures tumbling against each other begin contacts in the same step, and aephysics began them in an order that depended on how its broadphase found them, so a joiner laid exactly could part from the host after many seconds (a join found 6.5 cm apart after 10 s of tumbling). #1030 gives aephysics a canonical begin order (bodies keyed figure times 64 plus bone, snapshot version 6); on branch `agent/asset` a tumbling join is bit for bit over all 719 ticks, and parts at tick 593 with the option off. It is not on this head.

## Costs

`test_net_anim` on 2026-11-19 at `bea4c991`: a figure streams 553 bytes a second walking, 8,175 while down (its ragdoll), 5,800 dead, 1,448 over the whole script. Over three seeds of the hub at 150 ms, 30 ms jitter and 5% loss, 1,948 of 1,948 ticks played the same to the bit on each, none before its inputs came. Clients joining at ticks 551, 272 and 753 started from the snapshot about 10 ticks on, their feet and hands within 0 mm and 3.8e-6 degrees 30 ticks on; the ragdoll's solver state in the snapshot was 12,156 bytes, put in 16.6 to 19.5 µs and laid in 37.7 to 53.2 µs. A remote figure costs `netanim` under a microsecond a frame (#911).

## The horde's struck zombies

A pose-bank horde hands a struck zombie to a ragdoll figure and back on every peer through `ae3d.nethandover` (#466), on the frozen `ae3d.handover`: [networking.md](../networking.md#struck-zombies-handed-to-ragdolls-on-every-peer).

## Limits and known issues

- `character.use` (slots, enter and exit takes) is not replicated yet (#1009).
- After a knockdown facing the other way, a client with no latency parts from the host at the get-up (hands 149 mm; #1003).
- Simultaneous contacts: #1030 above.
