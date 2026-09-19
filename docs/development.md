# Development

The project runs the milestones 1–2 training fixture on Windows with Godot's Compatibility renderer.
Gameplay follows the [functional](requirements/functional.md) and
[non-functional](requirements/non-functional.md) requirements. The Git remote is
[VHonzik/Ostinato](https://github.com/VHonzik/Ostinato); CI and exports are not configured yet.

## Tools

Exact versions, download URLs, and hashes are in [tools/versions.json](../tools/versions.json).

| Tool | Version or prerequisite |
| --- | --- |
| Godot | 4.7.2 stable, standard Windows x64 GDScript build |
| Exact engine output | `4.7.2.stable.official.ed1daf0bf` |
| Export templates | 4.7.2 stable; install when exports are needed |
| GUT | 9.7.1, vendored in `addons/gut/` with its MIT license |
| PlantUML | 1.2026.8, cached in `bin/`; uses Smetana, no Graphviz needed |
| PowerShell | 7+ |
| Java | 17+ on PATH |

Use the pinned [Godot release](https://godotengine.org/download/archive/4.7.2-stable/) and
[GUT release](https://github.com/bitwes/Gut/releases/tag/v9.7.1).
Upgrade dependencies deliberately in a separate change, keeping this guide, the pins,
and CI aligned.

## Setup and launch

Run from the project root in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/godot.ps1 --version
pwsh -NoProfile -File tools/godot.ps1 --editor
```

Setup downloads missing pinned Godot, GUT, and PlantUML dependencies and checks their hashes.
It can be rerun; mismatched Godot/PlantUML files are errors and existing GUT is checked for
its declared version without being overwritten. Downloads need network access. Export
templates are unnecessary for editor use and validation.

Run the configured main scene without the editor:

```powershell
pwsh -NoProfile -File tools/godot.ps1
```

The wrapper locates the project and pinned console launcher and forwards Godot arguments.
In the editor, F5 runs the main scene and F6 the open scene. The current main scene needs
no save data; it creates the training fixture and a fresh level-1 mage on startup.

## Milestone 1: movement fixture

Launch with F5 or the normal wrapper command. Tap a key for one action; holding a key
does not repeat turns. The controls are W/A/S/D, Q/E/Z/C for diagonals, arrow keys
(including orthogonal chords), and numpad 1–9 excluding 5. Period or numpad 5 waits.
Top-row numbers do not move the player. Input bindings live in `project.godot`.

The blue outline marks the player. Green NPCs are fixed; gold NPCs wander inside the
gridded meadow. Trees, courtyard walls, map edges, and living NPCs block entry. The
remains immediately west of spawn do not block. The two trees north and east of spawn
leave a legal northeast diagonal. Turn, tile, speed, and movement credit are always shown.
Walking into a blocker leaves NPCs, time, and credit unchanged.

The fixture's 0.5× / 1× / 1.5× controls change speed without spending time or clearing
credit. At 0.5×, two clear movement actions move one tile; at 1.5×, they move one then two.
Tab reaches these controls; Enter/Space activates them, and Esc releases UI focus to
resume movement. Gameplay keys do not also act while a fixture control owns focus.
Reset restores the same map, seed, actor positions, default speed, turn zero, and zero
credit. These controls are development fixtures, not global Options or the Loop lifecycle.

Implemented scope: [FR-007/008/010/011/013](requirements/functional.md#movement-and-simulation-time),
the wandering portion of [FR-023](requirements/functional.md#fr-023--wandering-and-crowded-pursuit),
movement bindings from [FR-043](requirements/functional.md#fr-043--options-and-keybindings), and
[FR-044](requirements/functional.md#fr-044--player-centered-camera).
Combat, hostile bumps, aggro, pursuit, and other timed systems arrive in later milestones.
The fixture is not the final Northshire map.

`GridWorld` holds the small grid simulation separately from `MovementGame` input/UI.
Keeping every rule in the scene would couple turn tests to rendering; one ordinary
RefCounted model and typed NPC records let tests exercise movement and deterministic
ordering directly. There is no global manager or event bus.
See the [class diagram](architecture/classes/movement.puml) and
[turn sequence](architecture/sequences/movement_turn.puml).

For [NFR-002/003](requirements/non-functional.md#platform-rendering-and-display),
`pixel_viewport.gd` uses a built-in SubViewportContainer: choose the largest integer scale
fitting 640×360, then expand its child SubViewport to all remaining whole logical pixels.
This small resize helper makes both leftover world space and clear-color edge remainders
explicit, rather than depending on stretch presets' letterboxing. At 1280×800 the view
is 640×400 at 2×. The camera stays centered at map edges, and existing 16×16 sprites
use nearest filtering. UI geometry is tested at the minimum size; final human readability,
platform compatibility, and reference-hardware performance are not established by these tests.

## Milestone 2: Hero emerges

Launch the same main scene. **P** or **Character** opens the character sheet; **K** or
**Spells** opens the spell book. The HUD always shows level, current/required XP, health,
and mana. The starting mage has 20/20/20/23/22 primary attributes, 51 health, and 165 mana.
The [DATA-001/002 source record](data/hero-baseline.md) explains the selected Vanilla values,
racial removal, growth, XP table, resource refill, and beyond-level-60 extension.

The Mage tab shows learned Fireball and Frost Armor rank 1. These are explicitly labeled
previews; activating them explains that real effects arrive later and spends no time.
In a development build, the Development tab offers **Practice**, **Gain 450 XP**, and
**Death trigger**. Each costs exactly one turn and no mana. Practice reports success;
450 XP reaches level 2 with 50/900 XP and updated stats; Death trigger reports its invocation
without changing health or resetting anything. The temporary death state is milestone 3.
Release builds omit development ranks and their tab.

Click a skill or use Enter on the focused skill. A/D or left/right switches panel tabs;
W/S, diagonals, or Tab cycles controls inside the panel; Esc closes it. Hover a skill for
its description. Previewing, switching tabs, and waiting in the UI spend no time, and
movement/wait keys cannot also act on the world. Successful dummy casts grant wanderers
exactly one shared phase, preserving movement credit. Chat shows the most recent 100
messages, including XP and every gained level; scroll to inspect earlier messages.
Fixture Reset also restores the fresh hero and clears chat. No save or Loop is implied.

Implemented scope is the milestone-2 portion of FR-015/016/017/046/048/050. Secondary combat
stats, real resource spending/regeneration, equipment, training services, and real spell
effects remain later dependencies. The five primary stats, resources, sourced growth,
learned ranks, and one-turn fixtures are executable now. The existing movement tests
remain in the complete suite alongside progression, skill/turn, and UI tests.
See the [hero class diagram](architecture/classes/hero.puml) and
[skill sequence](architecture/sequences/hero_skill.puml).

## Project layout

- `scenes/main.tscn`: integer-scaled viewport; `movement_game.tscn`: playable fixture.
- `scripts/world/`: grid rules, NPC state, fixture layout, and sprite rendering.
- `scripts/hero/`: sourced mage growth, progression, learned ranks, and the character/spell panel.
- `docs/data/`: versioned data selections and adaptations.
- `test/unit/`: GUT tests; all project test suites belong under `test/`.
- `tools/`: setup, launch, validation, dependency pins, and GUT report hook.
- `docs/architecture/`: PlantUML sources for implemented systems.
- `addons/gut/`: pinned third-party dependency.
- `reports/`: generated local logs, test results, and diagrams; ignored by Git and Godot.

Follow [coding-style.md](coding-style.md). [.editorconfig](../.editorconfig) and
[.gitattributes](../.gitattributes) define formatting and LF normalization.
[.gitignore](../.gitignore) excludes downloaded tools, caches, reports, and builds.
Keep GDScript UID files and asset `.import` sidecars to preserve resource identities.

## Validation

Use the same entry point locally and in CI:

```powershell
pwsh -NoProfile -File tools/validate.ps1
```

It verifies tool pins and test configuration, imports resources headlessly, checks every
first-party GDScript, runs startup for 120 iterations, runs the complete recursive GUT suite
with error tracking, and renders every PlantUML source as SVG and PNG. Discovery is checked
against detailed JSON and JUnit results so unrun or missing tests cannot pass.

Unexpected diagnostics, nonzero exits, timeouts, resource leaks, missing reports, zero
tests, or failed/pending/skipped/risky tests fail validation. Focused test filters are rejected.
Negative tests must assert specific expected errors; do not disable error tracking or broadly
suppress diagnostics. See [AGENTS.md](../AGENTS.md) for test-integrity rules.

Each child process has a 120-second wall-clock limit. Increase it explicitly when needed:

```powershell
pwsh -NoProfile -File tools/validate.ps1 -TimeoutSeconds 240
```

Results are generated in `reports/validation/<run-id>/`. Inspect the latest summary and
its logs, including on failure:

```powershell
$reportDirectory = (Get-Content reports/latest-validation.txt -Raw).Trim()
Get-Content (Join-Path $reportDirectory 'summary.json')
```

The shared process helper provides timeouts and logs for each tool. The GUT report hook
adds discovery/status/error details absent from JUnit so the runner can verify completeness.
Startup checks cover only the scene they exercise; add meaningful tests as gameplay appears.

Render diagrams independently with `pwsh -NoProfile -File tools/render_diagrams.ps1`.
Inspect changed diagrams for readability.

## Pull requests

Agents may push feature branches to this project's `origin` and create or update PRs
without asking for confirmation. Agents must never merge PRs into `main`, enable
auto-merge into `main`, or push directly to `main`; those actions are reserved for humans.
See the standing authorization in [AGENTS.md](../AGENTS.md#prs-and-human-qa).

Use the [PR template](../.github/pull_request_template.md) for a short change summary,
automated results, and feature QA steps. Include extra scene/setup/reset details only when
needed to try the change. Human reviewers decide QA scope, any QA records, acceptance, and
merging. Keep handoff information in the PR; local work without a PR needs only a brief
completion message. Bootstrap and maintenance work need no feature acceptance paperwork.
