# Development

Windows x64, Godot Compatibility renderer, typed GDScript.

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

The project targets a playable demo of the full game. The main menu displays
**Ostinato (Demo)**; the valley is the demo's playable scope.

**New Game** offers five named world seeds, then launches the valley, the sole playable
map, as a Warrior with Mortal Strike and Whirlwind. The player menu shows the chosen
world name. Speak to Marshal McBride north of spawn, ask Janos inside the
abbey for starter gear, and use quests, trading and training to prepare for the gate.
Death rebuilds the physical world; learned abilities and hotbar assignments persist.
Returning Loops begin with class selection; other classes unlock from Loop three.
Defeat every currently present stalker to complete the demo.

Use the authoritative references for current content and code entry points:

- [Class mechanics and abilities](class-mechanics.md): training, costs, combat rules,
  passives, effects and trainer gifts.
- [Quests, dialogue and NPCs](npc-dialogue.md): contacts, objectives/rewards, speech,
  encounter profiles, arrivals and Loop state.
- [Game direction](direction.md): design goals and open gameplay decisions.
- [Art workflow](../art/README.md) and [art direction](art-plan.md): sources and presentation.

### Controls

Movement, hotbar and menu bindings can be changed in Options → Keybindings.

| Action | Default input |
| --- | --- |
| Move | WASD + QEZC, arrows or numpad |
| Wait | Period / numpad 5 |
| Interact | F; bump friendly NPCs; bump a stationary neutral twice to attack |
| Inventory / spells / quests / character | I / K / J / P |
| Player menu | M |
| Lower hotbar | 1–6, R, T, G, V |
| Upper hotbar | Shift plus the same keys |
| Confirm / cancel | Enter / Escape |
| Options / fullscreen | Escape when no action/menu is open / F11 |

Held movement waits 0.5 seconds, then repeats every 0.15 seconds. Targeted abilities
use the committed enemy or a target picker according to their rules. Automatic
swings continue against the selected enemy in melee during movement, waiting and
abilities. Attack bumps animate sequentially; input waits for them to finish.
K → Development provides XP, gold, Death trigger and Kill stalker in development builds.

### Equipment and interaction

Equipment uses armor, neck, two rings and one weapon setup. Two-hand, shield-pair
and dual-wield setups each occupy one slot. All classes can use all gear. Bags sort
by quality, then name; replacement previews compare the selected equipment slot.
Empty equipment slots auto-equip received gear. An inventory hint marks higher-quality
bag items available for equipped slots.

Usable bag items offer **Assign to hotbar** while the layout is unlocked. Receiving a
healing potion assigns it immediately left of Food when that slot is empty in the same
row and no potion shortcut exists. Saves retain the player's exact assignments, including
empty slots; loading does not auto-assign items.

Closed chests block movement. Bumping opens their loot menu without collecting or
spending a turn; full bags preserve uncollected loot. Bumping a newly killed enemy
opens loot until the player moves; later corpse interaction uses F. Ordinary
loot-bearing corpses hide after 300 turns; the guard's corpse remains.

### Saves and settings

Saving requires an action boundary outside combat. Five slots use the `demo` family,
revision 1; other revisions are incompatible and left untouched. No migration is
provided. Failed writes/loads preserve existing files and the running world.

Saves live in `%APPDATA%/Godot/app_userdata/Ostinato/saves/`; global settings are in
`options.json` beside that directory. Tests use isolated save locations. See the
content references above for effect, quest and NPC persistence.

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

Start a New Game to test the complete edited layout. Saves retain enemy/chest placements,
collision and indoor state; fixed contacts except the guard follow current scene
positions on load. The northeast corner of the northern abbey room is passable despite
its wall art.

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
Keep numerical data in code. Refactor only when it helps the current task.

Work stays local unless requested otherwise. Summarize changes and useful playtest
steps in chat; create no handoff file. Humans choose what to test and commit.
