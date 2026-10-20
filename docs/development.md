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
The marshal offers the western woods, northern camp and mine objectives; Willem
asks you to enter the mine, approach the vineyard and explore the wolf woods, and Milly offers the vineyard encounter. The marshal
includes both young and timber wolves in one western-woods quest. Trees, walls
and vine trellises block movement; flowers, bushes, small stones and sparse grass tufts are
decorative. Grass appears less often in wooded areas. Outdoor ground is plain. Both
wolf types and outdoor kobold vermin are neutral until attacked; all mine kobolds and
bandits are hostile. The road south of the southwestern gate admits timed stalkers beside the guard.
Outdoor enemies wander locally with random pauses and staggered starts; mine kobolds,
Garrick and stalkers stay put when idle. Saves retain pending wandering deadlines.
Closed chests block movement; bumping a chest opens the loot menu without collecting
anything or spending a turn. Remaining loot reopens the menu on later bumps; empty
chests no longer intercept movement. Full bags preserve uncollected items.
There are no within-Loop NPC respawns. Faction layers show friendly contacts in green and neutral/hostile NPCs in yellow/red;
available quests and ready turn-ins alternate the faction layer with an exclamation mark.
A separate base layer shows health. NPCs temporarily use a corner heart; the player uses
its current class artwork with an empty faction layer.
The upper-right quest tracker lists accepted quests and objective progress, marking
finished objectives and ready quests completed. Handed-in or abandoned quests disappear.
The engaged enemy frame shows its name, health and a yellow marker while it is needed
for an accepted quest objective. Fresh Loops include food with an upper-right hotbar
shortcut; Eating shows the next healing tick and remaining duration.
Occupants hide terrain decorations and corpses beneath them. Empty corpses disappear;
corpses with items or money remain available for looting; the story guard's corpse remains.
Death rebuilds the
map, contacts, enemies and chests, preserving learned abilities and hotbar.
Janos Hammerknuckle supplies starter gear for the selected class and trades. Llane teaches Warrior unlocks;
Farseer Lopaa, Brother Sammuel and Jorik Kerridan teach the implemented Shaman, Paladin
and Rogue kits. Trainers show current level requirements and gold prices, with free
starter skills and gray learned entries. Learning is permanent; prices remain provisional.

New Game starts a warrior with rage, Mortal Strike and Whirlwind, wearing travel clothes.
Ask Janos inside the abbey for spare class gear once each Loop. The marshal offers
warrior referrals, with "Uhm... I seek ... teaching" choices for the other classes from the second Loop. Speak
to the marshal before accepting any quest. Returning Loops show class selection first,
focusing the previous class; choosing immediately reveals quests and locks the class until death.
Other NPCs redirect you to the marshal until you choose. Warrior always uses "I am warrior";
other Loop three choices begin "I am ...." and from Loop four begin "I am". Class choice keeps gear and names the
matching trainer. Visit that trainer to learn the class's starter skills for free, with
no level requirement; new actives prefer empty slots in the upper row for maintenance
buffs and the lower row for rotation and situational abilities, using the other row
when needed. Existing assignments are preserved. Learning is permanent and needs
no relearning in later Loops. The initial Warrior pair remains known at New Game.
Milly now stands inside the abbey, and Farseer Lopaa stands beside its main entrance.
The northeast corner wall of the northern abbey room is a hidden passable tile,
retaining the ordinary wall art until a later visual hint is added.
Movement: WASD + QEZC, arrows, or numpad; wait: period/numpad 5.
Held movement waits 0.5 seconds, then repeats every 0.15 seconds.
F interacts; I inventory; K spells; J quests; P character; hotbar: 1–6, R, T, G, V; Shift for the upper row.
M opens the player menu.
Enter confirms, Escape cancels/opens Options, F11 toggles fullscreen.
Bump a friendly NPC to interact; bump a stationary neutral enemy twice to attack.
Mortal Strike uses your last attacked enemy in combat; before your
first attack, choose an enemy in melee range. Automatic attacks continue on that enemy
while it remains in melee range, including turns spent moving, waiting and using abilities.
Whirlwind casts directly from the hotbar against adjacent enemies, preserving the
selected attack target and ordinary swing timing. Heroic Strike and Incite are removed.
Early Warrior training adds Enrage from surviving enemy hits and passive Death Wish,
which increases physical damage dealt and damage taken as health falls. Its aura shows
the current tradeoff. Warrior Flurry is removed; Shaman retains its own Flurry.
The action effect resolves before player swings, followed by enemy actions. No attacks
are banked out of range and target changes keep the weapon's remaining delay.
Ordinary player swings and enemy melee attacks against the player show sequential
bumps, including misses. The action input gate stays closed until the bumps finish;
pending melee/casts still allow cancellation, except Charge. Bumps spend no extra turns.

