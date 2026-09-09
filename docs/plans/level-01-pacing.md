# Level 01 transfer timing

## Current request and boundaries

Ramez edited the scene after the compact-layout revision, then requested spikes
under the transfer and much faster TransferIn/TransferOut decks that reward a
well-timed stop. This replaces the earlier no-stop/recovery-floor requirement.
Preserve the newly saved terrain, raised TransferRest, other objects, exit
relocation, and the user's global MovingPlatform default speed of 500.

## Solution and progress

- [x] Save the editor scene and snapshot the current file before editing.
- [x] Cover the existing pit floor (y=336.667) with five overlapping spike strips.
      Damage=999 and hurts_while_frozen=true prevent tanking/freezing the floor.
- [x] Set TransferIn speed to 950 and TransferOut to 897 px/s. Their roughly
      0.6-second round trips align. Adjust only TransferIn's travel to (220,-180)
      so an appropriately frozen deck connects the bank and raised middle.
- [x] Prove one-cast traversal at starting ages 23 and 53 using real input and
      wind-up. Both crossings take about 4.2 seconds of the five-second stop.
- [x] Check early and late stopped positions are outside jump reach; test actual
      spike overlaps across both edges and strip joints while time is frozen.
- [x] Check actual death/reload returns to TransferCheckpoint at age 26 with
      full health and normal time after spending three years.
- [x] Review three targeted captures and verify the editor reloaded the spikes.
      Comparison confirms only two deck settings and five spike strips changed
      in the live scene; the user's global moving-platform script is untouched.

## Artifacts and validation

`tests/level_01/verify_transfer_timing.tscn` is the current traversal contract. The obsolete safe-route entry point has been removed; the transfer now requires
a well-timed stop.
`tools/level_01/export_layout.gd` now exports the current live group to a
review draft, so manual edits cannot drift from a second authored layout.

Snapshot and respawn-check artifacts: `builds/transfer-timing/`.
Targeted captures: `builds/transfer-review/` using the existing Python helper.
Only Level 01 is rendered; the main menu and story are not run.

Existing headless certificate and shutdown-resource diagnostics remain. A
resource UID cache warning for the user's newly saved exit falls back to its
valid text path. These are separate from the traversal assertions. Automated
checks establish the route and timing, not a completed human playthrough.
Delivery now includes organizing the scenes and repository files, committing the
changes, and updating PR #44. Merge the existing main-branch organization into
this branch while preserving the current authored layout and gameplay settings.

Final checks passed: timed crossing and spike overlaps, actual checkpoint reload,
layout, enemy footing, freeze/resume, opening join and relocated exit, review-draft
export, and `git diff --check`. Starting-age 23 crossing used 4.17 seconds;
starting-age 53 crossing used 4.12 seconds. Each cast cost three years.

## Repository organization and PR delivery

- [x] Commit the authored gameplay and background revision.
- [x] Integrate main's existing Level 1 folder structure, cinematics, and UI moves.
- [x] Keep one authored layout, including decorations, at
      `src/levels/level_01/level_01.tscn`.
- [x] Group shared objects by purpose and keep scripts beside their scenes.
- [x] Group ambience, terrain seam patches, and loose checkpoints in the scene.
      Rename the later section to SalvageYard and give its final checkpoint the
      unique name ExitCheckpoint; preserve positions and gameplay parameters.
- [x] Group physics checks under tests/level_01 and authoring helpers under
      tools/level_01; update every resource path and authoring documentation.
- [x] Verify scene contracts, transfer timing, existing physics checks, and Web export.

Delivery target: commit the integration, push the branch, and update PR #44.

Organization validation: all 267 pre-existing node property blocks match the
pre-organization snapshot. Scene contracts load 39 scenes with zero failures;
all seven focused physics scenes pass. Web release export and review-draft
export succeed. Five fresh direct-level captures cover the opening, transfer,
spike floor, and exit. Existing headless certificate/shutdown diagnostics remain.
