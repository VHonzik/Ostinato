# Local backlog

Use small playable tasks, followed by a short playtest and an adjustment. No PR, issue,
or milestone metadata is required. Task notes describe the change, the open decision,
and how to try it; the final chat carries temporary playtest instructions.

## Completed — Make iteration lighter

- [x] Replace formal requirements and source-data docs with direction and this backlog.
- [x] Replace historical development walkthroughs with current setup/check commands.
- [x] Make local work the default; remove required PRs, source audits, and handoff files.
- [x] Simplify validation into quick, targeted, and full modes and verify their failure paths.

## Current milestone — A readable playground

- [x] Build the screen prototype from [UI_design.svg](UI_design.svg): 1280×720,
  32px tiles, two rows of ten hotbar slots, compact log and dedicated player menus.
  Keep existing gameplay playable; the mage/resources are placeholders for the pivot.
- [x] Remove automated resolution, control-fit and readability acceptance. Keep input,
  menu behavior, hotbar and save checks; visual acceptance belongs to human review.
- [x] Draft the [reduced valley and sprite list](art-plan.md). World population changes
  belong to the later world milestone; the owner’s [map sketch](map.svg) supplies the layout.
- [ ] Play the screen prototype and review the valley sketch with the owner. Adjust
  layout, landmarks and sprite needs before replacement art work starts.

## Later playable milestones

- **Warrior first:** prototype melee input and rage with a small signature toolkit.
  Playtest the attack rhythm; replace the mage start and obsolete classes in runnable
  slices. Decide the fate of item/economy systems before investing further in them.
- **Learning across Loops:** one persistent class track, trainer checkpoint, and story
  unlock; then add rogue, shaman, and paladin combinations. Settle progression credit,
  resource interaction, and retained abilities before expanding the tracks.
- **A smaller, memorable world:** fewer NPCs, no respawns, tailored XP, deliberate
  encounters, and dialogue that changes as the player learns about the Loop.
- **A satisfying stalker:** tune first-Loop length, misses/resists, victory prospects,
  and reinforcement pacing against play sessions. Finish art/UI and prepare a demo build.

## Workflow experiment

Try the owner's chosen alternative model/settings on a few comparable future tasks.
Compare accepted/playable results, corrections, actual token use if available, and
elapsed time. Keep observations in chat; only retain a useful resulting preference.
Do not add a benchmark framework, automatic model routing, or a new reporting ritual.

The old milestone-8 completion queue is retired locally. Existing GitHub issues and
milestones have not been changed; do not resume them automatically.