Start with the marshal north of spawn; Willem stands west of the abbey. K → Development provides
XP, gold, Death trigger, and Kill stalker for quick experiments. The stalker
arrival schedule lives in the valley data. The first arrival kills the gate guard early
enough for a direct route to witness it. Defeating every present stalker immediately wins;
escape beyond the valley is the story outcome, with no gate lock or crossing action.
Death resets the attempt, preserving
learned abilities and hotbar. Visit Llane inside the abbey to buy Battle Shout,
Anger Management, Charge or Execute once your level and gold meet their requirements. Use the spell book to rearrange learned actives.
Execute uses the committed melee target, requires low target health, and shows current rage spending
in its tooltip and target picker. Its one-turn attack keeps weapon timing running; optional combo
empowerment remains for a later slice. Charge's wind-up and automatic
travel keep the player casting until arrival, blocking other actions and cancellation.
Charge arrival also allows the ready weapon to attack its target. These are current
mechanics; tuning and remaining v0.1 mechanics still need playtesting.
After all Warrior training is learned, Llane offers a reusable War Horn once each Loop.
Use it from Bags or the hotbar: a two-turn cast pulls neutral and hostile NPCs across
the current screen, requiring sight, with a 30-turn cooldown after completion. It
grants no combo points or attack procs and keeps the selected attack target. Death
removes the horn; retained learning lets you claim another in the next Loop.
After all Rogue training is learned, Jorik offers Lucky charm through the same farewell
dialogue once each Loop. Carrying it in Bags passively prevents one lethal hit, leaving
1 HP and replacing it with an inert Broken lucky charm. A later hit can still kill you.
Both forms are lost on death; saves retain the item and gift claim.
After all Paladin training is learned, Brother Sammuel offers Wartorn Banner through
the same once-per-Loop farewell dialogue. Its free one-turn use plants a nonblocking
banner beside you for 10 turns, giving you and friendly summons within 3 tiles 10% less
damage taken. Bags and hotbar support use; the ground outline and HUD show protection.
Saves retain the item, planted banner and claim. Death clears them and permits a new
gift with retained learning. The item and its claim persist in current saves.

