# Working on Ostinato

This is a hobby roguelike in Godot/GDScript. WoW is inspiration, not a specification.
The current project target is a playable demo of the full game, focused on the valley.
Prioritize enjoyable play, readable art/UI, and small playable changes.

## Context and decisions

- Read `docs/direction.md` for game design work and the relevant task in `docs/backlog.md`.
  Read `docs/development.md` when using tools, and `docs/coding-style.md` when editing code.
  Read relevant existing code; do not load all documentation for every task.
- The user's current decisions take precedence. Ask early about consequential design
  choices, with a recommendation; proceed independently on routine implementation details.
- Keep unresolved gameplay choices explicit. Do not treat old code or tests as a binding
  design contract. Update affected tests when intended behavior changes, explaining why.
- Keep numeric tuning and implemented behavior in game data/code, with
  [docs/class-mechanics.md](docs/class-mechanics.md) as the authoritative human-readable
  reference for current class mechanics, taglines and ability tables. Read it when
  changing class abilities and update it in the same change for additions, removals,
  renames, tuning, training requirements/prices, proc interactions or effect art/placement.
  Keep both active and passive abilities, one table per class, the existing columns and
  `-`/`*` notation, sorted by learning level, learning cost, then name. Update affected
  shared rules and class summaries/taglines too. Keep this reference focused on the
  current class overview, with brief introductions. Describe implemented behavior only;
  remove obsolete descriptions instead of recording changes, removed abilities,
  comparisons with earlier versions, or plans. Keep AGENTS.md as current working
  instructions, without project history or a change log.
  Other docs should hold durable direction and current tasks. No requirement IDs,
  mandatory source audits, additional duplicated ability tables, design reports or
  acceptance paperwork.
- [docs/npc-dialogue.md](docs/npc-dialogue.md) is the authoritative human-readable
  reference for implemented quests, dialogue and NPCs in the playable valley. Read it
  when editing this content and update it alongside changes to quest availability,
  objectives/rewards, dialogue text/conditions, NPC identities/placements/services,
  encounter profiles/behavior, story events or related Loop/save rules. Keep the intro
  brief and the tables central; include exact dialogue and its conditions. Describe
  current playable content only, replacing obsolete entries without change notes,
  removed-content lists, earlier-version comparisons or proposed dialogue. Keep ability
  and trainer-gift effect details in class-mechanics.md and link to them rather than
  duplicating ability tables. Keep future story/design work in direction/backlog.
- Keep supporting guides focused on setup, workflows and durable direction. Link to
  the authoritative content references instead of repeating their current mechanics,
  dialogue or tuning. Remove stale implementation claims and project-history recaps.
- Research only when it resolves a concrete uncertainty. Vanilla accuracy is optional.

## Implementation and checks

- Use simple typed GDScript and built-in Godot features. Avoid speculative frameworks,
  broad refactors, and unrelated cleanup. Keep the game runnable between tasks.
- Keep the exact dependency pins in `tools/versions.json`; upgrade deliberately.
- For design simulations, read [bench/README.md](bench/README.md). Keep reusable bench
  source in `bench/`, separate from game code; put generated runs in ignored
  `reports/bench/`. Use `pwsh -NoProfile -File tools/simulate.ps1` with its scenario
  options as a standalone command so the saved launcher approval applies. Routine
  local sims are authorized during design work; do not ask for conversational approval
  for each run. Respect any tool-enforced approval and request only the launcher prefix
  if needed. Sims inform design; they do not establish balance or human acceptance.
- Run `tools/validate.ps1` for code/resource changes: import, script loading, startup.
  Add `-Test <path>` for affected behavior tests. Use `-Full` for changes spanning many
  systems, validation-tool changes, or when requested. Documentation-only changes need
  a diff/link check, not a Godot run. See `docs/development.md` for commands.
- Test meaningful behavior and edge cases, especially saves, Loop reset, and turn ordering.
  Use controlled time/randomness. Avoid tests that merely repeat implementation details.
- Never hide failures, disable error tracking, or claim unrun checks passed. A targeted
  pass is not a full-suite pass. Expected errors must be asserted narrowly. Remove tests
  for deliberately removed behavior along with that behavior, not to conceal regressions.
- Preserve user saves on failed writes/loads. Break save compatibility explicitly when
  needed; do not build migrations for an experiment unless requested.

## Planning and collaboration

- Work locally by default. Do not commit, push, create/update PRs, issues, or remote
  milestones unless asked. Never merge or push directly to `main` or enable auto-merge.
- Keep milestones separate from game direction in `docs/backlog.md`. Detail the next
  playable task; leave later milestones coarse. Do not maintain duplicate GitHub plans.
- End with a short chat summary: what changed, checks and limitations, and a few useful
  playtest steps. No handoff files. If temporary notes are needed, use ignored `reports/`.
- Do not automate resolution, text readability, clipping, or control-fit acceptance.
  Keep UI tests focused on behavior such as input, focus navigation, and state changes.
- Human playtesting decides feel, readability, and balance. Do not claim human acceptance.
- Keep tool output concise; inspect diagnostic logs on failure instead of dumping them.
  Do not generate written validation reports or introduce mandatory QA forms.
