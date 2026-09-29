# Networking

`ae3d.net` puts multiplayer in the engine (#413). A game marks what is networked, and the engine keeps it in step between one host and its clients. This page describes what is built: three transports -- an in-process loopback, TCP, and UDP with a reliable channel of its own -- the handshake, server-owned objects replicated and interpolated and corrected smoothly, fields of a script's state replicated beside them, snapshots quantised and sent as deltas against what each client has acknowledged, relevance by distance and by what each client can see and a budget of bytes for each client filled most urgent first, players moved by their clients' commands with prediction and reconciliation, each script's simulation run only where its object is simulated, events, objects the host creates and destroys while the game runs, a horde every peer simulates rather than receives, its struck zombies handed to ragdolls on every peer, the link measured on every transport and read over the agent channel, the editor playing a scene as a host and its clients, and the zombie street played by sixteen.

## A session

```aether
import ae3d.net

session = net.host_udp("0.0.0.0", 7777)          // or net.join_udp("192.168.1.20", 7777)
car = engine.object(e, "Car", body)
net.networked(session, car)                       // the host sends it; a client draws it
net.attach(e, session)                            // stepped by the engine every frame
```

Both sides build the same scene and mark the same objects networked in the same order. That order is the net id, which is how a snapshot's object is found on the client. The host's scripts move the objects; a client runs none on them. A program switches transport with the one call: `host_udp`, `host_tcp` or `host_loopback`, and the `join_` of each.

`examples/net_cars.ae` is the whole shape: eight cars round a ring. `examples/net_street.ae` is all of it at once: the zombie street played by a host and fifteen clients ([below](#the-street-played-by-sixteen)).

```bash
./build.sh examples/net_cars.ae
./build/net_cars                              # host on 127.0.0.1:7777
AE3D_NET=join:127.0.0.1 ./build/net_cars      # a client
AE3D_NET_BIND=0.0.0.0 ./build/net_cars        # host for the network
AE3D_NET_TRANSPORT=tcp ./build/net_cars       # over TCP, both sides; UDP is the default
```

## Transports

A transport moves messages between the host and each peer. A message is either reliable (never lost, in order: the handshake, events, objects created and destroyed) or unreliable (a snapshot, which the next one supersedes, so waiting for a lost one would only make it later; an input, which carries every command the host has not acknowledged).

| Transport | Made with | For |
|---|---|---|
| UDP | `host_udp(address, port)`, `join_udp(host, port)`, `udp_port` | A real network properly: a lost snapshot is not waited for, and reliable messages are made reliable on the same socket (below). `set_conditions(session, latency, jitter, loss)` simulates a link on what that side sends; `set_timeout(session, seconds)`. |
| Loopback | `hub_new`, `host_loopback(hub)`, `join_loopback(hub)` | Tests, and the editor's play as a host and its clients in one process. `hub_set_conditions(hub, latency, jitter, loss)` puts a real link's conditions on it, deterministically. |
| TCP | `host_tcp(address, port)`, `join_tcp(host, port)` | A network that lets no datagrams through. The stream is reliable and ordered, so both kinds of message travel the same way, and a lost segment holds every newer snapshot back. |
| Steam | not built: SteamNetworkingSockets is Valve's Steamworks SDK, proprietary and not available to this project ([#483](https://github.com/nicolas-maman/ae3d/issues/483)) | Lobbies and NAT traversal, behind the same calls, when a game ships on Steam. |

### UDP

`ae3d.netudp` is a connection over `std.udp` ([aether#2201](https://github.com/aether-lang-dev/aether/issues/2201)), built the way Quake 3's netchan and Glenn Fiedler's *Networking for Game Programmers* build one, and `ae3d.net`'s UDP transport is a session over it.

- **Packets.** Every datagram carries a sequence number, the newest sequence this side has received from the other, and a bitfield of the 32 before it: every packet acknowledges up to 33, so an acknowledgement lost with its packet is carried again by the next. A packet a sender learns was received is how it knows the reliable messages in it arrived, and when -- its round trip. A burst of more than 32 between two of the receiver's own packets (a large message arriving) would leave its oldest never acknowledged, so the receiver sends an acknowledgement at once every 16 packets it takes; and one the link reordered behind more than 32 newer is acknowledged on its own, with its 32 neighbours, from a ring of the last 1,024 received.
- **A reliable, ordered channel.** A reliable message gets an id and stays in a window of 1,024 until a packet carrying it is acknowledged. It goes in the next packet, and again whenever the resend timeout has passed: the smoothed round trip and four of its variance (RFC 6298), or half the round trip again where that is more, between 50 ms and a second. The half is for what the variance cannot see: a packet is acknowledged by whichever of the other side's next packets arrives first, so the samples are the quickest of several; with the variance alone a third of a 100 KB block was sent twice. The timeout grows by half with every resend of one message, to a second -- TCP doubles it, for a link congestion has filled, which a game's few kilobytes a second do not. The round trip is seeded by the handshake's, so the first messages are resent on the link's own timeout. The receiver keeps what arrives out of order and hands each over once, in id order. A message larger than 1,024 bytes goes as slices, each a reliable message of its own, and is handed over whole once its last slice is in: the horde's 30 KB state, or a 100 KB block.
- **Unreliable channels**, one a message kind: a message on one is sent once, numbered on its channel, and on a sequenced channel -- snapshots, acknowledgements -- one older than the newest already handed over is dropped: a late snapshot never takes a newer one's place. Inputs are unsequenced: each carries every command the host had not acknowledged when it was sent, so a late one holds nothing a newer did not, and the host keeps only what it has not queued. A message larger than a datagram goes as up to 255 fragments of one sequence number, handed over when all are in; a newer message on the channel drops what is left of an older one. A flush sends the unreliable first, what is only worth having now, and reliable messages fill at most 32 datagrams of it, so a large one goes over several frames and never crowds a snapshot out.
- **A handshake.** The client sends a request with a random salt of its own, padded to 64 bytes; the host answers with a challenge carrying a salt of its own, 9 bytes; the client answers with the two combined, and the host opens the connection. Every packet after carries the combined salt, and one that doesn't is dropped: a datagram from an old connection, or from anyone who didn't see the challenge, is not taken for this one, and a forged request makes the host send less than it, so it can't be used to flood a third party.
- **A timeout and a disconnect.** A connection that hears nothing for the timeout (5 s by default) is closed, and a client's handshake given up after it. A side with nothing to send sends an empty packet every tenth of a second, which carries its acknowledgements. A disconnect is said three times, at once, and the connection closed: `net_free` says it to every connection. The host calls the game's `on_leave(session, hook, context)` with every welcomed client that goes; a client's `disconnected(session)` becomes true and `connected` false.
- **Datagrams of 1,200 bytes at most**, under what every IPv4 and IPv6 path carries without fragmenting (IPv6's minimum is 1,280 with its headers). A payload packet's header is 13 bytes: its kind, the salt, its sequence, the acknowledgement and its bits.
- **The link's conditions**, for tests and the editor: `set_conditions` delays every datagram that side sends by a latency and up to a jitter more, and drops a share of them, reliable ones among them -- the reliable channel is the transport's own, and has to earn it. Each endpoint draws from a generator of its own, seeded by the order it was made, so a run loses the same datagrams again and two sides don't lose the same ones.

`traffic(session, kind)` counts what a side sent, by kind: `TRAFFIC_SNAPSHOTS`, `TRAFFIC_EVENTS` (every reliable message), `TRAFFIC_INPUTS` (the inputs, with the acknowledgements riding on them), `TRAFFIC_ACKS` (acknowledgements on their own) and `TRAFFIC_LINK` (the link's pings) on every transport; `TRAFFIC_HEADERS` (TCP's length frames, UDP's packet headers), and on UDP `TRAFFIC_ACK_PACKETS` (datagrams with nothing but acknowledgements, whole), `TRAFFIC_RESENT` and `TRAFFIC_HANDSHAKE`. `datagrams_sent` and `largest_datagram` say the rest, and every peer's link is measured apart, both ways ([The link, measured](#the-link-measured)). An IPv4 datagram carries 28 bytes of IP and UDP header besides.

## The protocol

Protocol 6.

| Message | Direction | Bytes |
|---|---|---|
| hello | client to host, reliable | `u8 1`, `u32 protocol` |
| welcome | host to client, reliable | `u8 2`, `u32 client id`, `u32 tick rate`, `f64 precision` (metres a step of a position) |
| snapshot | host to each client, unreliable | `u8 3`, `u32 tick`, `f32 host time`, `u32 ack` (the client's newest command the host has applied), `u8 base gap` (this tick less the tick of the snapshot it is a delta against; 0 for none), `varint objects`, `varint records`, `u8 flags`; with flag 1 the client's own player at full precision, `f32 x y z`, `f32 vy`, `u8 grounded`; with flag 2 the previous tick's time, `f32`; then a record each: `varint index gap`, `u8 fields`, and the fields it names -- x, y and z, each a zigzag varint of its change in steps of the precision (its value, where the base doesn't have the object), the rotation in 48 bits, and the object's replicated fields ([below](#fields-of-a-scripts-state)) |
| input | client to host, unreliable | `u8 4`, `u16 newest snapshot` (the client's acknowledgement), `u8 flags`, with flag 1 the client's view (18 bytes), `u32 first seq`, `u8 count`, a bit a command whether it is sent, then per command sent its walk's x and z in millimetres a second, each a zigzag varint of its change from the command sent before it, and its jump in 64ths of a metre a second, a varint |
| spawn | host to client, reliable | `u8 5`, `u32 net id`, `u32 owner` |
| ack | client to host, unreliable | `u8 6`, `u16 tick`, `u8 flags`, with flag 1 the view: a snapshot the client has, when no input carried it |
| event | either way, reliable | `u8 7`, `u16 event`, `u8 count`, then `count` `f32` numbers |
| create | host to client, reliable | `u8 8`, `u32 net id`, `u16 kind`, `f32 host time`, `f32 x y z`, `f32 qx qy qz qw` |
| destroy | host to client, reliable | `u8 9`, `u32 net id`, `f32 host time`, `f32 x y z`, `f32 qx qy qz qw`: when it went, and where it was |
| event with bytes | either way, reliable | `u8 10`, `u16 event`, `u32 length`, then `length` bytes |
| ping | either way, unreliable | `u8 11`, `u16 ping`: ten a second to every peer |
| pong | either way, unreliable | `u8 12`, `u16 ping`: the answer, at once |

A view is the client's eye, `f32 x y z`, the way it looks as a heading and a pitch in 16 bits each, its vertical field of view in whole degrees (`u8`) and its width over its height in 32nds (`u8`).

Over TCP each message is framed by a `u32` length. Over UDP each is a chunk of a packet: 5 bytes of header for a reliable one (its kind, id and length), 6 for an unreliable one (its kind, channel, sequence and length), 8 for a fragment.

## Time and interpolation

The host sends a snapshot every network tick: 30 a second by default (`set_tick_rate`), stamped with its clock.

A client estimates the host's clock from the least-delayed snapshot it has seen: a snapshot can arrive later than its stamp, never earlier. It draws every object at that clock less the interpolation delay (`set_interpolation_delay`, 100 ms by default), between the two samples around that moment. `view_time(session, now)` is that moment, in the host's time. It is what lag compensation will rewind to.

The delay has to cover a snapshot interval and the link's jitter, and another interval for each snapshot in a row it should survive losing: over 50 ms +- 20 ms and 10% loss, with the real clock's frames on either side, `tests/test_net_udp.ae` draws 150 ms behind. When snapshots stop coming, the objects hold at the newest one.

**Corrected smoothly, never snapped.** A burst of losses longer than the delay runs the view past the newest sample, and the object holds there; when the snapshots come again they put it on along its path, and drawn from them at once it would jump the whole way it went meanwhile. So an object is drawn from where it stood: the error between that and where its samples put it is kept, and falls away, to a third every tenth of a second (`set_smoothing(session, seconds)`; 0 corrects at once). It is not guessed on while it holds -- a snapshot that leaves an object out may mean it stood still or that it waited for the budget, and carrying it on would overshoot the one that stopped. An error over 4 m is the object moved, not a correction, and is taken at once. `tests/test_net_authority.ae` holds it to numbers: an object at 6 m/s through 400 ms of every snapshot lost jumps 2.06 m in one step with the smoothing off, and moves 0.40 m at most with it, against 0.10 m a step as it goes; 0.8 s after the snapshots come again it is drawn 0.65 mm from where the host had it.

## What each client is sent

A snapshot carries only what the client doesn't already have, of what is relevant to it, within its budget.

**Quantised.** A position goes in whole steps of the session's precision, a tenth of a millimetre by default (`set_precision`, the host's, sent in the welcome as a double): its x, y and z as integers, which a double holds exactly, so a delta is an exact difference of integers and a client that adds it holds what the host told it, to the bit. A rotation goes as its three smallest components in 15 bits each and which one was dropped in 2: the dropped one is the largest, so the others lie within +-1/sqrt 2, and a unit quaternion's length gives it back -- 48 bits, 6 bytes, within a tenth of a milliradian. Where the floats sent every object 31 bytes, a record now is its index's gap from the last (a byte), a byte of fields, a varint for each axis that changed (a byte for a move under 6 mm a tick, two under 82 cm, three under 105 m) and 6 for a turn. An object moving less than half a step is not moving, and costs nothing. A client's own player goes apart, at full precision, since it is what the client reconciles against: a quantum there would move it every snapshot.

**Deltas against what the client acknowledged.** Each snapshot is a delta against the newest one the client has acknowledged: the objects whose state differs are recorded, and everything else is as it was. The host keeps, for each client, a ring of the last 33 it told that client -- what the client will hold once it has each -- and the client keeps the last 33 it received. It rebuilds each new one from its base, keeps it, and acknowledges it; the acknowledgement rides on its next input (`u16`, put back beside the host's tick), and only a client with no input to send, or none since its newest snapshot, sends it on its own. A lost snapshot costs nothing: the host never deltas against one the client hasn't confirmed. A base 32 ticks old is not used, since the client may have let it go and a delta it couldn't read it could never acknowledge: past it, the snapshot goes whole (`set_deltas(session, false)` sends every one whole, what the deltas are measured against). An object that stands still is sent until the client's acknowledgement of it comes back, and never again. A snapshot older than one the client holds is dropped, counted by `stale_snapshots`: snapshots never go backwards.

**Drawn at their moments.** A client samples an object only when a record for it arrives: a sample says where the object was at the snapshot's time, and an object with no record in a snapshot may have moved and not been sent (past the budget). One that was still where the client had it at the tick before -- it had stood still, and starts to move -- is recorded with a flag, and the client holds it there until that tick, so it isn't drawn sliding from where it stood over all the time it stood; the previous tick's time is in the snapshot when the base is older than that tick.

**Relevance.** `set_relevance(session, metres)` sends a client only what is within that distance of its player (of its eye, where it has sent a view and has no player); `set_relevant(session, object, mode)` overrides one object -- `RELEVANT_ALWAYS` (a scoreboard, the ball), `RELEVANT_NEVER` (what only the host needs), or `RELEVANT_NEAR`, the default. What lies farther keeps the state the client was last told, so it costs nothing until it comes back within reach, and then it's sent as any change is. A client's own player goes in its own block, always. Without a radius, or with nothing to measure from, everything is relevant. A radius a little past what a client can see means an object is already there when it comes into view.

**What a client can see** (#487). A client says what it sees -- `set_view(session, eye, direction, fov, aspect)`, or `set_camera_view(session, camera)` -- and the view goes to the host with its inputs (its acknowledgements, with no player): each time the eye moves 25 cm or turns a degree, at most once a tick, and every half second whatever it does, 18 bytes. The host judges every object it would send against it: outside the view's frustum (widened by two degrees, what the view may be behind the camera by) it is out of sight; inside, a ray from the eye to the object's sphere (`set_bounds(session, object, centre, radius)`, 0.5 m round its place by default) -- to its centre, and where that is blocked to its top -- against the static world the host has as physics statics (`set_occluders(session, physics)`: the ground, the buildings) says whether anything stands between. A ray is cast when an object comes into the frustum and every sixth tick while it stays there, staggered, so a view full of objects costs a sixth of its rays a tick. What the client can see gathers priority four times as fast; what it cannot, a quarter as fast -- slower, never stopped: what is behind the camera still arrives, so turning round never shows a stale world. `set_visibility(session, false)` weighs by distance alone, what the sight is measured against. `sight(session, client, id)` says what the host last made of an object (`SIGHT_SEEN`, `SIGHT_OUT`, `SIGHT_HIDDEN`).

**A budget, most urgent first.** `set_budget(session, bytes)` limits every client's snapshot to that many bytes; `set_client_budget(session, client, bytes)` one client's (a slower link). What changed and is relevant is a candidate, and each candidate gathers priority every tick it waits: its own (`set_priority(session, object, priority)`, 1 by default) times 1 + 10 / d, d its distance from the client in metres (a metre at least), so an object at the player gathers eleven times what a far one does, and by what the client can see of it. The snapshot is filled in order of priority gathered, most first -- except that an object the client can see that has already waited a tick goes ahead of the rest, and so does anything that has waited 45 ticks (a second and a half): a priority alone would let a hidden object that gathered for a second outrank one in view, and a view full of changes the budget can't hold every other tick would keep what is behind the camera from going. One that doesn't fit leaves room for a smaller one after it, keeps what it gathered, and goes next tick, first. The header and the own block are counted first, and a record's index gap as the varint of its index, so a snapshot is never over the budget -- but for one record no snapshot's room could hold (an object whole with its fields, over a budget smaller than that), which goes alone when it comes first rather than wait for ever. `worst_wait(session, client, id)` is the most ticks an object waited, changed and unsent, `worst_wait_any(session, client)` the most of any, and `worst_wait_sight(session, client, sight)` the most in a row in one sight; `largest_snapshot`, `snapshot_bytes`, `snapshots_sent` and `whole_snapshots` a client's snapshots; `view_bytes` and `hidden_bytes` the record bytes it was sent of what it could see and of what it could not; `objects_sent` the records written, every client's.

`known(session, id)` and `state_at(session, id, out)` read an object's state as the wire carries it: a client's newest snapshot's, or the host's at its last tick. `host_tick` and `snapshot_tick` are those ticks.

## Fields of a script's state

An object's transform is not all of it: a player has its health, a car its speed and whose it is (#486). A field of a script's state is replicated beside the transform:

```aether
struct Car {
    speed: float
    horn: bool
}

car = engine.object(e, "Car", model)
net.replicate(session, car, "speed", &state.speed, net.REPLICATE_FLOAT, 0.01)   // to a centimetre a second
net.replicate(session, car, "horn", &state.horn, net.REPLICATE_BOOL)
net.replicate(session, car, "driver", null, net.REPLICATE_TEXT)                // the session keeps a text
net.networked(session, car)
net.on_changed(session, car, "horn", honked, game as ptr)                       // a client, when it changes

net.set_text(session, car, "driver", "Nico")                                     // the host
name = net.text(session, car, "driver")                                          // either side
```

- **Kinds.** `REPLICATE_INT` (an `int`), `REPLICATE_FLOAT` (a `float` in whole steps of a precision, or its 64 bits where the precision is 0), `REPLICATE_BOOL`, `REPLICATE_VEC3` (three floats, the same way) and `REPLICATE_TEXT` (up to 31 bytes, which the session keeps: a string field of the game's has an owner already, the setter that assigned it). Both sides register the same fields on the same objects in the same order, as they mark objects networked; the object may be networked after them, so a kind's maker registers its object's fields before the session numbers it. On the host an object's fields are fixed once a tick has taken its state; `replicate` refuses one after, and a name twice.
- **The host's.** Its game writes a field; every tick the session reads it as the wire carries it -- an int as it is, a float as its steps (to 2^53) or its bits, a bool as 0 or 1, a text as its length and bytes -- beside the object's quantised transform.
- **On the wire.** In the object's record, against the snapshot the client acknowledged, only when it differs: the record's fields byte says so (64), and a varint mask names the fields that changed; an int or a stepped float goes as a zigzag varint of its change, a float in bits as its 8 bytes, a bool as a byte, a text as its length and bytes. Where the base has none of the object's fields (the first time, or whole), the record says that too (128) and carries how many there are, each one's kind (and a stepped float's precision, the host's, as a double), and every value -- so a client reads an object's fields before it has made the object, which a snapshot, never held up behind the reliable word that makes it, may bring first. A field that stands still costs nothing; the budget takes or leaves a record whole, so a field and the transform it goes with arrive in the same snapshot.
- **On a client.** Every field is written from every snapshot the client takes, where the game keeps it, in the order it takes them -- never backwards, so in tick order -- and never from a snapshot whose fields for the object are older than the ones it last wrote: a snapshot cannot say an object is gone, so after the host lets one go its fields would be its base's again. `on_changed(session, object, name, hook, context)` calls `hook(context, change)` after a snapshot changes a field's value -- `change.object`, `.name`, `.order`, `.tick` and `.now` -- in the order the fields were registered within one snapshot. A field is state, not an event: two changes between the snapshots a client takes are one change there, the newer; what must be seen every time is an event.
- **What a client holds.** `fields_known(session, id)` says whether its newest snapshot has an object's fields; a player told of before any snapshot carried it holds what its maker gave it until then.

`tests/test_net_fields.ae` holds it to numbers over loopback UDP, 50 ms ± 20 each way (which reorders) and 10% lost: every client's copy of every field of twelve crates -- one of every kind each -- a mover, three players' health and a rocket's fuel is the host's at its snapshot's tick in every frame, bit for bit; every hook fires once for every change the host made, with its value, in its order, and for nothing else; standing still, six fields on twenty moving objects cost the same bytes to the byte as none ([the numbers](#what-it-is-held-to)).

## Players

A player is a character controller ([physics.md](physics.md#characters)) owned by one client. The game says how one is made, the same on both sides:

```aether
make_player(context: ptr, client: int) -> *CharacterController {
    e = context as *Engine
    o = engine.object(e, "Player ${client}", body)
    behaviour.object_set_position(o, spawn_point(client))
    return physics.character_controller(o, 0.3, 1.8)
}

net.set_player_maker(session, make_player, e as ptr)
```

The host makes a player for every client it welcomes and tells every client about it (spawn); each client makes the players it is told of, its own among them (`my_player`). Then, every fixed step, a client gives its command:

```aether
net.player_input(session, walk, jump, now)        // walk in m/s, jump in m/s up
```

- **Prediction.** The command moves the client's own player at once, in the client's world, the way `physics.character_move` would on the host: no round trip before the player walks. It moves it as the wire carries it -- its walk in whole millimetres a second, its jump in 64ths of a metre a second -- so the host applies the very numbers the client predicted with.
- **Commands to the host.** Each input message carries every command the host has not acknowledged, the oldest first (up to 64, a second of them), and the newest snapshot the client holds (its acknowledgement, riding along; with a player, a client waits for its next input to acknowledge a snapshot, unless a fixed step and a half goes by without one). A command is sent where it differs from the one before it, as its change from that one -- a walk that turns steers a few millimetres a second a step, a byte an axis -- and as a bit where it is the same again: a key held is the same command step after step. A client walking a circle, its every command different, sends 1.7 KB a second of inputs where the floats sent 4.5. The host's acknowledgement is the last command it applied, so every message starts at or before the next one it needs and runs on without a gap: whatever the link loses or reorders, the host never has a command to skip and the client never predicted one the host did not apply. The host keeps them by their sequence and applies one a host step, in order, to its player for that client, so the player moves in the host's world at the pace it walked, whatever the link's jitter did to when the commands arrived; a queue grown past three commands catches up a command a step.
- **Reconciliation.** Every snapshot tells the client the newest of its commands the host has applied, and where that left its player (with its vertical speed and whether it stands). The client puts its player there and replays the commands the host has not applied yet. When both worlds agree, as they should, that moves nothing; `prediction_error(session)` is the most it ever moved.
- **Everyone else's.** The other players are drawn interpolated, like any networked object.
- **The host plays too.** `host_play(session, now)` gives the host a player of its own (client 0), told to every client like any other; on the host, `player_input` moves it directly, since the host's world is the authority. Without it the host is a dedicated server.

Networked scene objects are marked before hosting or joining, so their ids come first and the players' after them.

`examples/net_walk.ae` is players on a plaza: the host plays too, every client joins with a capsule of its own, W/A/S/D walk and space jumps, and the camera follows your own player.

```bash
./build.sh examples/net_walk.ae
./build/net_walk                              # host and a player, on 127.0.0.1:7777
AE3D_NET=join:127.0.0.1 ./build/net_walk      # a client
```

With `AE3D_NET_AUTOWALK=1` each walks five seconds round a circle by itself, and prints where every player is when it closes. A host and a client run side by side, over UDP or TCP, print the same position for the client's player: (-0.915374, 0, -3.84055) on both, over UDP on this machine.

## Who simulates what

An object is simulated on one side and drawn on the rest. On the host, what it owns and its own player; on a client, its own player. Everything else a side has of the game is remote there: on a client what the host owns and every other client's player, on the host a client's player (it moves by that client's commands).

- **Scripts.** A script's `fixed_update` -- its simulation -- runs only where its object is simulated: the engine passes a remote object's by (`behaviour.object_remote`, which a script can ask too, as it would ask whether it has authority). Its `update` and `late_update` -- what the object looks like, what it plays -- run on every side. So a scene built the same on every peer, its scripts and all, simulates each object once.
- **Bodies.** A dynamic body on a remote object is made kinematic: driven where the session puts it, pushing what it meets as a kinematic body does, never simulated against the host's word.
- **Giving it back.** `release(session)` makes every networked object simulated here again, its scripts' `fixed_update` run and a body the session drove dynamic again, for a game that plays on alone after its session. `net_free` leaves the game's objects be: they may be gone by then.

`tests/test_net_authority.ae`: over the loopback, a crate the host owns runs its script's `fixed_update` 240 times on the host and none on either client, and its `update` 240 times on every side; each client's player's runs on its own client alone, the host's on the host alone. The crate's body, pushed along the ground at 2 m/s on the host, is kinematic on a client and drawn within 0.05 mm of where the host had it; `release` makes it dynamic again.

## Events

An event is a game's own message: a horn honked, a hit, a door opened. Both sides register the same events in the same order, each with a handler:

```aether
honked(context: ptr, call: *NetCall) {
    game = context as *Game
    horn(game, call.sender, call.a)               // who honked, and how loud
}

net.on_event(session, "honk", honked, game as ptr)
```

and either side sends one:

```aether
net.send_event(session, "honk", net.HOST, now, 0.8)            // a client, to the host
net.send_event(session, "hit", net.EVERYONE, now, id as float, 25.0)   // the host, to every client
net.send_event(session, "whisper", 2, now, 1.0)                // the host, to client 2
```

- **Reliable and in order.** An event travels the reliable way, so it arrives once, and in order with everything else reliable the same side sent the same peer. An event the host sends after creating an object arrives after the object is there.
- **Four numbers.** An event carries up to four numbers (an id, an amount, a place), 32-bit floats on the wire, and only as many as the last one that isn't 0: a honk with one number is 8 bytes, with none 4. A handler reads them as `call.a` to `call.d`, 0 where the sender gave fewer.
- **An id on the wire, not the name.** An event is its order among the registered: 2 bytes. That's why both sides register in the same order, as they mark the same objects networked.
- **Who sent it.** `call.sender` is the client's id on the host, and `net.HOST` (0) on a client. A client sends only to the host; the host sends to one client or to `net.EVERYONE` it has welcomed, never to itself (its game calls its own code). A client that wants to reach the others sends to the host, which passes it on.
- **When.** A handler is called in the step the event arrives, and `call.now` is this side's time in that step, what a reply is sent at. `send_event` is false when there is no such event or no one to send it to yet: a client before its welcome.
- **Bytes.** An event can carry a block of bytes instead of numbers, a state too big for four of them: `net.send_event_bytes(session, "state", to, now, data, length)`, 7 bytes and the block. The handler reads `call.data` and `call.length`, the session's until it returns.
- **A client that joins late.** `net.on_join(session, hook, context)` calls `hook(context, client, now)` on the host with every client it welcomes, after its welcome, its player and the objects alive are on their way, so what the game sends it from there arrives after them.

## Spawning

The scene's networked objects are known by the order both sides mark them. An object the host creates while the game runs, a rocket or a car driven in, is known by the id the host gives it (the next after every id so far) and by its kind. Both sides register the same kinds in the same order, each with a maker and an unmaker:

```aether
make_rocket(context: ptr, id: int) -> *GameObject {
    e = context as *Engine
    return engine.object(e, "Rocket ${id}", rocket_model())
}

unmake_rocket(context: ptr, o: *GameObject) {
    engine.destroy(context as *Engine, o)
}

net.object_kind(session, "rocket", make_rocket, unmake_rocket, e as ptr)
```

The host creates one, moves it as it moves anything, and destroys it:

```aether
rocket = net.create_object(session, "rocket", muzzle, aim, now)
...
net.destroy_object(session, rocket, now)
```

- **Create.** The host makes the object with the kind's maker, places it, networks it, and tells every client its id, its kind and where it is. Each client makes its own with the same maker and places it the same. From the next tick the snapshots carry it like any object. A client keeps where it was made as its first sample, so it is drawn from there to wherever the snapshots take it. It exists the moment the word arrives, so an event that names it (`net.id_of`, `net.object_of`) finds it, and it waits at that first place until the client's view reaches the moment it was made.
- **Destroy.** The host tells every client when the object went and where it was then, and lets its own go. A client draws the object to that place and lets it go when its view reaches that moment, so the object lives the same stretch of the host's time on every side. Letting it go when the word arrived would cut the last 100 ms or so of every rocket's flight. A snapshot can't say an object is gone (one it leaves out is as it was), so a sample from after that moment is the old state carried on, and the client drops it.
- **Late join.** A client the host welcomes is told every created object still alive, and none destroyed before it came.
- **Ids aren't given again.** A destroyed object's id stays empty, so a snapshot or a delta that still names it, against an older baseline, finds nothing there, and a later object is never read as a change against the old one's state. A session creates up to 65,535 objects over its life, the limit of the snapshot's `u16` index.
- **Letting go.** The unmaker is the game's (`engine.destroy`, as a game does); `net_free` calls it for every created object still alive. A null unmaker leaves the object to the game.

## The horde

A horde isn't sent a zombie at a time. A snapshot of floats was 31 bytes an object, so three thousand zombies would be 2.7 MB a second to every client, and a city holds a hundred thousand. `ae3d.nethorde` sends what the horde's simulation can't know by itself, where it began and every change to what drives it, and every peer, the host among them, steps the same horde at the same fixed ticks and holds it to the bit.

```aether
import ae3d.nethorde

field = nav.flow_new(x0, z0, x1, z1, 1.0)            // the same field on every side
nav.flow_block_model(field, building)
horde = nethorde.horde_new(session, field)           // both sides, at the same point among their registrations
nethorde.attach(e, horde)                            // after net.attach: stepped every frame

nethorde.start(horde, seed, 3000, x0, z0, x1, z1, now)   // the host
nethorde.set_target(horde, player.x, player.z, now)      // when the player crosses a cell
nethorde.kill(horde, index, now)                         // a zombie shot
nethorde.hit(horde, index, dx, dz, 0.5, now)             // a zombie shoved (dx, dz) m/s, stunned half a second
```

A client reads its horde as the host does: `horde_count`, and the `positions`, `yaws` and `phases` columns, which the crowd's tiers and draws take as they are ([crowds.md](crowds.md)), and `stunned(horde, index)`, the seconds a hit zombie has left of its stun, what a game draws a stagger by.

- **The start.** The seed, the count, the ground, the rules (speed, turn, separation) and the tick rate (30 a second) as doubles, and the host's time at tick 0: 215 bytes. Each peer spawns the same horde from the seed with the horde's own integer generator.
- **Inputs at a tick.** The target the flow field floods from, a zombie killed, which leaves the horde (the last zombie takes its index), a zombie hit, and a zombie handed to a ragdoll or given back (below). The host applies one at once and tells every client the tick it takes effect at, the next: 16 bytes a target, 12 a kill, 25 a hit, 12 a handover, 25 a rejoin.
- **A hit.** A velocity change and a stun in whole ticks. The horde's velocity is each tick's scratch (the wander writes it whole, and with a figure the step scales it to the walk's speed), so a shove is a velocity of its own on the few zombies hit, beside the columns. For the stun the zombie keeps its heading and its walk's phase, stands in the step (its velocity zeroed after the separation, so the others are still pushed off it), and after the step its shove carries it, fading in a straight line to nothing on the stun's last tick: v over n ticks carries it v dt (n + 1) / 2, 1.07 m for 4 m/s over half a second. A zombie hit again while stunned adds the new change to what is left of its shove and is stunned for the longer of the two. The change is kept as the 32-bit float the wire carries, on the host too, and the shoves are in the hash and in a late joiner's state.
- **A seal a tick.** Every tick the host tells every client it has done it: 8 bytes. Reliable messages arrive in order, so a client holding the seal for a tick holds every input for it, and steps it only then. A client steps its horde to its view time, where it draws everything else, a tick at a time and never past the newest seal: it runs the view's 200 ms behind the host and never guesses.
- **A hash.** Every `set_checks` ticks (30 by default, once a second) the seal carries 48 bits of a hash of the host's horde at that tick: 16 bytes. A client whose own differs asks for the horde's state and takes it, as a late joiner does.
- **Late join.** A client welcomed after the start is sent the horde as it is, quantised: the rules, 10 bytes a zombie, the index of each one handed over (4 bytes), and 32 a shove under way. A zombie's state is its x and z (its y is the road's), its heading and its walk's phase; its velocity is a tick's scratch and isn't state. x and z go on a 24-bit grid over the ground (7 µm across the test's 120 m street, a millimetre across 16 km), the heading in 16 bits of a turn, the phase in 16 bits of the walk: 10 bytes where the doubles were 32, 30 KB for 3,000 zombies where they were 95 KB, and 4.8 MB for half a million where they were 16 MB. The shoves are few and go as their doubles.
- **Every peer snaps to it.** A joiner has to hold exactly what every other peer holds, and a quantised state isn't what anyone holds. So as it sends one, the host snaps its own horde to the quantised values and tells every client to at the next tick, an input like the others (8 bytes a client). Unpacking a packed value and packing it again gives the same steps, so a snap is exact and the same on every peer, and two joins in one tick snap once. A zombie handed over stays parked through a snap: its place isn't on the grid. The other way, the joiner taking the quantised state as it is and the next hash check putting it back, is kept behind `set_join_snap(horde, false)` for the measurement below: it holds the host's horde a second later, and costs four times the bytes, since what puts it back is the doubles (a quantised resync would be off again). A resync, too, is quantised and snapped.
- **Why not replay.** Replaying the inputs from tick 0 instead would be a few hundred bytes but a simulation of every tick since the game began: 4 seconds in, 119 ticks of 3,000 zombies, 23 ms here; an hour in, 108,000 ticks, 20 s of the joiner's time, while the state stays 30 KB. Replay wins the first seconds of a game (over a link of a megabyte a second the two cross about 5 s in, where sending the state takes as long as replaying the ticks); the state wins every game past them, and doesn't grow with it.

### Struck zombies, handed to ragdolls on every peer

`ae3d.handover` hands a struck zombie to an active ragdoll and takes it back when the figure recovers, a player alone ([motion.md](motion.md)). A networked horde is simulated on every peer and hashed, so a zombie has to leave it at the same tick everywhere and come back to the same bits; and a ragdoll is physics, which isn't bit-exact across machines. `ae3d.nethandover` joins the two (#466):

```aether
import ae3d.nethandover

pool = handover.pool_new(e, "zombie.glb", "Walk", 12)   // every side, the same figure
glue = nethandover.handover_new(horde, pool)            // every side, after horde_new
nethandover.attach(e, glue)                             // after nethorde.attach

nethandover.strike(glue, index, point, impulse, now)    // the host: handed to a figure, POWERED, struck
nethandover.kill(glue, index, point, impulse, now)      // the host: LIMP, and compacted when despawned
```

- **Out at a tick.** The host's pool takes a figure, stands it where the zombie was drawn and strikes it; the horde's `hand_over` input takes the zombie out on every peer at the next tick: its out flag set, its place parked far off the ground (where ae3d.handover parks one, past any cull), and every pass of the tick passing it by -- the separation (`horde.separate_exact_out`: not in the grid, so it neither pushes nor is pushed, and a crowd of them parked together takes no cell's room from the rest), the step (`step_out`), and the flow field's steering (it finds no cell there). A shove on it is dropped: the ragdoll took the blow. The out flags are in the hash, and in a joiner's state.
- **Only the host simulates the ragdoll.** Its twelve bones are created objects of the kind "horde.bone" -- the kind's maker hands the session each bone's own object on the host, and a stand-in on a client -- sent as every object is: quantised, as deltas, within each client's relevance and budget. A "horde.ragdoll" event says which zombie they are. A client stands a figure of its own pool as a puppet (`handover.puppet`: its bodies parked for good, its clip stopped) and poses it every frame from the bones as it draws them, interpolated at its view time (`handover.puppet_pose`, the rig set from the pose as `physics.ragdoll_show_pose` sets it).
- **Given back quantised.** The figure gets up and goes back: the pool writes where it stands into the host's columns, and the horde's `rejoin` input gives the zombie back on the grid a joiner's state packs it on -- 10 bytes of x, z, heading and phase -- on the host now and on every peer at the next tick, the same bits everywhere. Its bones are destroyed.
- **The same frame.** A puppet appears at the host's time of the handover's tick and goes at the rejoin's (a destroy says when an object went, and it may be a tick ahead), so on a client the zombie leaves its horde as its figure appears, and comes back as it goes: never both, never neither.
- **Killed.** A zombie killed while handed over lies as a limp figure, its flag set, until the pool despawns it (`handover.set_on_despawn` says when); then the horde kills it too, which compacts it away -- at the glue's next step, not inside the pool's own, so a strike the despawn made room for keeps its index.
- **Moved.** A kill's swap moves the last zombie into the dead one's index; the horde says so on every peer (`set_on_move`), and a figure handed that zombie follows it (`handover.renumber`).
- **Joining mid-handover.** A client that joins while a zombie is out is sent the horde with its out flags, the bones alive (net's created objects), and the "horde.ragdoll" for each: it draws what everyone else does.

### The same on every platform

**What makes a tick the same everywhere.** A tick is `ae3d.horde`'s and `ae3d.nav`'s passes in a fixed order: the headings turned toward the field (`flow_steer`), the velocities along them (`wander`), the separation, and the step, by 1 / the tick rate, never a frame's delta, then the shoves, each moving only its own zombie. Each pass works a figure at a time over the pool and writes only that figure, so the pool's size and its timing change nothing. With one exception, found on the way: the separation with no pool visits each pair once and pushes both, which adds the same pushes in another order than the pool's gather, and 1,773 of the 4,500 velocity components of a knot of 1,500 differ in their last bits. `horde.separate_exact` gathers at any thread count, and is what the horde steps by. The flow field's headings were libm's `atan2`, which isn't the same function on every platform; a cell points one of eight ways, so they are eight constants now. What is left of libm is `sqrt`, `floor` and `fabs`, exact everywhere, beside the horde's own polynomial sine and arctangent. A figure's pose bank (`set_figure`, when the walk drives the step) has to be the same bytes on every side too: its travel table is in the step.

**No multiply fused with an add** (#441). An FMA rounds `a*b+c` once where the pair rounds twice, so a program that fuses and one that doesn't part in the last bit. x86-64 without `-march` has no FMA to fuse into; Apple Clang on arm64 fuses within an expression by default (`-ffp-contract=on`), and GCC's default outside ISO mode is `fast`, which fuses across statements too. Every compile line of every build script now says `-ffp-contract=off` (`ae3d_fp_flags` in `scripts/native.sh`): the engine's library, the generated program, the editor, a script.

**Proved on every runner.** `tests/test_determinism.ae` hashes, from a fixed start, the networked horde at every tick -- 2,000 zombies on the test street's ground and flow field, the target moved, zombies killed, hit, handed over and given back, and a client joining mid-run, which snaps every peer to the quantised state: every pass above, the snap's and the rejoin's packing -- and aephysics's falling ragdolls (the reference's cross-platform scene: eight humans dropped on grid meshes and tori) at every step until every body sleeps. In one process it holds the horde's trail the same at one thread and at four, a joining client to the host's every frame, and the physics' the same twice. With `AE3D_DETERMINISM_TRAIL=<path>` it writes the trail, a line a tick and a step, each hash in sixteen hex digits. Every CI runner -- Linux and Windows on x86-64, macOS on arm64 -- writes its trail after its run, and the `determinism` job reads all three and compares them line for line, failing on the first that differs and naming it. On the pack's first CI run the three runners wrote the same 513 lines -- the horde's 181 ticks and the ragdolls' 332 steps -- to the bit.

## The link, measured

Every transport's link is measured by the session itself, the same way on each, both ways (#488). Ten times a second each side pings every peer it has welcomed (a client its host, once welcomed), and the peer answers at once: 3 bytes each and a chunk's header. A pong is a round trip as the game has it, a frame on either side included; `round_trip_us(session, client)` is their smoothed round trip and `jitter_us` its variance, as RFC 6298 (and TCP) smooths them, kept in whole microseconds; `loss_ppm` is the share of the last fifty pings judged that were lost -- unanswered after a second -- in parts per million (`round_trip`, `jitter` and `loss` the same in seconds and shares; `pings(session, client, what)` the pings sent, answered and lost). On a client `client` is ignored: its peer is its host.

Every byte to a peer and from it is counted by kind -- snapshots, events, inputs, acknowledgements, the link's pings, the transport's headers (UDP's packet headers and every chunk's own; TCP's length frames), its resends (received: reliable chunks that came again after they were already here) -- `link_bytes(session, client, SENT or RECEIVED, kind)` since the link began, and `rate(...)` the whole bytes a second over the last window of a second (`window_us` long), `TRAFFIC_ALL` their sum. A host's peer adds its budget (`budget_of`), its snapshots whole and as deltas, the waits, and the bytes spent on what it could see; a client its prediction's corrections, the last and the worst (`last_correction`, `prediction_error`, `correction_um`).

**On the agent channel.** `net.stats` answers with every session in the program, a host and its clients alike (the editor's play, a test, or a game with its bots), or the one at `session`: each figure a whole number in the unit its name says, the number `ae3d.net` measures ([agent.md](agent.md#a-multiplayer-session)). `net.set_link` sets the link's simulated conditions, as the editor's play sliders do: a UDP session's on what it sends, a loopback session's on its hub (`set_link(session, latency, jitter, loss)` in code). `tests/test_agent_net.ae` asks a host and a client over loopback UDP through the channel, each held still by `frame.pause`, and compares all 114 figures of the two with the sessions' own, twice: none differs. The round trip it reports is the link's 20 ms each way and the frames either side (56 ms); `net.set_link` to 100 ms moves it by 155 to 165 ms, for the 160 it added.

## The street, played by sixteen

`examples/net_street.ae` is the zombie street played by a host and its clients (#489): three blocks of the street, players on foot, two cars round the road with their speed, their horn and their driver replicated as fields of the cars' state, and a horde of the pipeline's zombie -- 400, its walk baked into a pose bank, drawn from the full mesh within 20 m of the camera and the export's stand-in past it -- simulated on every peer, hunting the host's player and shoved by the cars at every peer's same tick. Each client sends its view; the host judges what it sees against the street it has as statics.

```bash
./build.sh examples/net_street.ae
./build/net_street                              # a host and 15 bot clients in this process
AE3D_NET=host ./build/net_street                # a host for the network, on :7777
AE3D_NET=join:192.168.1.20 ./build/net_street   # a client of it
```

By default the host plays in the window and fifteen bot clients join it over real datagrams on this machine's loopback interface, every side's link 50 ms each way and 2% lost, each bot a world of its own -- the street's collision, its players, its horde -- as a machine across the network would have, walking a stretch of the road of its own. `AE3D_NET_SECONDS=n` ends the play n seconds after the last has joined and says what it measured; `ci.sh` runs ten seconds of it and holds it to the first four rows. Eight runs of it on this machine:

| | Measured, over eight runs | Held to |
|---|---|---|
| players | 16: the host and 15 clients | 16 |
| a client's bytes a second, in its worst second of the run | 7.3 to 11.5 KB down (the most where its join -- the horde's state, the whole first snapshot -- fell in one second), 3.1 to 3.2 KB up; an ordinary second 6.0 to 6.5 KB down (snapshots 3.4, the horde's seals, hits and targets 1.1, headers 1.7, pings 0.05) and 3.0 up (inputs 1.05, headers 1.9, pings 0.05) | under 20 KB down and 4 KB up, every second |
| every client's horde against the host's at the tick it reaches, every frame | 4,299 to 4,346 ticks compared a run, none different; 4,625 to 4,642 seals' hashes checked, none diverged | none |
| the cars' fields on every client | the driver's name and the speed as the host has them on 15 of 15, every run | all |
| the most a reconciliation moved a client's own player | 3 µm, the worst of the fifteen; most 1 µm | stated |
| the host's frame | 6.9 ms with the scene alone, 6.4 ms with its 15 clients -- the difference is what the camera sees; the host's own work (its cars, its session, its horde, the crowd's instances) 0.05 ms a frame alone and 0.14 ms with them, its session's step 0.09 to 0.10 ms | stated |

The round trip each bot reports is 112 to 117 ms: the link's 100 and the frames either side. A client joining from another machine (`join:`) plays the same street: over loopback, its horde checked every tick, none diverged, and its player's worst correction 0 µm.

## What it is held to

`tests/test_net.ae` runs a host and a client in one process. Sixteen objects go round a circle of 10 m at a radian a second, and the client is measured against where the host had each object at the client's `view_time`:

| Link | Worst error | The geometry's bound |
|---|---|---|
| perfect loopback | 1.440 mm | the chord between two snapshots, 10 (1 − cos 1/60) = 1.39 mm, and half a step of the precision on each axis, 0.087 mm |
| 100 ms, 20 ms jitter, 2% loss | 5.594 mm | a lost snapshot doubles the interval, 10 (1 − cos 1/30) = 5.55 mm, and the precision's |
| TCP on this machine | 2.8 mm | real-time steps, ticks not aligned to them |

Sixteen moving objects cost a client 6.11 KB a second, the link's pings among it, where the floats cost 14.9. With 48 more that stand still, over the lossy link, it costs 9.46 KB a second, where the floats cost 19.2. The still ones are drawn where they stand, and are sent only until their acknowledgement is back: 1,280 records in two seconds, where sending every object every snapshot would be 3,840.

`tests/test_players.ae` runs a host and two clients, each with a world of its own, over 100 ms latency, 20 ms jitter and 2% loss. The host plays and walks; client 1 walks, turns and jumps; client 2 walks:

| | Measured | Held to |
|---|---|---|
| a command moves the client's player the step it is given | 50 mm at 3 m/s | 49-51 mm |
| the most a reconciliation moved a player | 0.0004 mm | 1 cm |
| a client's own player at rest against the host's | 10⁻¹¹ mm | 1 mm |
| the other client's player at rest | 10⁻¹¹ mm | 1 cm |
| the other client's player while walking, against the host at view time | within 1 cm on 128 of 131 steps, 35 mm at worst | 1 cm on 95%, a step (50 mm) always |
| the host's own player at rest, drawn by a client | 10⁻¹¹ mm | 1 cm |
| a jump's peak, client against host | 0.9186 m and 0.9186 m | 1 cm |
| a client's commands, with its acknowledgements on them | 0.97 KB a second | 4 KB |
| relevance 40 m: a crate among the players, one 200 m off | the near one where the host has it; the far one never sent | |
| a hostile link, one client walking client 1's path: 100 ms, 40 ms of jitter, 40% of snapshots and inputs lost | the most a reconciliation moved it 0.0002 mm; at rest where the host has it, to 10⁻¹¹ mm | 1 mm |

The walking error is under a centimetre except at three steps, where the host caught up a queue the link had let grow, applying two commands in one step. Applying commands as they arrived, instead of one a host step, made it 52.7 mm. Over the hostile link, inputs that carried the newest four commands lost one for good in 0.4⁴ = 2.6%: the host skipped two of them and a reconciliation moved the player 100 mm. Carrying every unacknowledged command costs less (1.47 KB a second where the four cost 3.06, and 0.97 as their changes in millimetres a second) and loses none. The players at rest are at whole positions, which the precision holds exactly.

`tests/test_net_events.ae` runs a host and two clients, and a third that joins 2.67 s in, each with a world of its own, over 100 ms latency, 20 ms jitter and 2% loss. The clients honk to the host, the host sends scores to everyone and whispers to client 2. It fires nine rockets on an arc, a quarter second apart, each flying 0.9 s, and drives two cars round a circle, the first gone after a second:

| | Measured | Held to |
|---|---|---|
| events: 192 honks, 80 scores to each client, 24 whispers | every one once, in order, from its sender, with its numbers; client 1 had none of client 2's whispers | all |
| an event, sent to handled | 133 ms at most | a one-way trip, its jitter and a step: 137 ms |
| an object, created on the host to made on a client | 133 ms at most | 137 ms |
| a created object drawn against where the host had it at the client's view time | within 6 mm on 1,546 of 1,546 object-steps, 5.6 mm at worst | 6 mm on 99%, 13 mm always |
| destroyed on the host to gone on a client | 217 ms at most, never drawn past its moment | the view's lag, 200 ms, and a step |
| the late client | told the four objects alive when it joined, none of the seven gone before; the scores from its welcome on, in order | all |
| a client's 132 honks, its acknowledgements and its pings | 0.54 KB a second over the run (a honk with three numbers is 16 bytes) | 1 KB |
| the host, to three clients | 3.67 KB a second, where the floats cost 7.3 | 10 KB |

The drawing error is the geometry's, as in `tests/test_net.ae`: a rocket's arc is off the chord between two snapshots by g dt²/8, 1.36 mm at 30 a second and 5.45 mm across a lost one; a car's circle 1.39 and 5.55 mm. Two snapshots lost in a row would be 10 (1 − cos 1/20) = 12.5 mm, what the bound allows; in this run none were. Over TCP on this machine, 20 honks reach the host once and in order, and a rocket is made on the client and goes when the host destroys it.

`tests/test_net_udp.ae` runs a host and two clients over real datagrams on this machine's loopback interface, ports the system picks, every side's link simulated: 50 ms ± 20 ms each way and 10% of datagrams lost, reliable ones among them. 364 objects -- sixteen round a circle, the rest still -- three players walking, honks and scores twenty a second, and a 100 KB block to each client two seconds in; on the real clock, 60 steps a second, for five seconds and a quiet one after:

| | Measured | Held to |
|---|---|---|
| welcomed: two round trips of handshake, a third of hello and welcome | 517 and 667 ms | 1.5 s (four of the six datagrams lost) |
| every honk at the host, every score at every client | 81 and 81 of 81, none out of order, twice or wrong; the slowest 633 ms (a message lost twice, and the ones behind it) | all, exactly once, in order |
| the 100 KB block, 98 reliable slices | whole at each client, once | whole, once |
| snapshots | 147 and 139 taken, none backwards | never backwards |
| the first snapshot, whole: 5,525 bytes | in fragments, every object known 683 ms in; the largest datagram 1,200 bytes | put back together; no datagram over 1,200 |
| the most a reconciliation moved a player | 0.0009 mm | the TCP run's centimetre |
| a client's own player at rest against the host's | 0.0004 mm | 1 mm |
| sixteen moving objects drawn against the host at the view time (150 ms behind) | within 6 mm on 205 of 210 steps, 12.5 mm at worst, where two snapshots in a row were lost | 6 mm on 90%, and the chord of the longest gap always: 12.6 mm for two |
| the host, to two clients | 70.7 KB a second in 827 datagrams: snapshots 24.4, events 39.5 (the block 39), headers 2.1 (0.08 of them acknowledgement-only datagrams), sent again 3.7 | |
| a client | 2.7 KB a second in 439 datagrams: inputs and the acknowledgements on them 0.82, honks 0.19, headers 1.1, sent again 0.02, the rest the link's pings | 8 KB |
| a client that leaves | the host hears it 0.05 ms later, its leave hook called | 100 ms |
| a host that falls silent | its client gives it up 1,017 ms in, a timeout of 1 s | 1 s to 1.3 |
| a handshake nobody answers | given up 516 ms in, a timeout of 0.5 s | 0.5 s to 0.7 |

A resend is 9% of the reliable bytes here, where 10% of datagrams are lost. Before the resend timeout took half the round trip as its floor, a third of the block went twice; before a burst was acknowledged every 16 packets and a late packet on its own, most of it did. Before the host kept a client's commands by sequence, a command the link reordered behind a later one was skipped, and a reconciliation moved a player 42 mm; while an input carried only the newest four commands, a macOS runner lost every copy of one and a reconciliation moved a player 37 mm.

`tests/test_net_budget.ae` runs 500 objects over a field 380 m by 300 m, every one turning on a circle of its own so every one always has something new, a host and four clients standing apart over 50 ms, 10 ms of jitter and 2% loss; relevance 60 m; a budget of 400 bytes a tick for three clients and 250 for the fourth; client 1 walks at 5 m/s toward a crate 80 m off. Each run is eight seconds, with the budgets and without:

| | With the budgets | Without | Held to |
|---|---|---|---|
| a client's largest snapshot | 386, 375, 374 and 249 bytes | 763, 776, 776 and 756 | within its budget, and the budget binding |
| a client's snapshots | 10.7, 10.5, 10.5 and 7.0 KB a second | 16.9, 17.0, 16.5 and 15.4 | |
| the object at a player, waiting | a tick at most | never | a tick |
| the slowest of the 43 objects within client 4's relevance | 4 ticks | never | half a second |
| an object 250 m from every player | never sent | never sent | never |
| one set always relevant, one never | at all four; at none | | |
| the crate ahead, first held by client 1 | 59.5 m off | 59.7 m off | before it is within the view, 50 m |

`tests/test_net_delta.ae` holds the deltas to the host's state, and measures what they save:

| | Measured | Held to |
|---|---|---|
| over UDP, 50 ± 20 ms and 10% lost, 50 objects moving, 50 still, three players walking: every snapshot a client takes against the host's state at its tick | 115 and 108 snapshots, 11,726 and 11,016 object states, none different | every object, to the bit of its quantised values |
| acknowledgements sent on their own by two clients with players | 0 bytes | next to nothing |
| a client that acknowledges nothing for 1.5 s, then does | 17 whole snapshots in and after the gap, then 60 compared, none different | whole past the ring, the host's after it |

The snapshot bytes, over the loopback with 50 ± 20 ms and 10% lost, the two seconds after the first, fifty crates in every scene:

| Scene | Deltas | Whole snapshots | The floats before (31 bytes an object) |
|---|---|---|---|
| still | 0.5 KB a second (the header, 17 bytes a tick) | 23.9 KB | 46.0 KB |
| a player walking among them | 0.67 KB | 24.4 KB | 46.9 KB |
| fifty moving and turning among them | 19.7 KB | 48.4 KB | 91.4 KB |

`tests/test_net_horde.ae` runs a host and two clients, and a third that joins 4.5 s in, each with a horde of 3,000 and a flow field of its own, over 100 ms latency, 20 ms jitter and 2% loss, the seals hashed every tick. The target is set six times, forty zombies are killed, and sixty are hit, eight a second: six zombies shoved up to 6 m/s and stunned half a second, and twice a second zombie 100 again, stunned a second, so each hit on it lands while the last still holds it:

| | Measured | Held to |
|---|---|---|
| the same horde, 90 ticks alone and over four threads | 0 of 15,000 doubles differ | 0 |
| a zombie hit at 4 m/s for half a second, alone | carried 1.06667 m along the hit and 0 across it, its heading and walk held, the stun over on its 15th tick | 4 dt (n + 1) / 2 to 1 nm |
| a client's horde against the host's at the tick it is at, every frame | client 2: 495 frames at 224 ticks, up to four zombies under a shove at once; the late client: 249 frames at 101 ticks; every one the same | all |
| the seals' hashes | 224 ticks on client 2, 101 on the late client, none different | none |
| every side at the host's last tick, the columns compared whole | the same to the bit, 2,960 zombies | |
| client 1, one zombie nudged a millimetre | found at the next tick, the state asked for once, the host's horde again 16 frames (267 ms) later, the other clients snapped with it and none off | once, 40 frames |
| the late client | the state, 30,167 bytes for 2,980 zombies and four shoves (10.0 bytes a zombie, where the doubles were 95,711 bytes), 250 ms after it joined; its first tick checked 350 ms after | under 10.1 bytes a zombie; two trips (275 ms); 500 ms |
| a client's horde, seals hashed every tick | 783 bytes a second, 200 of them the hits, where snapshots of every zombie would be 2.6 MB | 1 KB |
| a tick of 3,000 zombies on this machine, over four threads | 0.19 ms | |

The two ways to give a joiner a quantised state, measured the same way: a host and a client, and a third that joins 2 s in, the seals hashed once a second (the default), the target moving and six zombies hit a second:

| | (a) every peer snaps at the join tick | (b) the joiner takes it, the next hash check puts it back |
|---|---|---|
| the state | 30,327 bytes | 30,319 bytes |
| joined to holding the host's horde from then on | 267 ms, as its state arrives | 1,083 ms |
| the horde's bytes it had received by then | 30,327 | 126,963 (the doubles, 96 KB, on top) |
| its frames off the host's horde | 0 | 37 |
| divergences, resyncs | 0, 0 | 1, 1 |
| the client there before it | 0 divergences (a snap is 8 bytes) | 0 divergences |

(a) is what the horde does: exact from the first tick, a quarter of the bytes and 800 ms sooner. (b) starts off by up to half a step of the grid (3.6 µm here), half a step of a heading and of a phase, and is off in every frame until the check finds it and the doubles arrive.

Over TCP on this machine, a client that joins half a second in takes the state framed on the stream, 30 KB, and both clients end at the host's last tick with its horde to the bit.

`tests/test_net_handover.ae` runs a horde of 48 of the box man on a ground, a pool of four figures on every side, a host, a client from the start and a third that joins mid-handover, over 100 ms, 20 ms of jitter and 2% loss, on the test's clock, the seals hashed every tick. The host strikes the last zombie hard (it falls, gets up and goes back), shoves another (it staggers and goes back), kills a third (it lies and is despawned), and kills the first zombie in the horde, so the one it struck hard moves to its index while handed over:

| | Measured | Held to |
|---|---|---|
| the first zombie out | tick 15 on the host and on the client | the same tick |
| the client's horde against the host's, every frame, handed over and given back | 735 frames, none different, none with a different count out; 344 seals, none diverged | all |
| the client that joins mid-handover | three out at its first tick; 609 frames, none different; 281 seals, none diverged | the flags from its first tick |
| the struck zombie on the client, drawn in its horde or as its figure | 707 frames watched, its figure 361 of them; both 0, neither 0 | never both, never neither |
| its figure's pelvis against the host's ragdoll at the client's view time | within 2 cm on 359 of 360 frames, 21.6 mm at worst | 2 cm on 95% |
| the zombie killed while handed over | compacted at tick 105, when its figure was despawned, on every peer | at one tick |
| the zombie moved to index 0 while handed over | kept its figure, and was given back there | |
| a ragdoll's bones to a client | 4.4 KB a ragdoll a second | 6 KB: twelve bones' records at most, 30 a second |

`tests/test_determinism.ae`, on this machine: the horde's tick 180 hashes to 5549349224744341822 at one thread and at four, a client joining at tick 90 holds it in every frame after; the ragdolls sleep at step 332 with the same hash twice. Across the three CI runners, above.

The editor's play (#476, [editor.md](editor.md)): a bounded run with a host and two clients draws each of the three worlds, welcomes both clients, and after the players walk and stand holds a client's own player within a micrometre of the host's and the others it draws within 43 µm (the precision); W held in client 2's view walks client 2's player and no other; and Stop leaves nothing behind -- every session and hub freed, the renderer's models and the editor's engine's objects back to their counts, every networked row where it stood.

`tests/test_net_fields.ae` runs a host and two clients over loopback UDP, 50 ms ± 20 each way and 10% of datagrams lost, twelve crates with a field of every kind changed on schedules of their own, a mover whose place jumps with a field, every player's health, and a rocket created two seconds in whose fuel burns, then destroyed; then the same scene within a budget over the loopback, and what fields cost:

| | Measured | Held to |
|---|---|---|
| every field of every object a client has, at every frame, against the host's at the tick of its newest snapshot | 25,176 and 24,500 values over 329 and 320 frames, none different: a stepped float the host's steps times its precision, the same bits; one sent whole, the host's bits | every one, bit for bit |
| the hooks | 564 changes on the host; 564 hooks on each client, each matched to its change in order, with its value, none missed, none extra, none at a tick before the change | once a change, in order, nothing else |
| a client's own player's health | 79 on the host and in both clients' hooks | its fields reach it |
| the rocket's fields | made once on each client with the rocket, and gone with it: none left | come and go with it |
| within a budget of 120 bytes, a field and its transform | the largest snapshot 118 bytes, objects waiting up to 13 ticks; in the snapshot of every one of the stage's 20 changes, the mover's place the stage's; none seen backwards; the client ends at the host's stage | always together |
| six fields standing still on twenty moving objects, over 50 ms and 10% lost | 8,077 bytes of snapshots in two seconds, the same to the byte as with no fields; changing every step, 26,137 (8.8 KB a second more) | 0 bytes |
| what cannot be | a name twice, a float with nowhere to keep it, a text given a place, a text over 31 bytes, a field after the first tick: refused | refused |

`tests/test_net_sight.ae` runs 500 objects in a street of buildings, 250 on the road and 250 in the yards behind, every one moving every tick, a host and two clients standing mid-street looking opposite ways along it, a budget of 900 bytes a snapshot, over the loopback's 50 ms, 10 ms of jitter and 2% lost; each wait measured by the test from the tick each object was last sent, settled and before the turn:

| | By sight | By distance alone, the same budget | Held to |
|---|---|---|---|
| the most ticks in a row an object a client can see waited | 1 and 1 | 4 and 4 | a tick |
| an occluded one, and one out of view | 18 ticks (0.6 s), and 18 | 4, and 4 | longer, a second and a half at most, and never unsent: none was |
| client 1 turns round: the 125 objects newly in its view | the last of them sent a tick after the first tick judged by its new view | | 2 ticks |
| the record bytes client 1 was sent of what it could see | 69% of them | 25% | most of them, and more than twice distance alone's |
| the host's rays, and its step | 228 rays a tick for the two clients; its step 0.11 ms a tick, against 0.11 by distance alone | | stated |

`tests/test_agent_net.ae` and `tests/test_net_authority.ae` hold the channel and the corrections to their numbers, above ([The link, measured](#the-link-measured), [Who simulates what](#who-simulates-what), [Time and interpolation](#time-and-interpolation)); `examples/net_street.ae` the street ([The street, played by sixteen](#the-street-played-by-sixteen)).

## Next

Everything #413 asked for is built but Steam's sockets (SteamNetworkingSockets, with its lobbies and NAT traversal) behind the same calls, which want Valve's proprietary Steamworks SDK, not available to this project or its CI ([#483](https://github.com/nicolas-maman/ae3d/issues/483)). Past #413: a destroyed object's id given again once every client has a snapshot without it; lag compensation, which rewinds to `view_time`; for the horde, the late joiner's state compressed on top of its quantising (zlib would probably halve it again).
