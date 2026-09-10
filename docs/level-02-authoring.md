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
- `Enemies`: eleven existing Guard/Gunner instances.
- `Entities/Player` and `HUD`: the shared player and interface.

A/D move, Space jumps, J attacks, and K stops time. Electrical barriers are
always active, including during time-stop. Contact deals 25 damage; remaining
inside causes another hit every second. The four-frame electricity animation
loops at 16 FPS, including during time-stop. Jump over the visible electricity.
The freight deck still stops on the world clock. Falls cost a life and use the normal retry
system. Supply chests heal 50 health, open only when useful, and reset on retry,
like the existing healing pickups. The gate completes the level without requiring
all enemies to be defeated.

Keep enemy paths and checkpoint names stable during tuning: they identify saved
retry progress. The shared lifecycle now selects the scene's phase before using
checkpoints, and clears a checkpoint from another phase when switching scenes.

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
and scene contracts. The tests use the saved map, including the repositioned
cache platforms; hazard checks hold the player in contact to isolate repeated
damage from knockback. Headless runs can report audio-resource cleanup warnings
and a macOS certificate diagnostic; these are separate from assertion results.

The capture helper writes six gameplay screenshots under the ignored
`builds/level-02-review/` folder. Existing captures and exports are local review
artifacts and may predate the latest scene edits.

`tools/level_02/build_initial_map.gd` records the original authoring recipe and
now uses the reusable object scenes.
It overwrites the saved scene and tileset when explicitly run with `--replace`;
keep manual edits in the scene and do not regenerate it during normal editing.