Shaman starts with Lightning Shield and Lava Burst; Paladin with Seal of
Command and Judgement; Rogue with Eviscerate and the Relentless Assault passive.
All use rage. Retained abilities/passives work in every class. Training spends gold,
requires the current Loop's level, and does not spend player XP. Relentless Assault builds player-held
combo points from landed direct active attacks and ordinary main-hand hits, across
classes and targets, with one base point per world turn. Seal Fate can add an extra point
on an active crit; off-hand hits and bonus damage grant none. Eviscerate needs points
and a melee target and spends all held points on its physical attack. Learned Slice
and Dice adds attack haste using those same spent points, even on a miss. Slice and Dice
cannot be cast or assigned separately. Eviscerate inherently rolls a rage refund after
spending; combo points are never refunded. Opportunity is removed; Seal Fate and Bandit's Guile
continue to reward qualifying retained class attacks. Seal of Command is always on
once learned; it has no cast, refresh or hotbar slot. Blessing of Kings is also passive: active
Battle Shout grants +2 Strength, Agility and Stamina, without healing when refreshed.
All four class kits are available, including their actives and passives. The spell book
describes their provisional mechanics; passives can be focused and inspected but cannot
be cast or assigned. New catalogue data lives in
[class_toolkit_data.gd](../scripts/hero/class_toolkit_data.gd), alongside the existing
[starter and Warrior data](../scripts/hero/class_skill_data.gd).
Every class can equip any gear without level or learning requirements.
Ambidexterity improves off-hand damage when learned.
Lightning Shield and Windfury cost no rage but still use a world turn. Lava Burst
deals flat Fire damage independent of weapon damage and Strength. Its base cast takes
three turns. Maelstrom Weapon banks up to five stacks from the first landed primary
physical attack per action; stacks shorten the cast and improve critical chance. Five
stacks make it instant, still spending one turn. The HUD shows stack count and the
tooltip shows current cast time. Reserved stacks are spent only on valid completion,
including a miss; cancellation preserves them. Earth Shock control effects are removed. Strength of Earth
Totem and Elemental Warding are removed. Earth Elemental is now summoned by the
single-use Ancestral totem item, Farseer Lopaa's farewell gift after all Shaman training.
Use it free in one turn from Bags or the hotbar; failed placement preserves the item.
The elemental follows the player or an
engaged target and repeatedly taunts nearby engaged hostiles in sight. It lasts until
killed or Loop reset and blocks resummoning while alive. The gift is once per Loop;
death removes the item and summon and permits another gift with retained learning.
Lightning Shield includes its stronger six charges, and Windfury includes its stronger
bonus strikes without separate upgrade purchases.
Hands have independent timers; due swings resolve in time order, with main-hand first
on ties. Feral Spirit creates a temporary pair of wolves following your selected enemy,
inherently healing you from their actual damage dealt.
Instant and Deadly Poison cost no rage and become available together at the Rogue trainer; Catalytic
Venom unlocks later. Casting either coating with dual wield opens a hand picker:
directions choose main hand, off hand or both; Enter applies, Escape cancels freely.
Each hand keeps its own coating and expiration, shown separately in the aura display.
Single-weapon setups coat the main hand directly. Catalytic Venom rewards Instant
on the faster base-speed weapon and Deadly on the slower; equal-speed pairs do not
catalyze. Deadly stacks belong to each enemy and tick at the turn boundary, retaining
fractional damage across ticks. Saves retain coatings, stacks and pending tick damage.
Finishers spend all held points before refunds; Execute and Judgement do not spend points.
Consumable procs wait until used or death. Timed hero buffs expire at the advanced turn
boundary before player swings and enemy attacks. The same phase expires summons and
ordinary combat debuffs, then resolves Judgement, Consecration and Deadly
Poison in that order. Their handlers preserve the final verdict or poison tick.

The character screen shows Strength, Agility, Stamina, Armor, Crit and attack haste,
with weapon power and dodge as derived values. Gear works equally in all four classes.
Equipment has five slots: armor, neck, two rings and one weapon setup. Two-hand,
weapon-and-shield and dual-wield pairs each occupy one inventory/equipment slot.
Janos sells common gear, finite healing potions and unlimited food. Quest rewards cover
the common loadout; the mine and vineyard award final weapons. Mobs can drop poor gear
or rare uncommon upgrades; each chest guarantees common or uncommon equipment.
Poor/common/uncommon names appear gray/white/green; other item text stays white.
Bags and equipment replacement lists display uncommon, common, then poor items,
alphabetically within each quality. Actions retain the original inventory slots.
Selecting a replacement for an equipment slot previews stat gains and losses against
that exact slot, including either ring. Shields contribute armor.
Common and uncommon accessories have primary and secondary bonuses. Crit and haste
use direct percentage bonuses. Strength increases weapon power; Agility adds crit and
dodge. Weapon-based physical, Holy and Nature damage keeps fractional power until the
final integer result, using the existing weapon roll for unbiased rounding.
Mana, caster stats and the obsolete class catalogues
are removed, along with parry, block, glancing, crushing and spell resistance.

Ordinary enemy and stalker tuning lives in
[northshire_data.gd](../scripts/world/northshire_data.gd); level-gap modifiers live in
[melee_rules.gd](../scripts/combat/melee_rules.gd). New spawns and Loops use the current
profiles; saved actors keep their recorded stats. The current
[simulation bench](../bench/README.md) compares kits, weapon setups and encounters
using the live game model; generated results stay under ignored `reports/bench/`.
Garrick now has 120 HP and 7–9 base melee damage, retaining his level, armor and
2.6-turn swing interval. His first-Loop target is a close fight after free gear and
modest training; stronger preparation can make him reliable in later Loops.

Judgement retains its delayed verdict. It fixes damage and hit/critical results when
cast, shows a countdown on its target, and delivers the verdict before due weapon swings
and enemy actions. Impact ignores current range and never changes the selected target;
a target dying early loses its sentence. It casts on the engaged target and its hotbar
label turns red without learned Seal of Command. Art of War empowers a stronger critical,
and Judgement includes its flat
damage bonus without shortening the fixed base cooldown through haste.
Divine Purpose, Eye for an Eye and combo-point refunds are removed. Existing Holy/critical rewards happen on impact.
Consecration creates visible fixed Holy ground; leaving it does not move or cancel it.
Its periodic damage grants no attack procs or combo points and supplies no mitigation.

