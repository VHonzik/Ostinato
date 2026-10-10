# Local backlog

Use small playable tasks, followed by a short playtest and an adjustment. No PR, issue,
or milestone metadata is required. Task notes describe the change, the open decision,
and how to try it; the final chat carries temporary playtest instructions.

## Current milestone — Make iteration lighter

- [x] Replace formal requirements and source-data docs with direction and this backlog.
- [x] Replace historical development walkthroughs with current setup/check commands.
- [x] Make local work the default; remove required PRs, source audits, and handoff files.
- [x] Simplify validation into quick, targeted, and full modes and verify their failure paths.

## Proposed next milestone — A readable playground

Order is a recommendation to discuss, not an approved implementation queue.

1. Try one gameplay-screen layout using existing art. Settle what doubling resolution
   means for logical pixels, tile/sprite size, and visible world. Show a smaller combat
   log, larger hotbar, and player-menu entry. Keep movement and combat playable.
   Decide dimensions and hotbar capacity with the owner before committing to the layout.
2. Sketch the reduced valley and identify the characters/landmarks that matter for the
   first Loop. Produce one practical sprite list for the owner's spritesheet work.
   Avoid building a complete inventory of old source content.

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
