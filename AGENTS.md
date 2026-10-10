# Working on Ostinato

This is a hobby roguelike in Godot/GDScript. WoW is inspiration, not a specification.
Prioritize enjoyable play, readable art/UI, and small playable changes.

## Context and decisions

- Read `docs/direction.md` for game design work and the relevant task in `docs/backlog.md`.
  Read `docs/development.md` when using tools, and `docs/coding-style.md` when editing code.
  Read relevant existing code; do not load all documentation for every task.
- The user's current decisions take precedence. Ask early about consequential design
  choices, with a recommendation; proceed independently on routine implementation details.
- Keep unresolved gameplay choices explicit. Do not treat old code or tests as a binding
  design contract. Update affected tests when intended behavior changes, explaining why.
- Put numeric tuning and implemented behavior in the game data/code. Keep only durable
  direction and current tasks in docs. No requirement IDs, mandatory source audits,
  duplicated data tables, design reports, or acceptance paperwork.
- Research only when it resolves a concrete uncertainty. Vanilla accuracy is optional.

## Implementation and checks

- Use simple typed GDScript and built-in Godot features. Avoid speculative frameworks,
  broad refactors, and unrelated cleanup. Keep the game runnable between tasks.
- Keep the exact dependency pins in `tools/versions.json`; upgrade deliberately.
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
- Human playtesting decides feel, readability, and balance. Do not claim human acceptance.
- Keep tool output concise; inspect diagnostic logs on failure instead of dumping them.
  Do not generate written validation reports or introduce mandatory QA forms.
