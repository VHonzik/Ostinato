# Local backlog

Use small playable tasks, followed by a short playtest and an adjustment. No PR, issue,
or milestone metadata is required. Task notes describe the change, the open decision,
and how to try it; the final chat carries temporary playtest instructions.

## Completed — Make iteration lighter

- [x] Replace formal requirements and source-data docs with direction and this backlog.
- [x] Replace historical development walkthroughs with current setup/check commands.
- [x] Make local work the default; remove required PRs, source audits, and handoff files.
- [x] Simplify validation into quick, targeted, and full modes and verify their failure paths.

## Completed — A readable playground

- [x] Build the screen prototype from [UI_design.svg](UI_design.svg): 1280×720,
  32px tiles, two rows of ten hotbar slots, compact log and dedicated player menus.
  Keep existing gameplay playable; the mage/resources are placeholders for the pivot.
- [x] Remove automated resolution, control-fit and readability acceptance. Keep input,
  menu behavior, hotbar and save checks; visual acceptance belongs to human review.
- [x] Draft the [reduced valley and sprite list](art-plan.md). World population changes
  belong to the later world milestone; the owner’s [map sketch](map.svg) supplies the layout.
- [x] Establish the [local art pipeline](../art/README.md): ComfyUI world/static
  generation, selected individual PNGs, and separate atlas packing. The prototype
  is accepted; rejected experiments are removed.
- [x] Play the screen prototype. The owner's quick playtest found it satisfactory;
  the valley sketch and sprite plan are ready for the first playable map prototype.

## Current milestone — A memorable valley

- [x] Build a playable route from the marshal through one encounter area using the
  [valley sketch](map.svg) and selected AI-created sprites. Try ground, boundaries,
  actors and props together before expanding to the whole valley. The owner accepted the first slice;
  **New Game** now uses the expanded valley as the sole game map.
- [ ] Refine selected sprite equipment, remains, and terrain joins in the western
  woods slice, especially cliff joins, abbey doors and wolf remains. The owner-selected
  original sprites are restored for actors, abbey walls/entrance, nature, chests
  and a shared corpse. Review silhouettes at native size before further art changes.
- [x] Expand the valley with fewer NPCs, no within-Loop respawns, deliberate
  encounters and exploration destinations. Add a timed arrival at the southwestern gate.
  Branch rewards are an initial tuning pass; routes and XP still need playtesting.
- [ ] Add a small story pass with recognizable contacts and dialogue that changes
  as the player realizes the Loop. NPCs remain unaware of it; settle the shaman's
  identity and keep invasion knowledge limited.
- [ ] Playtest navigation, landmark recognition, encounter/XP pacing, the timed gate
  threat and early/returning-Loop conversations; adjust the map, story and art together.

## Later playable milestones

- **Warrior first:** prototype melee input and rage with a small signature toolkit.
  Playtest the attack rhythm; replace the mage start and obsolete classes in runnable
  slices. Decide the fate of item/economy systems before investing further in them.
- **Learning across Loops:** one persistent class track, trainer checkpoint, and story
  unlock; then add rogue, shaman, and paladin combinations. Settle progression credit,
  resource interaction, and retained abilities before expanding the tracks.
- **A satisfying stalker:** tune first-Loop length, misses/resists, victory prospects,
  and reinforcement pacing against play sessions. Finish art/UI and prepare a demo build.

## Workflow experiment

Try the owner's chosen alternative model/settings on a few comparable future tasks.
Compare accepted/playable results, corrections, actual token use if available, and
elapsed time. Keep observations in chat; only retain a useful resulting preference.
Do not add a benchmark framework, automatic model routing, or a new reporting ritual.

The old milestone-8 completion queue is retired locally. Existing GitHub issues and
milestones have not been changed; do not resume them automatically.
