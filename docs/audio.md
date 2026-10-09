# Audio

`ae3d.audio` puts sound in the world (#415): sources on game objects, a
listener on the camera, four buses, over `std.audio`'s mixer (miniaudio,
vendored in Aether's standard library).

```aether
audio.attach(e)                                    // once, beside physics.attach
src = audio.source(car, "sounds/engine.wav", audio.EFFECTS)
audio.set_looping(src, true)
audio.set_distances(src, 2.0, 80.0)
audio.play(src)

audio.set_bus_volume(e, audio.MUSIC, 0.6)
audio.duck(e, audio.MUSIC, audio.VOICE, 0.35)      // the music under a line of dialogue
```

## Sources and the listener

An AudioSource is a component, like Unity's: it is taken off with its
object, and its sound goes with it. Clips are WAV, MP3 or FLAC (OGG Vorbis
waits on aether#2364). A clip's encoded bytes are read once per path, and
each source decodes them as the mixer pulls, so a long ambience costs its
file's size, not its decoded one.

After the frame's updates, in the late phase, the engine places every
spatial source against the listener. The listener is the camera, or an
object given to `set_listener` (a player's head). `engine_update` runs the
late phase too, so the editor's engine places sources as the game's loop
does.

- **Distance.** Full volume within `min_distance`, then `min / d`, the
  inverse of the distance (the physical falloff, and Unity's logarithmic
  rolloff). Held at its value at `max_distance` beyond that.
- **Pan.** Equal-power, from the source's direction across the listener's
  right: hard left at 90 degrees left, centred ahead and behind.
- **Doppler.** `f' = f (c - v_l.u) / (c - v_s.u)`, where `u` runs from the
  source to the listener, `c` is 343 m/s, and each velocity is its object's
  movement over the frame. `set_doppler` scales the shift (0 turns it off),
  and the pitch is kept between half and double.

A source that is not spatial (music, a voice in the player's head) plays
centred at its own volume.

## Buses

MUSIC, EFFECTS, AMBIENCE and VOICE are `std.audio` groups, each with a
volume that multiplies its sources'. `duck(e, bus, under, amount)` lowers
`bus` to `amount` of its volume while any source on `under` plays, easing
in and out over a quarter of a second.

## Devices

`attach` opens the sound device. `AE3D_AUDIO=0` opens none and every call is
silent. A machine with no device runs as if `AE3D_AUDIO=0` were set.
`AE3D_AUDIO=headless`, or `attach_headless(e, rate)`, opens a mix that only
advances when it is rendered (`std.audio.render`). That is how a mix is held
to numbers, the way a frame is held to pixels.

## Measured

`tests/test_audio.ae` uses a headless engine stepped by hand and a
constant-sample tone, so a rendered block's peak is the gain and the pan
exactly:

| What | Number |
|---|---|
| Distance (min 2 m, max 40 m) at 1, 2, 4, 8, 40, 80 m | gain 1, 1, 0.5, 0.25, 0.05, 0.05, in the gain applied and in the rendered peak |
| Dead ahead | 0.35353 each side: the tone's 0.5 times cos(pi/4) |
| 90 degrees right | left 0, right 0.49997 |
| Crossing in front, -4 m to +4 m | pan rising monotonically from left to right, equal sides at the middle |
| A car passing at 30 m/s, 5 m aside | 1.09571 coming (the formula's 1.09572), 0.919662 going (0.919663) |
| Effects bus at half volume | the effect at half, 0.17677; the music untouched |
| Two centred sources | 0.70706, the two summed |
| Music ducked under a voice to 0.35 | 0.35 while the voice plays, 1 after it |
| 258 sources placed | 0.023 ms a frame at worst |

## The world's sounds

`ae3d.worldsound` (#566) gives the engine's own systems a voice:

```aether
ws = worldsound.attach(e)              // after physics.attach
worldsound.follow_weather(ws, w)       // rain, wind, thunder
worldsound.car(ws, vehicle)            // an engine pitched by the car's speed
worldsound.hits(ws, true)              // physics contacts
```

The sounds are made in Aether, not read from files, so a program needs no
assets for them and every run hears the same samples:
- **Rain:** two seconds of lightly smoothed noise, looped.
- **Wind:** four seconds of heavily smoothed noise swelling twice, looped.
- **Thunder:** three seconds of low noise that cracks in and rolls off;
  from a strike past 2 km (`NEAR_THUNDER`), lower noise that swells in over
  a third of a second and rolls on, with no crack.
- **Engine:** one exact cycle of a 50 Hz tone and five harmonics, looped.
- **Hit:** an eighth of a second of noise dying away.

Rain, wind and thunder play on AMBIENCE and are not spatial. Engines and
hits play on EFFECTS, placed where they are.

- **Rain and wind.** The rain's volume is the weather's intensity (in rain
  and storms). The wind's is its speed over 25 m/s; a storm gusts at 1.8
  times its wind.
- **Thunder.** Each lightning flash now records how far off it struck, half
  a kilometre to six (`weather_strike_distance`). Its thunder is heard that
  distance over 343 m/s later, at a volume of 1000 / d, kept between 0.15
  and 1. `thunder_last_distance` and `thunder_last_far` say which strike
  the last one heard came from, the frame `thunder_started` counts it.
- **Engines.** The pitch is 0.8 + 0.05 times the speed, at most 2.4.
- **Hits.** A frame keeps its strongest physics contacts, at most four
  (`MAX_HITS`), and starts them at their points. Volume is the approach
  speed over 8 m/s, and a harder strike is pitched lower.

A game with weather sounds of its own plays them on the same clock (#631):

```aether
worldsound.set_weather_sounds(ws, "rain.wav", "wind.wav", "thunder_near.wav", "thunder_far.wav", 2000.0)
```

Each path replaces the made sound (`""` keeps it). Thunder from a strike
nearer than the distance plays the near clip, further off the far one.

`tests/test_worldsound.ae` checks each of these headless:
- rain at 0.5 is gain 0.5, and 0 cleared; wind at 10 m/s is 0.4;
- the rain is in the rendered mix;
- a strike 5,981 m off is heard after 17.45 s (17.44 s by the speed of
  sound, within a frame);
- the engine pitch is 1.30456 at 10.09 m/s, exactly 0.8 + 0.05 v;
- twelve dropped crates are heard 25 times, never more than 4 in a frame;
- a game's rain clip, every sample 0.2, peaks at 0.1414 in the mix at full
  rain (0.2 centred); its near thunder at 0.6 and far at 0.3 play as 0.424
  and 0.212 over their volumes.

## In the editor

`audio.register_kind()` makes **Audio Source** a component kind (#567).
Its fields are the source's own: clip (a sound asset), bus, volume, pitch,
loop, spatial, min and max distance, Doppler, and play on start. The
inspector shows them, the scene file keeps them, and the agent's
`component.get` and `.set` reach them. The component binds to the engine's
sound in its start phase: the clip is loaded, the source is placed from then
on, and it plays if it starts with the play. A field written through the
registry applies at once.

The editor registers the kind and attaches sound to its viewport engine,
with the listener on the editor's camera. Every bus is muted
(`audio.set_muted`) while the scene is edited and unmuted while Simulate
runs.

`tests/test_audio` adds an Audio Source as the inspector does and checks
that it binds, plays and is placed (gain 0.5 at 4 m with min 2), that a
volume write applies at once (0.25), and that its fields go through the
scene file's JSON and back. The editor driver adds one to a cube through
Add Component, checks it offers every bus, saves, and finds the component
and its fields in the file.

## Not yet

OGG Vorbis is aether#2364.
