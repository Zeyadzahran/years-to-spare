![Years to Spare](assets/intro/logo.png)

A 2D action-platformer made with Godot. Fight through Cad Corp to find your
family, using your father's clock to stop and rewind time. Every use costs
years of your life. Defeating enemies gives some of those years back.

**[Download on itch.io](https://r6mez.itch.io/years-to-spare)**

## The game

Still in development. The current project has two connected levels:

- **Garbage Eden:** cross a salvage yard, learn to stop time, fight the Guardian,
  and rescue your sister.
- **City of Time:** learn to rewind, face guards and beam-firing robots, and
  fight the CAD owner and his reinforcements to reach your parents. He fights
  with his mind as much as his pistol: stay at his hip and he throws you
  clear, from phase two he sends waves with a gap to crouch or jump through,
  and in the last phase he tears shards out of the floor and hurls them
  where you stand.

Both levels include moving platforms, traps, checkpoints, and in-game guides.
The story continues through cutscenes to a final ending and credits. City of
Time changes from day to night, with rain, embers, and changing background
sounds. Music can be switched off separately in the settings.

## Time, health, and lives

You start at **14**. As you age, your appearance and portrait change from boy
to adult to elder, and you move more slowly. Reaching **60** ends the run;
starting over takes you back to Level 1 at fourteen. Spending more years than
you have left also ends your life.

- **Stop time:** press **K** to freeze the world for up to five seconds; press
  **K** again to resume early. Costs three years per activation and takes
  three seconds to recharge after ending.
- **Rewind:** unlocked in Level 2. Goes back four seconds, costs four years,
  and takes six seconds to recharge. It can undo injuries and death, but
  does not refund the years you spend.

When Rewind is ready and you have enough years left, you can use it during
collapse or within one second after the death animation. It never happens
automatically. Level 2 teaches this with a guided fall.

Figs and supply chests restore **health**. Hearts give **extra lives**: you
start with three and can collect up to nine. Some hearts appear randomly
along the route or inside chests. Some spikes only hurt; others are fatal.

Dying spends a life and usually returns you to your checkpoint. Spent years,
defeated enemies, and collected hearts stay recorded. During the CAD owner
fight, a spare life lets you continue with fight progress intact. Losing your
last life means restarting the level.

## Controls

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Move | A / D or left / right arrows | Left stick |
| Jump | Space / W | A / Cross |
| Crouch | S / down arrow | D-pad down |
| Attack | J / left click | X / Square |
| Stop time | K / right click | Left shoulder |
| Rewind | L | Y / Triangle |
| Pause / settings | Esc | Start |

Press **Enter** to skip the intro or final cinematic. On Game Over, press
**Enter** to restart or **Q** to return to the menu.

## Run from source

Clone or download this repository, open `project.godot` in **Godot 4.7**, and
press **F5**.

Game code and scenes live in `src/`, shared systems in `autoload/`, and art
and audio in `assets/`. Checks for both levels live in `tests/`.
See the [Level 1](docs/level-authoring.md) and
[Level 2](docs/level-02-authoring.md) guides for editing and testing notes.
