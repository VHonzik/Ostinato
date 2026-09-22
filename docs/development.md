# Development

The project runs the milestones 1–5 training fixture on Windows with Godot's Compatibility renderer.
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
In the editor, F5 runs the main scene and F6 the open scene. The main scene opens the main menu. New Game creates a fresh seed and level-1 mage.
Existing saves are loaded only through the five-slot interface.

The milestones 1–3 sections below record their original review fixtures. Milestone 4
supersedes their preview, startup, Reset-button, and death-overlay behavior.

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
Milestone 3 adds combat, hostile bumps, aggro, and pursuit to these grounds.
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
and now kills the player through milestone 3's temporary death overlay.
Release builds omit development ranks and their tab.

Click a skill or use Enter on the focused skill. A/D or left/right switches panel tabs;
W/S, diagonals, or Tab cycles controls inside the panel; Esc closes it. Hover a skill for
its description. Previewing, switching tabs, and waiting in the UI spend no time, and
movement/wait keys cannot also act on the world. Successful Practice/XP casts grant wanderers
exactly one shared phase, preserving movement credit. Chat shows the most recent 100
messages, including XP and every gained level; scroll to inspect earlier messages.
Fixture Reset also restores the fresh hero and clears chat. No save or Loop is implied.

Implemented scope is the milestone-2 portion of FR-015/016/017/046/048/050. Milestone 3 adds secondary melee stats. Resource spending/regeneration, equipment,
training services, and real spell effects remain later dependencies. The five primary stats, resources, sourced growth,
learned ranks, and one-turn fixtures are executable now. The existing movement tests
remain in the complete suite alongside progression, skill/turn, and UI tests.
See the [hero class diagram](architecture/classes/hero.puml) and
[skill sequence](architecture/sequences/hero_skill.puml).

## Milestone 3: Fight!

Launch the same main scene. Move southwest, then south from spawn to stand beside the yellow
**Young Wolf**. A neutral bump blocks without time. Press **F**: a lone neutral opens
**Attack Young Wolf?**, with **Attack (Enter)** and **Cancel (Esc)**. A lone hostile
starts melee immediately. Multiple candidates first use a selector: movement directions
wrap around, Previous/Next buttons and adjacent world sprites also select, and Enter
chooses. Choosing a neutral then asks separately for attack confirmation. A corpse
remains selectable under another actor. Combat prompts use labeled shortcuts or mouse
clicks; Tab does not change focus. Selection, confirmation, and cancellation spend no
time until an attack is committed.

Friendly **Groundskeeper Mira** is two tiles northwest of spawn. Her greeting and empty
corpse results go straight to chat, with no dialogue to dismiss. A single candidate
skips selection for these interactions too. Open windows never advance simulation.

Red **Timber Wolves** wait to the east at (32,12), (33,14), and (34,16). Approach to
within five tiles with clear sight to provoke them. They follow a shortest terrain
route around trees/walls, approaching directly when shortest routes tie. They only
spread around other actors when the next step is occupied, and swing immediately
when ready on entering range. Wandering meadow wolves remain neutral until engaged. Relationship colors
are accompanied by text in the selector; alternate palettes remain milestone 8.

Bumping a hostile or confirming an attack spends at least one turn. The temporary
Bent Staff swings every 2.9 simulation seconds. If it is not ready, the committed
attack automatically advances the necessary turns, including each NPC phase. A brief
presentation gap between boundaries allows **Esc** or **Cancel attack (Esc)** to stop
the request without refunding elapsed turns. There is no Continue prompt. The request
ends once its swing resolves; idle time does not start another attack. Movement and
Wait also advance swing timers but do not automatically attack. Chat reports
each attack outcome/damage and kill XP; the HUD always shows current/max health and
mana. P now shows attack power, armor, critical and dodge percentages.

A killed wolf leaves a nonblocking, selectable corpse with an explicit empty-loot
message; loot rewards arrive in milestone 5. Kill XP is granted once, including
ordinary level-up/refill when crossing a threshold. Corpses expire after 300 turns.
Player death immediately stops the remaining phase and opens **You died**. Gameplay
keys cannot continue the attempt; **Reset fixture** or Enter restores a fresh fixture.
The Development death trigger follows this same path. Reset is still a development
control; the persistent Loop starts in milestone 4.

Scope: the initial melee/interaction portions of FR-009/014/020–027/049, FR-016 kill
XP, and updated FR-048/050 feedback. See [DATA-002 melee selection](data/melee-baseline.md)
for formulas, source limitations, explicit fixture adaptations, and deferred mechanics.
No targeted real spell, inventory loot, regeneration, or full combat formula coverage
is claimed. Existing Fireball/Frost Armor remain previews. See the
[combat classes](architecture/classes/combat.puml) and
[combat sequence](architecture/sequences/combat_turn.puml).

## Milestone 4: Here we go again...

Launch the main scene and choose **New Game**. **Esc** from idle gameplay or the
**Options** button opens options; menus never advance simulation. The bottom menu
labels show the checked-out short Git hash and copyright. **F11** toggles fullscreen.
Options persist display, relationship palette, and keybindings separately from saves.
A conflicting binding requires an explicit swap. Enter/Tab remain menu controls.

