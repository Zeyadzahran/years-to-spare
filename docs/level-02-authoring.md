# Level 2

Open `src/levels/level_02/level_02.tscn` and choose **Run Current Scene**.
On macOS the configured Godot shortcut is shown beside the run control.
The main menu still starts Level 1; Level 2 is a separate scene for development.

The map is 8,960 pixels wide. The level scene stores placements and tile cells. Repeated objects are instances
of reusable scenes. No runtime generator rebuilds the layout.

| Section | World X | What happens here |
| --- | --- | --- |
| Entry street | 0–1,408 | First patrol, stepped supply cache, short gap |
| Machinery yard | 1,600–2,880 | Cargo obstacle, upper route, first electrical trap |
| Rooftops | 3,072–4,416 | Guards, raised cache, approach to freight crossing |
| Freight crossing and landing | 4,416–6,208 | Moving deck, checkpoint, upper overlook, electrical trap |
| East courtyard and exit | 6,400–8,960 | Crate and rooftop route, final gap, guards and exit |

## Scene groups

- `Background`: sky and four repeating parallax layers.
- `World/Terrain/IndustrialTiles`: painted `TileMapLayer`, 64-pixel world cells.
- `World/Platforms`: five static ledges and the freight shuttle.
- `World/Obstacles`: two solid cargo crates and the side boundaries.
- `World/Decorations`: pipes, machinery, pylons and scattered debris.
- `World/Checkpoints`: five uniquely named Level 2 checkpoints.
- `World/Supplies`: five healing chests, including three elevated caches.
- `World/Hazards`: four electrical barriers and the fall-reset area.
- `World/Wayfinding`: in-world instructions and district signs.
- `World/Exit`: the completion gate and its Level 2 panel.
- `Enemies`: ten Guard/Gunner instances and one stationary Robot.
- `Entities/Player` and `HUD`: the shared player and interface.
- `Tutorial`: one decorative Rewind sign floating over the entry street.

A/D move, Space jumps, J attacks, and K stops time. Electrical barriers are
always active, including during time-stop. Contact deals 25 damage; remaining
inside causes another hit every second. The four-frame electricity animation
loops at 16 FPS, including during time-stop. Jump over the visible electricity.
The freight deck still stops on the world clock. A fall the clock can catch
triggers a rewind instead of dying (4 years, no heart lost); anything else,
or a fall with Rewind on cooldown or unaffordable, costs a life and uses the
normal retry system. Supply chests heal 50 health, open only when useful, and reset on retry,
like the existing healing pickups. The gate completes the level without requiring
all enemies to be defeated.

Keep enemy paths and checkpoint names stable during tuning: they identify saved
retry progress. The shared lifecycle now selects the scene's phase before using
checkpoints, and clears a checkpoint from another phase when switching scenes.

## Rewind lesson

The entry street mirrors how Level 1 introduces time-stop: a guide card, then
an existing obstacle that teaches it. The boy spawns at the street's west end
with Stop and Rewind already granted.

