# Development

Windows x64, Godot Compatibility renderer, typed GDScript. The current game is in the
warrior-first pivot; [direction](direction.md) describes planned changes.

## Setup and launch

Use PowerShell 7 from the repository root:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/godot.ps1 --editor
# Or run the game directly:
pwsh -NoProfile -File tools/godot.ps1
```

[tools/versions.json](../tools/versions.json) is the dependency authority:
Godot `4.7.2.stable.official.ed1daf0bf`, GUT `9.7.1`, matching `4.7.2.stable`
export templates when exporting. Setup checks hashes and does not overwrite mismatched
installed dependencies. GUT is vendored with its license. CI and exports are not configured.

## Current build

**New Game** launches the sketch-based valley, the sole playable game map.
The marshal offers the western patrol, northern camp and mine objectives; Willem
points to exploration caches, and Milly offers the vineyard encounter. The marshal
also gives the stronger-wolf follow-up after the western patrol. Trees, walls
and vine trellises block movement; flowers, small stones and sparse grass tufts are
decorative. Grass appears less often in wooded areas. Outdoor ground is plain. Both
wolf types, kobold vermin and laborers are neutral until attacked; workers and bandits
are hostile.
The southwestern gate admits a timed stalker and reinforcements.
There are no within-Loop NPC respawns. Friendly contacts are green; available quests
and ready turn-ins alternate their contact sprite with an exclamation mark. Neutral and hostile sprites are yellow and red; injured enemies blink dark red.
Occupants hide terrain decorations and corpses beneath them. Empty corpses disappear;
corpses with items or money remain available for looting. Death rebuilds the
map, contacts, enemies and chests, preserving learned abilities, class progression and hotbar.
The supply trader and warrior trainer Llane remain usable; other class trainers await later slices.

New Game starts a warrior with rage, Slam and Battle Shout. Other classes are currently unavailable.
Movement: WASD + QEZC, arrows, or numpad; wait: period/numpad 5.
F interacts; I inventory; K spells; J quests; P character; hotbar: 1–6, R, T, G, V; Shift for the upper row.
M opens the player menu.
Enter confirms, Escape cancels/opens Options, F11 toggles fullscreen.
Bump a friendly NPC to interact; bump a stationary neutral enemy twice to attack.
Slam uses your last attacked enemy in combat; before your first attack, choose an
enemy in melee range.

Start with the marshal north of spawn; Willem stands west of the abbey. K → Development provides
XP, gold, class progression points, Death trigger, and Kill stalker for quick experiments. The stalker
arrival schedule lives in the valley data; killing one ends the demo. Death resets the attempt, preserving
learned abilities, class progression and hotbar. Visit Llane inside the abbey after a
progression log notification to unlock Anger Management or Charge; unlocking keeps your
points. Assign Charge to a hotbar slot through the spell book. Its wind-up and automatic
travel keep the player casting until arrival, blocking other actions and cancellation.
These are current mechanics, not constraints on the pivot.

Current saves are `demo` revision 12, introducing the warrior start, rage and persistent
warrior progression.
Revision 11 and older saves are incompatible and left unchanged; start a fresh game.
Valley saves retain their map identity. Saves live in `%APPDATA%/Godot/app_userdata/Ostinato/saves/`;
global settings are in `options.json` beside that directory. Tests use isolated save locations. Preserve user
files during failures and declare future compatibility breaks explicitly.

## Checks

```powershell
# Default: headless import, load/check first-party scripts, startup. No unit tests.
pwsh -NoProfile -File tools/validate.ps1

# Same quick checks, then all tests in the chosen file(s):
pwsh -NoProfile -File tools/validate.ps1 -Test test/unit/test_grid_world.gd
# Multiple files from PowerShell:
./tools/validate.ps1 -Test test/unit/test_grid_world.gd,test/unit/test_saves.gd

# Quick checks and the complete recursive GUT suite:
pwsh -NoProfile -File tools/validate.ps1 -Full
```

Use targeted tests for behavior changes; full tests for changes across many systems,
validation-tool changes, or an explicit request. Docs-only edits need a diff/link check.
Do not repeat a full run after a later prose-only edit. Add meaningful tests where they
protect behavior; remove obsolete tests when that behavior deliberately goes away.

Each process has a 120-second timeout; override with `-TimeoutSeconds 240` when needed.
Failures, unexpected diagnostics, incomplete test discovery, and pending/skipped tests
within the selected scope fail the command. A quick or targeted pass does not certify
all gameplay. UI layout, text readability, clipping, and resolution suitability are human review.
Do not automate visual acceptance; UI tests cover input and state changes. Tests and
startup checks do not establish visual quality or fun.

Output is a short scope/result summary. Logs are temporary and removed on success;
failures retain them under ignored `reports/validation/`. Use `-KeepLogs` to retain a
successful run for debugging. No written validation report is required.

## Where things live

- `scenes/`: main viewport and playable scene.
- `scripts/world/`, `combat/`, `hero/`, `items/`, `quests/`: simulation, UI, and game data.
- `scripts/game_session.gd`, `save_codec.gd`, `save_store.gd`: Loops and persistence.
- `test/unit/`: behavioral GUT tests; `tools/`: setup, launch, and checks.
- `art/`: [sprite generation and packing](../art/README.md); selected PNGs in
  `assets/sprites/valley/`, maintained atlas in `assets/spritesheets/valley/`.
- `docs/direction.md`: durable intent; `docs/backlog.md`: local work, separate from design.

Follow [coding-style.md](coding-style.md); preserve `.gd.uid` and asset `.import` files.
Keep numerical data in code. Refactor a subsystem when its current task benefits, not
as a prerequisite to the pivot. The existing folder layout needs no wholesale move.

Work stays local unless requested otherwise. Summarize changes and useful playtest
steps in chat; create no handoff file. Humans choose what to test and commit.
