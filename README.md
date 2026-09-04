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
- Checkpoints that preserve age and defeated enemies between retries
- Hazards, moving traps, and healing fig pickups
- Intro, main menu, HUD, music, sound effects, and persistent settings

Only time stop is available in the current level. Rewind and slow-time inputs
exist in the project, but their gameplay is not yet available.

## Running the game

1. Install [Godot 4.7](https://godotengine.org/download/).
2. Clone the repository:

   ```bash
   git clone https://github.com/Zeyadzahran/years-to-spare.git
   cd years-to-spare
   ```

3. Import `project.godot` into Godot.
4. Press **F5** to run the project.

The game starts at `src/levels/logo.tscn`. The playable level is
`src/levels/level_01.tscn`.

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
assets/                  Art, fonts, music, and sound effects
autoload/
  event_bus.gd           Signals shared between gameplay systems
  game_state.gd          Level, ability, and checkpoint progress
  time_service.gd        World time modes and scaled delta
scenes/
  options.tscn           Shared options screen and in-game overlay
scripts/                 Menu, intro, settings, and music scripts
src/
  actors/
    player/              Player controller, states, animation, and combat
    enemy/               Shared enemy logic, Guards, Gunners, and bullets
  components/            Health, age, and time-power components
  core/                  State machine and time-aware body classes
  levels/                Startup flow and playable level scenes
  ui/                    HUD, stat bars, and time-stop effects
  world/                 Checkpoints, pickups, platforms, and hazards
```

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
| A time-aware world object | Extend `TimeBody2D` or request scaled delta from `TimeService` |
| A cross-system event | Add a signal to `EventBus` and connect the interested systems |
| Another level | Add it to `GameState.LEVELS` and create its scene under `src/levels/` |
