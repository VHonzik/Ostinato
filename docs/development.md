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
wolf types and outdoor kobold vermin are neutral until attacked; all mine kobolds and
bandits are hostile. The southwestern gate admits timed stalkers at the guard's position.
There are no within-Loop NPC respawns. Faction layers show friendly contacts in green and neutral/hostile NPCs in yellow/red;
available quests and ready turn-ins alternate the faction layer with an exclamation mark.
A separate base layer shows health. NPCs temporarily use a corner heart; the player uses
its current class artwork with an empty faction layer.
The upper-right quest tracker lists accepted quests and objective progress, marking
finished objectives and ready quests completed. Handed-in or abandoned quests disappear.
Occupants hide terrain decorations and corpses beneath them. Empty corpses disappear;
corpses with items or money remain available for looting; the story guard's corpse remains.
Death rebuilds the
map, contacts, enemies and chests, preserving learned abilities, class progression and hotbar.
Janos Hammerknuckle supplies warrior gear and trades. Llane teaches Warrior unlocks;
Farseer Lopaa, Brother Sammuel and Jorik Kerridan teach the implemented Shaman, Paladin
and Rogue kits. Each trainer exposes the complete v0.1 catalogue, with free learning
at cumulative class XP checkpoints. Tuning remains provisional.

New Game starts a warrior with rage, Mortal Strike and Heroic Strike, wearing travel clothes.
Ask Janos inside the abbey for spare warrior gear once each Loop. The marshal offers
warrior referrals, with "Uhm... I seek ... teaching" choices for each class from the second Loop. Speak
to the marshal before accepting any quest to choose the class whose ability uses grant
class XP. Each returning Loop starts in the previous class; confirmation locks one choice
until death, including keeping that same class. Class choice keeps gear and names the
matching trainer. Visit that trainer to learn the class's starter skills for free, with
no class XP requirement; new actives prefer empty slots in the upper row for maintenance
buffs and the lower row for rotation and situational abilities, using the other row
when needed. Existing assignments are preserved. Learning is permanent and needs
no relearning in later Loops. The initial Warrior pair remains known at New Game.
Farseer Lopaa is the shaman contact.
Movement: WASD + QEZC, arrows, or numpad; wait: period/numpad 5.
F interacts; I inventory; K spells; J quests; P character; hotbar: 1–6, R, T, G, V; Shift for the upper row.
M opens the player menu.
Enter confirms, Escape cancels/opens Options, F11 toggles fullscreen.
Bump a friendly NPC to interact; bump a stationary neutral enemy twice to attack.
Mortal Strike and Heroic Strike use your last attacked enemy in combat; before your
first attack, choose an enemy in melee range. Automatic attacks continue on that enemy
while it remains in melee range, including turns spent moving, waiting and using abilities.
Heroic Strike reserves rage and commits until the next main-hand swing; Escape or target
loss cancels and refunds it. Its hotbar shows Q while queued. A miss consumes the strike.
The action effect resolves before player swings, followed by enemy actions. No attacks
are banked out of range and target changes keep the weapon's remaining delay.

Start with the marshal north of spawn; Willem stands west of the abbey. K → Development provides
XP, gold, class XP, Death trigger, and Kill stalker for quick experiments. The stalker
arrival schedule lives in the valley data. The first arrival kills the gate guard early
enough for a direct route to witness it. Defeating every present stalker immediately wins;
escape beyond the valley is the story outcome, with no gate lock or crossing action.
Death resets the attempt, preserving
learned abilities, class progression and hotbar. Visit Llane inside the abbey after a
progression log notification to unlock Battle Shout, Anger Management, Charge or Execute;
unlocking keeps your points. Use the spell book to rearrange learned actives.
Execute uses the committed melee target, requires low target health, and shows current rage spending
in its tooltip and target picker. Its one-turn attack keeps weapon timing running; optional combo
empowerment remains for a later slice. Charge's wind-up and automatic
travel keep the player casting until arrival, blocking other actions and cancellation.
Charge arrival also allows the ready weapon to attack its target. These are current
mechanics; tuning and remaining v0.1 mechanics still need playtesting.
Late Warrior training adds Booming Shout, a guaranteed area hit for pulling neutral
and hostile NPCs in sight. It grants no combo points or attack procs and keeps the
selected attack target.

