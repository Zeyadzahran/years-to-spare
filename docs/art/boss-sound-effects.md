# CAD owner fight sound effects

User-supplied originals: `/Users/r6mez/Downloads/boss-sound-effects`. Originals are unchanged. Runtime WAV copies live in `assets/sounds/cad_owner/`. Original filenames are retained below.

The two named cut requests use only their first cue. Hurt and death lose leading silence. The platform drop condenses the descending effect to fit the 1.3-second fall. All clips have short fades and are mono. Peaks target -4 dB except the platform drop (-3 dB) and enemy spawn (-1 dB).

| Output | Original filename | Source interval | Tempo | Runtime length |
|---|---|---|---|---|
| `charge.wav` | `charging-lazer.mp3` | 0.00–0.75s | 1x | 0.75s |
| `shot.wav` | `lazer-shoot.mp3` | 0.00–1.10s | 1x | 1.10s |
| `hurt.wav` | `getting-hurt.mp3` | 0.50–1.25s | 1x | 0.75s |
| `platform_drop.wav` | `eldadtsabary-descending-pitch-lost.mp3` | 2.20–10.20s | 6.154x | 1.30s |
| `appear.wav` | `scary-appear-sound.mp3` | 0.10–2.60s | 1x | 2.50s |
| `portal_open.wav` | `portal-appearing.mp3` | 0.00–3.20s | 1x | 3.20s |
| `enemy_spawn.wav` | `going-through-portal-jump (cut first part only).mp3` | 0.00–0.65s | 1x | 0.65s |
| `disappear.wav` | `dragon-studio-scary-chimes-(needs to be cutted).mp3` | 0.00–1.75s | 1x | 1.75s |
| `death.wav` | `boss-dying.mp3` | 0.38–4.80s | 1x | 4.42s |

Charge plays at a pitch ratio that fits the 0.65/0.75-second windup and stops when the laser fires. Shot supports three overlapping tails for bursts. Hurt, departure and arrival are boss-local sounds. Portal opening and enemy spawn are separate players; only opening plays the opening cue. Scary chimes play whenever the boss disappears, including repositioning. There is no separate phase-chime trigger. The descending sound starts at the final platform fall and stops on impact. Death plays on the arena, so retiring the boss does not cut off its tail. Rewind stops pending sound effects without restarting the battle music; Stop Time pauses them.

Validation: all nine imported WAVs produced non-silent, unclipped samples through Godot CoreAudio capture. The boss-audio, combat-polish, time-regression and ending-sequence suites passed with zero assertion failures.

Fight mix: battle music is -19 dB (12 dB lower than the prior mix). Boss, portal, death, laser impact and final platform impact effects are raised by 5 dB. The recut spawn cue uses a non-positional player at -1 dB so it remains audible across the arena; its combined asset/player gain is 6 dB above the previous cut. Other levels and the user’s volume settings are unchanged.
