# Project organization refactor

## Purpose and constraints
Group Level 1 assets, create reusable decorations, and colocate scenes/scripts without changing appearance or gameplay. Governed by the user-provided AGENTS instructions. Preserve the existing web-performance changes. Following review, the user authorized updating the README and creating a PR.

## Solution
Keep shared actors/components/world objects. Move level-specific art, ambience, terrain and background under src/levels/level_01. Extract decoration props and spatial groups while preserving transforms, effective drawing depths and overlap appearance. Extract a configurable exit and level-title destination with existing destinations unchanged. Preserve enemy paths and checkpoint names. No removal of duplicated background art, tile conversion, new streaming, or gameplay fixes.

## Progress
- [x] Inspect dependencies and identify progress identity contracts.
- [x] Capture instantiated scene properties and native-rendered baseline across the level.
- [x] Extract decorations and arrange Level 1 files.
- [x] Colocate UI/cinematic scripts and extract exit/title configuration.
- [x] Validate scene equivalence, rendering, progress, startup transitions and web export.
- [x] Document authoring workflow and review final diff.

## Validation
Use Godot 4.7.2 to capture node transforms, effective Z, sprite settings, collision properties and terrain data before/after. Compare native-rendered images across the level at fixed camera positions. Verify all scenes and referenced paths load, retained progress identifiers, title destinations, and successful Web export. Captures and original working files are under /tmp/years-refactor. Browser access was unavailable earlier; native Godot access is available for visual checks.

## Decisions
The City of Time title currently returns to Level 1. Preserve this even though it may be a future gameplay issue. Retain overlapping scrap background layers. New prop scenes keep original texture sheets and image crop coordinates.

## Results

- Level 1's main scene shrank from 1,001 to 364 lines. Its 79 decoration placements now use ten reusable prop scenes, grouped by location and drawing depth.
- All 324 captured visual/gameplay node records match after normalizing moved resource paths, the terrain node's new name, a runtime object ID, and the added ambience grouping node.
- All 26 native-rendered 1280 × 720 images match byte-for-byte, at camera X positions 350 through 12850 in steps of 500. Gameplay processing was disabled for these layout snapshots; they are not a complete animated playthrough.
- Moved PNG/MP3 files are byte-for-byte unchanged, import parameters are unchanged, and the resource-path audit found no missing references.
- `tests/scene_contracts.gd` loads and instantiates all 36 scenes, verifies startup reaches the main menu, checks enemy retry identities and checkpoint recovery, and runs both title animations through their existing destinations. Final result: zero assertion failures.
- Godot's final import and Web release export completed without logged errors or warnings. Export: `/tmp/years-refactor/web/index.html`.
- `git diff --check` passed. Final review found no remaining actionable refactor regressions or security findings.

## Limits and handoff

The final headless test reports two leaked objects and one resource still in use at shutdown despite passing its assertions. Earlier verbose runs identified audio playback resources; this refactor does not change their playback logic. This shutdown diagnostic remains unresolved and is not counted as a clean runtime exit.

Browser execution remains unverified because browser access was unavailable. Visual evidence is from native Compatibility rendering. Existing web-performance edits were preserved and included in the PR handoff.

Authoring instructions are in `docs/level-authoring.md`. Original files, the move map, property snapshots, PNG comparisons and execution logs are under `/tmp/years-refactor`; these temporary artifacts may be removed by the operating system.

## Integration with newer main

Merged `61011f3` (intro dialogue and credits). The updated intro and main menu are preserved exactly apart from resource-path changes. Credits now lives in `src/ui/credits`, with the menu/back paths updated and its script UID corrected to match the supplied sidecar. Retained both the upstream input setting and the PR's renderer settings.

After integration, all 37 scenes load and the scene contract assertions pass, including the new credits/menu round trip. The same two-object/one-resource shutdown diagnostic remains. The original 26 visual comparisons describe the Level 1 refactor; they do not claim that the intentionally updated intro and menu are unchanged from the old baseline.