Shaman starts with Lightning Shield and Strength of Earth Totem; Paladin with Seal of
Command and Judgement; Rogue with Slice and Dice and the Relentless Assault passive.
All use rage. Retained abilities/passives work in every class, but only selected-class
uses grant class XP; learning does not spend it. Relentless Assault builds player-held
combo points from landed direct active attacks and ordinary main-hand hits, across
classes and targets, with one base point per world turn. Seal Fate can add an extra point
on an active crit; off-hand hits and bonus damage grant none. Slice and Dice needs points
and spends them all for attack haste. Learned Eviscerate passively adds its attack
against the current melee target, using those same spent points. Slice and Dice can
still be used without a target. Judgement leaves the seal active.
All four class kits are available, including their actives and passives. The spell book
describes their provisional mechanics; passives can be focused and inspected but cannot
be cast or assigned. New catalogue data lives in
[class_toolkit_data.gd](../scripts/hero/class_toolkit_data.gd), alongside the existing
[starter and Warrior data](../scripts/hero/class_skill_data.gd).
Every class can equip any gear without level or learning requirements.
Ambidexterity improves off-hand damage when learned.
Hands have independent timers; due swings resolve in time order, with main-hand first
on ties. Feral Spirit creates a temporary pair of wolves following your selected enemy.
Instant and Deadly Poison become available together at the Rogue trainer; Catalytic
Venom unlocks later. Casting either coating with dual wield opens a hand picker:
directions choose main hand, off hand or both; Enter applies, Escape cancels freely.
Each hand keeps its own coating and expiration, shown separately in the aura display.
Single-weapon setups coat the main hand directly. Catalytic Venom rewards Instant
on the faster base-speed weapon and Deadly on the slower; equal-speed pairs do not
catalyze. Deadly stacks belong to each enemy and tick after enemy actions, retaining
fractional damage across ticks. Saves retain coatings, stacks and pending tick damage.
Finishers spend all held points before refunds; Execute and Judgement do not spend points.
Consumable procs wait until used or death. Timed hero buffs expire at the advanced turn
boundary before player swings and enemy attacks.

The character screen shows Strength, Agility, Stamina, Armor, Crit and attack haste,
with weapon power and dodge as derived values. Gear works equally in all four classes.
Equipment has five slots: armor, neck, two rings and one weapon setup. Two-hand,
weapon-and-shield and dual-wield pairs each occupy one inventory/equipment slot.
Janos sells common gear, finite healing potions and unlimited food. Quest rewards cover
the common loadout; the mine and vineyard award final weapons. Mobs can drop poor gear
or rare uncommon upgrades; each chest guarantees common or uncommon equipment.
Poor/common/uncommon names appear gray/white/green. Shields contribute armor.
Common and uncommon accessories have primary and secondary bonuses. Crit and haste
use direct percentage bonuses. Strength increases weapon power; Agility adds crit and
dodge. Weapon-based physical, Holy and Nature damage keeps fractional power until the
final integer result, using the existing weapon roll for unbiased rounding.
Mana, caster stats and the obsolete class catalogues
are removed, along with parry, block, glancing, crushing and spell resistance.

Ordinary enemy and stalker tuning lives in
[northshire_data.gd](../scripts/world/northshire_data.gd); level-gap modifiers live in
[melee_rules.gd](../scripts/combat/melee_rules.gd). New spawns and Loops use the current
profiles; saved actors keep their recorded stats. The saved
[October balance comparisons](../balance/2026-10-14/results.md) include the raw results,
simulation setup and two-handed/dual-wield comparisons for future class tuning.

Current saves are `demo` revision 21, with gear stats rebuilt from equipment on load.
Revision 20 and older saves are incompatible and left unchanged; start a fresh game.
This revision changes Eviscerate from an assignable active into a passive; the previous
revision also changed class unlock thresholds, including increases for learned skills.
Victory requires defeating all present stalkers.
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
