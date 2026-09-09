# Level authoring

Open `src/levels/level_01/level_01.tscn` and use **Run Current Scene (F6)**.
All terrain, gameplay objects, and decoration placements are authored here.
There is no separate extension or decoration layout to synchronize.

## Scene tree

- `Ambience`: desert wind and ambience players.
- `Background`: the reusable parallax scene.
- `World/Terrain`: opening tile surface and seam patches.
- `World/Decorations`: opening background and foreground scenery.
- `World/Checkpoints`, `Pickups`, and `Hazards`: opening gameplay objects.
- `World/SalvageYard`: the later terrain, platforms, checkpoints, hazards,
  enemies, pickups, exit gate, and decorations in their own groups.
- `Entities/Player`, `Enemies`, `HUD`, and `Tutorial`: player, opening enemies,
  interface, and instructions.

Keep the SalvageYard parent at the origin. Its object positions are world-space
coordinates, which makes it easy to compare both terrain sections in one scene.
The fixed middle platform is `Platforms/TransferRest`; the two fast decks are
`TransferIn` and `TransferOut`. Five overlapping lethal strips cover the floor.

## Files and reusable objects

Level-specific images, audio, hazards, props, tileset, background, and shader
live under `src/levels/level_01/`. Shared checkpoint, pickup, platform, and exit
scenes live in matching folders under `src/world/`. Scripts stay beside their
scenes, along with `.uid` and animation resource files.

Drag a scene from `level_01/props/` into a decoration group when adding scenery.
Existing placements retain their original texture crops, transforms, drawing
order, and depth. Edit a reusable source scene only when every instance should
change. Do not recenter existing rocks or normalize scales during file cleanup.
The original sheets remain in `art/props/`; separate PNG files are unnecessary.

The background contains one upright sky, ruins, and scrap layer. Its shader
extends rubble below the scrap silhouette. Keep the original colors, nearest
texture filtering, and enough horizontal repeats to cover the level in the editor.

## Retry identities

Enemy progress uses paths relative to the level root. The eight opening enemy
paths remain under `Enemies`; the two later guards are under
`World/SalvageYard/Enemies`. Avoid renaming or reparenting these during play tuning.
Checkpoint names must be unique across the whole level. The four later markers
are `ShuttleCheckpoint`, `LiftCheckpoint`, `TransferCheckpoint`, and
`ExitCheckpoint`. A retry preserves age spent and enemies already defeated.

The gate at `World/SalvageYard/Gates/LevelExit` shows a completion panel and pauses
the level. Its return button clears run progress and opens the main menu.

## Previews and checks

```bash
python3 tools/capture_level.py
python3 tools/capture_level.py --only 05,06,07 --output builds/transfer-review
godot --headless --path . --script tests/scene_contracts.gd -- --level-only
godot --headless --path . --fixed-fps 60 tests/level_01/verify_transfer_timing.tscn
```

The Python helper renders Level 1 directly and writes a gallery under `builds/`.
Focused checks are under `tests/level_01/`. `tools/level_01/export_layout.gd`
exports the current salvage yard into an ignored review draft; it does not
rebuild or overwrite the live layout. Generated artifacts stay under `builds/`.

Prefer Godot's FileSystem dock for future moves. Preserve `.uid` and `.import`
sidecars, update literal resource paths, refresh imports, then run scene checks.