- `Tutorial/Rewind` at `(430, 380)`: a single decorative sign floating above
  the street - `REWIND`, `L`, `Rewind time`, `4 sec back / costs 4 years`,
  in Rewind silver, all centred (`centered = true`: heading, key and text
  aligned to the card's middle, key on its own line). The StreetPatrol
  guard at `(797, 639)` is the classroom: trade a hit, press `L`, and the
  wound, positions and spent moments rewind four seconds. The street gap
  (`1370–1635`) and the `YardPulse` trap at `(2349, 644)` are unmarked
  practice: miss the jump or walk into the sparks, press `L`, and it never
  happened - even a lethal fall can be rewound out of during the collapse.

The sign is a static world-space drawing with no collision, so it cannot
affect movement, physics checks or retry identities. The `centered` flag is
opt-in; Level 1's cards keep their left-aligned look.

Cheating death is automatic, not only manual: `FallReset` carries
`cheat_fall = true`, so a lethal fall casts Rewind on the boy's behalf while
one is ready - winding up as he keeps falling, then standing him back on
solid ground four seconds back, billed 4 years with no heart lost. Support
lives in `TimePowers.try_cast` (cast by id, refused while another power
runs), `Player.try_cheat_death` (falls only, never combat, never phase 1),
and the `Hazard.cheat_fall` opt-in (chip damage never catches, and contacts
during the wind-up wait their turn instead of killing). Manual `L` presses
during the fall or the collapse still work exactly as before.

## Robot encounter

`Enemies/RoofRobot` replaces the rooftop gunner at `(4120, 512)`. Approach along
the flat roof from the left. Its chest charges, then it fires a fast horizontal
beam. Jump during the charge to clear the shot. A hit is fatal; Rewind during
the player's collapse lets you try again without losing a heart. Stop Time
freezes the robot and beam, but touching a frozen beam is still fatal.

The level's **Debug Spawn Path** is set to `DebugSpawns/RobotApproach` for editor
playtesting. Run the scene with no active checkpoint to start at `(3780, 512)`,
in front of the robot and just outside detection range. Walk right to begin the
encounter. Clear the debug path to restore the entry spawn in the editor;
exported builds still start at the entry.

The reusable enemy is `src/actors/enemy/robot.tscn`. Inspector defaults:

| Setting | Default |
| --- | --- |
| Detection / attack range | 320 pixels |
| Vertical detection / attack tolerance | 110 pixels |
| Attack Hit Time (charge) | 0.65 seconds |
| Attack Duration (charge and firing effect) | 1 second |
| Attack Recovery | 1.25 seconds |
| Beam Speed | 1,200 pixels/second |
| Beam sprite animation | 12 FPS |
| Health | 100; three normal sword hits |

The robot commits to a side when charging and turns again for its next attack.
Sword hits interrupt charging and play Hurt without knockback. Death plays the
supplied collapse animation. Walls block detection and absorb fired beams.
The beam sweeps its full collision shape each physics tick to avoid skipping
through the player or thin walls, and expires after 1.25 seconds of world time.
An amber glow, bright core and fading embers surround the supplied beam sprite.
The dim trail is cosmetic. All animation uses the beam's recorded age, so the
glow and embers stop and rewind with it.

This change is based on Rewind PR #60 (`3d04771`). It uses Enemy's existing
snapshots for the robot and records each beam's position, velocity, age and hit
state. Expired beams and dead robots retire through TimeService so Rewind can
restore them. The charge effect is derived from the recorded attack clock.

The three original PNG sheets are copied unchanged into `assets/sprites/robot/`
from `/Users/r6mez/Projects/Years-To-Spear/Assets/characters/enemies/robot/`.
`robot.png` is the Military Incursion Bot sheet: 160×96 cells, with idle on row 0,
chest firing on row 2, hurt on row 5 and death on row 6 (zero-based rows).
The beam and spawn sheets use 32×64 and 64×64 cells. The `.tres` frame resources
select atlas regions; the PNGs are not cropped or repainted.

The three supplied MP3s are copied unchanged to `assets/sounds/robot/`:

- `yodguard-short-energy-beam-shot-3-482517.mp3`: plays when a beam is fired.
- `floraphonic-metal-hit-95-200424.mp3`: plays on a surviving sword hit.
- `freesound_community-retro-video-game-death-95730.mp3`: plays on death.

All three are positional; adjust their AudioStreamPlayer2D children for volume
and hearing distance. Shot and hurt audio obey the existing enemy time-stop
behavior. DeathAudio uses Pausable processing so its two-second clip can finish
after the shorter collapse animation retires the robot, while still respecting
the pause menu. Rewind stops all three sounds, including a retired robot's death
sound, so sounds from the abandoned attack or death do not resume afterward.

```bash
godot --headless --path . --fixed-fps 60 tests/level_02/verify_robot.tscn
godot --headless --path . --fixed-fps 60 tests/level_02/verify_rewind.tscn
```

The robot check covers range and cover, stationary repeated attacks, charge
warnings, locked horizontal aim, Stop Time, fast collision in both directions,
thin walls, real sword hits, fatal-hit Rewind followed by a successful jump,
robot revival, and restoration of expired projectiles. Native captures of idle,
charging and jumping over the beam are in the ignored `builds/robot-review/`.
These checks verify behavior; final difficulty tuning still needs a human playtest.

## Reusable scenes and Inspector settings

Drag scenes from `src/levels/level_02/objects/` into the level to place another
object. Double-click a scene file to edit its shared art, collision shapes and
children. Those source-scene edits apply to every instance. Select an instance's
root in Level 2 to adjust its exported settings; only that instance is overridden.
Use the Inspector's revert arrow to return a setting to the shared default.

| Scene in `objects/` | Inspector settings |
| --- | --- |
| `supply_chest.tscn` | Heal Amount |
| `pulse_trap.tscn` | Damage, Cooldown, Animation FPS |
| `industrial_ledge.tscn` | Width Tiles, One Way; art and collision resize together |
| `cargo_crate.tscn` | Collision Size, Collision Offset, Art Width |
| `freight_shuttle.tscn` | Size, Speed, Travel, Start At, One Way, motion/orbit settings |

`props/` contains thirteen reusable decoration scenes: pylons, tanks,
transformers, a cargo shed, pipes and scrap piles. Their placements inherit art
from these scenes. `background.tscn` owns the sky and parallax layers. Checkpoints,
enemies, the player, HUD and completion gate already use shared project scenes.

Keep regular edits in these source scenes or the instance's root Inspector.
**Editable Children** is only needed for an intentional one-off child change;
overriding children on every instance would prevent shared edits from propagating.
Resizing a ledge, crate or freight platform changes its own collision resource,
not another instance's shape. The incomplete YardSupply has been replaced by a
complete instance of `supply_chest.tscn`.

`ElectricAudio` loops `assets/sounds/electric-sound.mp3`, including during time-stop.
`OpenAudio` plays `assets/sounds/chest-open.mp3` once when a chest heals the player.
Both use positional audio at 0 dB with a 700-pixel maximum distance. Edit those
child nodes in the reusable source scenes to change the shared volume or range.

## Assets

`src/levels/level_02/art/` contains the supplied PNGs, organized as terrain,
background, pipes, decorations, power lines and animated objects. The original
source is `/Users/r6mez/Projects/Years-To-Spear/Assets/environment/phase-2/`.
Day and night backgrounds and all individual tiles are available. This scene
uses the daytime layers and the original atlas, with nearest texture filtering.
PSD sources remain in the supplied folder. Character and enemy art comes from
the existing project; the phase-2 folder contains environment art.

## Verification and previews

```bash
godot --headless --path . tests/level_02/verify_objects.tscn
godot --headless --path . tests/level_02/verify_supplies.tscn
godot --headless --path . --fixed-fps 60 tests/level_02/verify_level.tscn
godot --headless --path . --script tests/scene_contracts.gd -- --level-only
godot --path . tools/level_02/capture_map.tscn
```

The focused test drives real movement at ages 14 and 60 through all four required
terrain gaps, the cargo obstacle and both street/roof cache steps. It checks
all enemy footing, attacks against a placed guard, freight carrying and freezing,
continuous trap damage during normal and stopped time, chest healing, checkpoint/age/enemy persistence, the
completion panel, and returning to Level 1 state. This is focused automated
coverage, not a complete human playthrough or final difficulty balancing.

Current PR checks on Godot 4.7.2: reusable objects, all five supply-chest
contacts and HUD updates, 18 movement routes (ages 14 and 60), gameplay lifecycle,
and scene loading. The tests use the saved map, including the repositioned
cache platforms; hazard checks hold the player in contact to isolate repeated
damage from knockback. Headless runs can report audio-resource cleanup warnings
and a macOS certificate diagnostic; these are separate from assertion results.

All Level 2 suites pass after integrating `main` at `cf19ef2`. The earlier base
passed 59 scene contracts. The current repository-wide contract run is blocked
by Level 1 references to missing boss-room/toxic-water scripts and a shader,
plus its replaced exit path. The Level 1 boss check also reports a camera-zoom
assertion. Those Level 1 files match the base branch and are outside this change.

The capture helper writes six gameplay screenshots under the ignored
`builds/level-02-review/` folder. Existing captures and exports are local review
artifacts and may predate the latest scene edits.

`tools/level_02/build_initial_map.gd` records the original authoring recipe and
now uses the reusable object scenes.
It overwrites the saved scene and tileset when explicitly run with `--replace`;
keep manual edits in the scene and do not regenerate it during normal editing.

## Finale

Winning the Owner fight runs the existing platform drop and walk to the
parents chamber, then leaves for `src/cinematics/finale/finale.tscn`: the
four `assets/cut-scene-l02` stills in numbered order (freed, happy, tired,
going away), then a black screen holding one low line (`Still worth it, my
best resource.`), ticking with the clock sound, then the credits, then a
black `THE END` card. Enter skips everything to the card; another Enter
returns to the main menu. Clicks and taps never skip.
