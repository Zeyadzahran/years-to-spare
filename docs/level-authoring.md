# Level authoring

Open `src/levels/level_01/level_01.tscn` for gameplay placement. Open
`src/levels/level_01/decorations.tscn` to edit decoration placement without the
rest of the level crowding the scene tree. Keep shared objects in `src/world`
and level-specific content in the level's own folder.

## Placing decorations

Drag a scene from `level_01/props` into the relevant location group:
Entrance (x below 2500), Trench (2500–4999), BigPit (5000–8499), or Exit
(8500 onward). These are editor organization boundaries, not gameplay triggers.
Keep a prop in the group containing its origin; do not split artwork at a boundary.

Each location has the drawing layers it currently needs:

- Back: effective Z = -1.
- Middle: effective Z = 0, shared with terrain and enemies.
- Front: effective Z = 1, above terrain and enemies but below the player at Z = 10.

These depths preserve the old layout. “Front” means the front decoration layer,
not in front of the player. Keep the layer Z on the parent; placed props normally
have Z = 0. Within the same depth, scene-tree order controls overlapping art.

Move or flip a placed instance to arrange the level. Edit the source prop scene
only when every copy should change. Source props own texture crop, offset and
default scale. Their origins and scales preserve the original art placement;
for existing rocks/dirt, do not recenter them during an organization-only change.
Use descriptive names for new props and placements. Existing instance names were
retained for comparison with the old scene.

The original sheets are under `art/props`; there is no need to split them into
separate PNG files. There are ten reusable props and 79 placed instances.

## Gameplay layout

Terrain and its seam patches are under `World/Terrain`. All four checkpoint
instances are under `World/Checkpoints`. Ambience is under `Ambience`.
The shared level-exit scene is placed as `World/CityTransition`; set its
`destination` in the Inspector. It accepts the player once, as before.

Do not rename or reparent existing enemies casually: retry progress identifies
them by their path relative to the level root, for example `Enemies/Guard1`.
Checkpoints identify themselves by node name; keep names unique within a level.
These identities survived this refactor unchanged.

## Title screens and navigation

`src/ui/level_title/level_title.gd` is shared by the two title scenes. Edit their
Label text/layout in the scene and set `next_scene` on the root. Animation timing
is shared. Both titles currently lead to Level 1, preserving the existing flow;
City of Time is a title screen, not a playable second level.

Main menu, options, and cinematics keep scripts beside their scenes. The startup
scene is `src/cinematics/logo/logo.tscn`. Autoload scripts live in `autoload`.

## Changing assets safely

Prefer Godot's FileSystem dock for file moves. Preserve `.uid` and `.import`
sidecars, check literal `res://` paths in scripts, and reopen the project to
refresh imports. Do not normalize scales, crop rectangles, collision shapes,
or parallax repeat settings as part of a folder cleanup.

The two overlapping scrap background layers are intentionally retained here.
Removing either requires a separate visual/performance check.

## Regression check

Run `godot --headless --path . --script tests/scene_contracts.gd` after importing
the project. It checks scene dependencies, retry identities, checkpoint recovery,
and the existing exit/title navigation. Full visual comparison from this refactor
is recorded in `docs/refactor-plan.md`.
