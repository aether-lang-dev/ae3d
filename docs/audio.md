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

## Not yet

Sounds from the engine's own systems (rain, wind, thunder delayed by the
strike's distance, the car's engine, physics contacts) are #566. The
editor's inspector section is #567. OGG Vorbis is aether#2364.
