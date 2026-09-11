![](assets/intro/logo.png)

A 2D action-platformer built with **Godot**.

Play as a boy fighting through Cad Corp to find his family. His father's clock
can stop time, but every use costs years of his life. Defeating enemies gives
some of those years back, turning time into both a weapon and the game's main
resource.

## Project status

The project is an in-development prototype with a playable first level,
**Garbage Eden**. It currently includes:

- Responsive platforming, crouching, and melee combat
- A five-second time-stop ability with an age cost and cooldown
- Melee Guards and ranged Gunners
- A compact salvage yard: shuttle ride, freight lift, and two-deck transfer
- A fast, timed transfer above a spike pit and an optional healing ledge
- Checkpoints that preserve age and defeated enemies between retries
- Hazards, moving traps, and healing fig pickups
- The existing final chamber, reshaped into a compact two-torch boss arena with the Iron Titan encounter and sister rescue ending
- Intro, main menu, HUD, music, sound effects, and persistent settings

Only time stop is available in the current level. Rewind and slow-time inputs
exist in the project, but their gameplay is not yet available.

City of Time currently has a title screen only. It returns to Level 1; a playable
second level has not been added yet.

## Running the game

1. Install [Godot 4.7](https://godotengine.org/download/).
2. Clone the repository:

   ```bash
   git clone https://github.com/Zeyadzahran/years-to-spare.git
   cd years-to-spare
   ```

3. Import `project.godot` into Godot.
4. Press **F5** to run the project.

The game starts at `src/cinematics/logo/logo.tscn`. The playable level is
`src/levels/level_01/level_01.tscn`.

All Level 01 layout is stored in that one scene. `World/SalvageYard` is a
normal node group inside it, containing the later sections. Reusable actors,
platforms, hazards, and the background remain separate reusable scenes.

For level work, open `src/levels/level_01/level_01.tscn` and use **Run Current Scene**
(F6), which skips the menu and story. To capture 15 views of this level directly:

```bash
python3 tools/capture_level.py
```

This uses Godot to render at the gameplay camera zoom and Python's standard
library to build `builds/level-review/index.html`. No Python packages are needed.
Use `--godot /path/to/godot` if Godot is not on your PATH or in `/Applications`.
Captures need a graphical session; use headless mode for the physics checks.

The final transfer has two fast decks around a permanent middle platform.
Time the stop so the incoming deck is high enough to reach the middle platform,
but still low enough to board from the bank. One well-timed five-second cast
(cost: three years) can cross both decks. The middle platform is safe to wait on
if another cast is needed. Spikes cover the pit and remain lethal while frozen;
a missed jump returns to the transfer checkpoint, preserving spent years.

For the current transfer challenge:

```bash
godot --headless --path . --fixed-fps 60 tests/level_01/verify_transfer_timing.tscn
python3 tools/capture_level.py --only 05,06,07 --output builds/transfer-review
```

The test uses the real input, wind-up, player controller, and five-second power
window at starting ages 23 and 53. It also checks that mistimed frozen positions
are unreachable and that the spike floor has no safe gaps. All previews load
Level 01 directly. The layout draft tool exports the current scene, including
manual edits, instead of rebuilding an older copy of the layout.

## Controls

| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Move | `A` / `D` or arrow keys | Left stick |
| Jump | `Space`, `W`, or up arrow | A / Cross |
| Crouch | `S` or down arrow | D-pad down |
| Attack | `J` or left mouse button | X / Square |
| Stop time | `K` or right mouse button | Left shoulder |
| Pause / options | `Esc` | Start |

The intro can be skipped by pressing any keyboard key.

## How time works

The player begins at age 14 and dies of old age at 60. Casting time stop costs
three years, freezes the world for five seconds, and then enters a three-second
cooldown. Defeating an enemy restores one year, while figs restore health.

A normal death returns the player to the latest checkpoint without restoring
spent years or respawning defeated enemies. Dying of old age clears that run's
progress and starts the level again.

## Project structure

```text
assets/                  Shared actor art, fonts, music, sounds, and input icons
autoload/                Event bus, run progress, world time, settings, and music
src/
  actors/                Player and enemies, with their scenes and scripts
  cinematics/            Logo and story intro, each beside its script
  components/            Health, age, and time powers
  core/                  State machine and time-aware body classes
  levels/
    level.gd             Shared level lifecycle and retry handling
    level_01/
      level_01.tscn      Gameplay layout: terrain, hazards, actors, and checkpoints
      shaders/           Scrap background depth shader
      props/             Reusable decoration scenes
      hazards/           Level 1 hazard scenes and animation resources
      art/               Background, terrain, prop, and hazard images
      audio/             Level ambience
      background.tscn    Parallax background
      terrain_tileset.tres
  ui/                    HUD, options, credits, main menu, and configurable level titles
  world/
    checkpoints/         Checkpoint scene, script, and marker animation
    pickups/             Healing pickup scene and script
    platforms/           Static, moving, falling, and blinking decks
    exits/               Exit gate and completion screen
    hazards/             Shared hazard behavior
docs/                    Level authoring guide and refactor validation notes
tests/                   Scene contracts and Level 1 physics checks
tools/                   Python preview command and grouped authoring helpers
```

See [Level authoring](docs/level-authoring.md) for where to place decorations,
how the layers work, and which names must remain stable.

All gameplay and decoration placements stay in `level_01/level_01.tscn`.
Use `World/Decorations` for the opening and `World/SalvageYard/Decorations`
for the later section. Reusable scenes in `props/` are available for new scenery.
Ambience, terrain seam patches, checkpoints, and salvage-yard objects have
separate scene-tree groups. The exit checkpoint has its own unique name.

Keep existing enemy paths and checkpoint names stable: retry progress uses them
to remember defeated enemies and the active checkpoint.

## Validation and Web export

After importing the project, run the scene checks from the project root:

```bash
godot --headless --path . --script tests/scene_contracts.gd -- --level-only
```

The command checks scene loading, retry identities, checkpoint recovery, and
completion while running Level 1 directly. Omit `-- --level-only` to include
startup, credits, and title navigation. Focused physics checks live in
`tests/level_01/`; authoring helpers live in `tools/level_01/`. Existing shutdown
resource diagnostics are separate from assertion failures.

Install the export templates matching your Godot version, then use the `Web`
preset in **Project → Export**, or run:

```bash
mkdir -p builds/web
godot --headless --path . --export-release Web builds/web/index.html
python3 -m http.server 8000 --directory builds/web
```

Open `http://localhost:8000` to play the exported build. Replace `godot` with your
Godot executable path if it is not on your PATH. The preset uses Compatibility
rendering and a single thread. Web builds render at the base viewport resolution
before scaling to the browser window; desktop builds retain canvas-item scaling.

## Architecture rule

Do not use `Engine.time_scale` for gameplay. The player must keep moving at full
speed while the world is frozen.

Anything affected by time powers should extend `TimeBody2D` or use
`TimeService.world_delta(delta)`. Player-controlled and UI code should use the
raw delta when it needs to continue during a time stop.

## Adding gameplay

| To add | Where to start |
| --- | --- |
| A player state or ability | Add a `State` under `src/actors/player/states/` and register it in the player's `StateMachine` |
| A player animation | Add the clip to `player_frames.tres` and map it in `PlayerAnimator.STATE_CLIPS` |
| An enemy type | Extend `Enemy`, configure its stats, and implement `_attack()` |
| A Level 1 decoration | Add a reusable scene under `src/levels/level_01/props/`, then place it in a decoration group in `level_01.tscn` |
| A level exit | Instance `src/world/exits/level_exit.tscn` under a `Level` root to show completion when crossed |
| A level title | Use the scenes under `src/ui/level_title/` and set the root's `next_scene` |
| A time-aware world object | Extend `TimeBody2D` or request scaled delta from `TimeService` |
| A cross-system event | Add a signal to `EventBus` and connect the interested systems |
| Another level | Add it to `GameState.LEVELS` and create its scene under `src/levels/` |

## Level 2 development scene

Open `src/levels/level_02/level_02.tscn` and run the current scene to play Level 2, an industrial map with eleven enemies, five checkpoints, supply caches, electrical traps and a moving freight crossing. The main menu continues to start Level 1. See [Level 2 authoring](docs/level-02-authoring.md) for the layout, editing notes and verification commands.

Level 2 gameplay objects are reusable scenes under `src/levels/level_02/objects/`, with shared decorations under `props/`. Edit a source scene to update every placement, or use the Inspector on one instance for local settings.