**K** now offers real Fireball and Frost Armor. Damage, healing, and friendly buffs
use a selector even with one target; **Enter** casts and **Esc** cancels. Fireball can
target adjacent enemies. Below its 30-mana cost, feedback identifies insufficient mana. Casts advance
automatically with the same cancellable presentation gap as melee. Their shared
fractional casting credit, resource costs, periodic effects, and completion failures
follow [the M4 source record](data/loop-baseline.md). HP/mana remain visible.

**K → Development → Death trigger** starts the next Loop immediately. All transient
state is rebuilt, including level, outfit, resources, actors, timers, and arrivals.
Learned ranks and per-game hotbar state survive. Loop count and turn are in the HUD.
There is no temporary death overlay or gameplay Reset button.

From Loop 2, move to (19,13), beside Marshal McBride at (18,12), and use **F**.
Choose druid while still level 1 and before accepting any quest; the current class is omitted. Selection replaces
only granted outfit pieces, preserves resources, and grants no skills. The mage
trainer is at (17,14), and the druid trainer at (17,16). Approach within one tile,
interact, and learn the free starting ranks. Druid has Wrath, Healing Touch, and
Mark of the Wild. Die again and use those retained spells from the mage baseline.
**I** shows the outfit and occupied inventory slots; full item operations follow in M5.

The eastern gate is at (54,14). At turn 15 a level-20 stalker enters, kills the guard,
and idles until ordinary aggro. Blocking the entry delays it until a free boundary.
Its announcement, actor state, and pending arrival survive load and reset each Loop.
This is the first-arrival subset; reinforcements and completion remain M8.

**Options → Save / Load** offers five slots. Occupied saves show UTC timestamp and
Loop; overwrite asks for confirmation. Saving is disabled in combat or during a
pending action. Loading remains available and cancels the abandoned continuation.
Unsaved Load/Main Menu/Exit requires discard confirmation. Slot copies retain the
same seed. Saved state includes both RNG streams, fractional progress, effects,
outfits, class eligibility, corpses, and schedule progress.

Files live under Godot's user-data directory: on Windows, normally
`%APPDATA%/Godot/app_userdata/Ostinato/saves/slot_1.json` through `slot_5.json`.
Global settings are `options.json` alongside the saves directory. Tests use isolated
temporary directories and do not overwrite gameplay slots. M4 originally used `demo` revision 1; M5 uses revision 2 (see below).
Damaged saves are retained with a `.damaged-UTC-unique` suffix, and unsupported
revisions remain unchanged. File failures are visible; a failed overwrite preserves
the previous save.

See [Loop/save classes](architecture/classes/loop_save.puml) and
[Loop/save sequence](architecture/sequences/loop_save.puml). Automated coverage
includes repeated resets, trainer/class restrictions, spell timing, save failures,
deterministic continuation, options conflicts, and UI geometry. Human visual,
platform, and benchmark acceptance is not inferred from those automated checks.

## Milestone 5: Always be learning..

Interact beside **Training supplies** at (19,19), collect its copper and items, then
open **I**. Select a bag item for details, equip/use, or move/split into a chosen slot.
Equipment slots offer unequip. Equip, unequip and use cost one turn; the open menu,
loot collection, rearrangement, training and trade cost no time. Full bags preserve loot.
A mage can wear the leather vest or use a sword/shield; item-level and hand rules remain.

The trader at (16,18) supports explicit buy/sell quantities. Its three mana potions are
finite; waiting never replenishes them. New Loops restore stock. Mage/druid trainers
at (17,14)/(17,16) expose all 26 included ranks through learning level 10, including
prerequisite/cost feedback. For a quick higher-rank fixture, cast Development → Gain
450 XP seventeen times to reach level 6, loot the chest, then learn Fireball rank 2
for 100 copper. Both ranks appear in the spell book. Die and cast the retained higher
rank from level 1; the bag, money, effects and vendor stock reset.

New effects include heals over time, roots, slows, Polymorph, Nova, Arcane Missiles,
conjured food/water, Thorns, individual cooldowns and equipment-derived stats. See the
[source record](data/learning-baseline.md) for numeric examples, exclusions and fixture
adaptations. The courtyard at x7–13/y8–11 is indoors for Entangling Roots.

**Save compatibility:** current saves are `demo` revision 2. Revision-1 files are
incompatible and retained unchanged. New saves restore remaining loot, vendor stock,
quantities/equipment, currency, cooldowns and periodic effects deterministically.
Use a new game or an unused save slot to review M5 without replacing an older save.

## Project layout

- `scenes/main.tscn`: integer-scaled viewport; `movement_game.tscn`: menus and playable fixture.
- `scripts/world/`: grid rules, NPC state, fixture layout, and sprite rendering.
- `scripts/combat/`: melee calculations, fractional swing timing, and interaction/targeting UI.
- `scripts/hero/`: sourced mage growth, progression, trainer ranks, and the character/spell panel.
- `scripts/items/`: item/loot data and atomic inventory/equipment transactions.
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
