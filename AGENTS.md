# Project rules

This is a small indie game using GDScript in Godot. Its combat and leveling draw heavily on WoW Classic/Vanilla and are adapted to the game's own requirements.

## Read requirements before any work

Before planning, research, implementation, tests, or review, read both:

- `docs/requirements/functional.md`
- `docs/requirements/non-functional.md`

Read their complete current contents and any requirement files they explicitly include. Do not rely solely on a summary from an earlier session. Re-read affected requirements when they change.

Then read `docs/coding-style.md`, `docs/development.md`, and relevant existing code and diagrams. If requirements are absent or unreadable, report the missing paths and do not invent them. If the assigned task is to establish or edit requirements, continue that documentation work from the user's instructions and identify unresolved decisions.

## Requirements and WoW references

Requirements are the product authority. Use stable IDs such as `FR-012` and `NFR-004`, with verifiable acceptance criteria. Link implemented behaviour and PRs to the relevant IDs.

When the user explicitly changes intended behaviour, reflect that authorized change in the requirements in the same PR. Never rewrite requirements simply to legitimize an implementation or make tests pass.

When combat or leveling behaviour is unspecified:

1. Check existing documented decisions and related requirements.
2. Research the relevant WoW Classic/Vanilla behaviour using Wowhead and WoW Wiki.
3. Adopt the clearest supported behaviour that fits this game's requirements, adapting it where those requirements call for a difference.
4. Record the source URLs, applicable game version when known, selected behaviour, and adaptation in the relevant requirement or feature note. Reference that record in the PR.

Research is intended to let work proceed. Do not ask for confirmation of every sourced detail or stop solely because a project-wide WoW patch has not been chosen. Ask only when conflicting evidence, missing evidence, or competing adaptations leave a material product decision unresolved. Explain what was researched and the remaining choice. Continue independent work.

Do not silently substitute Retail, expansion, or seasonal mechanics for Classic/Vanilla behaviour. If a source is inaccessible, use the available named source and record the limitation; do not imply it was read.

## Keep the implementation simple

Use KISS. Prefer direct code and existing Godot features. GDScript is the main language; follow the project coding style.

Avoid speculative abstractions, generic frameworks, unnecessary layers, and deep inheritance. A little duplication can be simpler than premature generalization. Ordinary helper functions, scenes, and built-in Godot types do not require a separate justification.

For a new abstraction, briefly explain the current problem, simpler alternative, and concrete benefit in the PR or relevant code documentation; no separate design report is needed. Possible future reuse alone is insufficient. Keep changes focused on the task.

Use the exact Godot, export-template, and GUT versions recorded in `docs/development.md`. Upgrade them deliberately in a separate change, keeping local development and CI aligned.

## Keep architecture documentation current

Maintain PlantUML sources under `docs/architecture/`:

- `components.puml`: the high-level component overview, responsibilities, and dependencies.
- `classes/`: focused, readable class diagrams for significant systems.
- `sequences/`: sequence diagrams for key feature interactions and meaningful alternate paths.

Use names that match the implementation. Show the fields and methods needed to explain relationships, not exhaustive member lists. Split diagrams when necessary for readability. Do not invent classes solely to populate a diagram.

Update affected diagrams in the same PR as the implementation, verify that changed sources render, and inspect their readability. Add diagrams only when they explain a useful relationship or interaction; routine bootstrap, tooling, and documentation changes do not need new diagrams or statements about unchanged diagrams.

## Automated validation and test integrity

Always run the documented project validation before completing a change. It must use Godot headlessly to import resources, check scripts, exercise project startup, and run the complete GUT unit-test suite. Run any additional required automated suites as well.

All unit tests must pass before merge; pending or skipped required tests do not count as passes. A run must actually discover the intended tests and complete successfully. Inspect process status, diagnostics, and test reports. Unexpected script, import, or runtime errors are failures even when the process exits successfully.

Test requirements and observable behaviour, including meaningful edge cases. Use controlled randomness and controllable time where needed for reliable tests. Avoid tests that merely repeat implementation details.

Do not weaken assertions, remove coverage, skip failing tests, narrow final test discovery, disable error tracking, or modify production behaviour solely to make checks pass. Fixing an incorrect test is legitimate when justified against the requirements. Expected errors in negative tests must be explicitly asserted and narrowly scoped.

Use the same validation entry point locally and in CI. Missing tools, timeouts, incomplete runs, or unavailable checks are not passes. Report the limitation and do not present the PR as ready to merge.

## PRs and human QA

Agents have standing authorization to push feature branches to this project's `origin` (`https://github.com/VHonzik/Ostinato.git`) and to create or update PRs, including draft PRs and their milestone metadata. Do not ask for confirmation again for these actions.

Agents must never merge PRs into `main`, enable auto-merge into `main`, or push directly to `main`. These actions are reserved for humans.

Deliver features in small, runnable PRs with a milestone associated in PR metadata. Each feature must be testable without a later PR.

Use `.github/pull_request_template.md` for:

- What changed and why, with relevant requirement links.
- Automated commands, results, and limitations. Refresh affected checks after changes; link logs instead of copying full reports.
- Brief feature QA steps and expected outcomes. Include extra launch, scene, fixture, reset, or boundary-case details only when needed to try the change.

Humans decide QA scope, any QA documentation, acceptance, and merging. Do not require forms, checklists, test matrices, or acceptance reports, or claim human QA results/approval on their behalf.

Bootstrap, tooling, and documentation maintenance are not feature work. Keep useful operational documentation and automated checks, without inventing feature requirements, milestones, or formal QA procedures. Include manual checks only when useful.

The PR is the handoff. Do not create separate handoff or acceptance documents unless a human requests them. For local work without a PR, a brief completion message with validation results is enough.