Current saves are `demo` revision 33, with gear stats rebuilt from equipment on load.
Revision 32 and older saves are incompatible and left unchanged; start a fresh game.
This revision replaces Heart of the Crusader's timed critical-chance debuff with a
saved, single-use melee vulnerability. No save migration is provided.
Kings bonuses are rebuilt from learned Kings plus active Shout, rather than saved
primary-stat buff fields. Failed writes/loads preserve existing player files.
Existing split wolf-quest records remain finishable; fresh routes offer the combined quest.
Committed Judgement verdicts and Consecration ground persist across saves;
both clear with the physical world on death.
Victory requires defeating all present stalkers.
Valley saves retain their map identity. Saves live in `%APPDATA%/Godot/app_userdata/Ostinato/saves/`;
global settings are in `options.json` beside that directory. Tests use isolated save locations. Preserve user
files during failures and declare future compatibility breaks explicitly.

## Editing the valley

Open [valley.tscn](../scenes/valley.tscn) in Godot's 2D editor. It is the layout
source read by New Game and death/Loop reset; the existing grid simulation and
`GridView` still run and draw the game. Run the main project to play the layout.

- `Terrain/Background` paints open ground and the blocked exterior.
  `Ground` paints roads, floors and soil. Abbey/mine floor tiles also mark indoors.
- `Terrain/Scenery` paints the original 16px art, scaled twice; `Props` paints the
  32px valley art. Both use tile custom data for movement/sight blocking. Flowers,
  bushes, small rocks, grass and signposts remain passable. Paint/erase cells in the
  TileMap editor; keep the terrain layers' transforms as supplied.
- `Actors` contains sprite placeholders for every initial contact, enemy and chest.
  Move them with 32px grid snapping. Positions are sprite centers (16px grid offset);
  the containing tile becomes the actor's starting/home tile. `wander_radius` sets
  its patrol area around that home; zero keeps it stationary.
- Keep an actor's `spawn_id` when moving it. When adding a creature by duplicating a
  placeholder, give it a unique `spawn_id` and `turn_order`; that order governs turns
  independently of tree order. `npc_id` selects existing contact/creature data. The
  Sprite2D texture/scale is an editor preview; update it when changing creature type.
  Contacts retain their identities/dialogue in `NpcDefinition`; creature stats remain
  in `NorthshireData`. Chests also carry a unique `treasure_id` and exploration hint.
- `PlayerSpawn`, ordered `StalkerEntries` markers and `Exploration` regions set their
  corresponding locations. Exploration regions expose their size in tiles. The map
  root exposes bounds and stalker deadlines. Summons and timed arrivals spawn during play.

The TileSets under [assets/tilesets](../assets/tilesets/) reference the existing sprite
sheets directly. Their `sprite`, `blocked` and `indoors` custom data feeds the grid
model; Godot physics collision shapes are not used for movement.

Start a New Game after layout edits. Existing saves retain their recorded actors,
collision and indoor state; this conversion preserves the current save format.

## Checks

Design experiments use the temporary [simulation bench](../bench/README.md), launched
with `pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Smoke`.
Its source is tracked separately in `bench/`; generated results, logs and runtime files
stay under ignored `reports/bench/`. Use the documented launcher for reusable approval.

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

- `scenes/`: main viewport, playable scene and editable valley layout.
- `scripts/world/`, `combat/`, `hero/`, `items/`, `quests/`: simulation, UI, and game data.
- `scripts/game_session.gd`, `save_codec.gd`, `save_store.gd`: Loops and persistence.
- `test/unit/`: behavioral GUT tests; `tools/`: setup, launch, and checks.
- `art/`: [editable Aseprite sources and sprite workflow](../art/README.md).
  Runtime sheets live in `assets/spritesheets/`; temporary SVGs in `assets/sprites/dev/`.
- `docs/direction.md`: durable intent; `docs/backlog.md`: local work, separate from design.

Follow [coding-style.md](coding-style.md); preserve `.gd.uid` and asset `.import` files.
Keep numerical data in code. Refactor a subsystem when its current task benefits, not
as a prerequisite to the pivot. The existing folder layout needs no wholesale move.

Work stays local unless requested otherwise. Summarize changes and useful playtest
steps in chat; create no handoff file. Humans choose what to test and commit.
