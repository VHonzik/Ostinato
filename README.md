# Ostinato

A 2D roguelike inspired by World of Warcraft Classic leveling.

Milestones 1–6 are playable: Northshire exploration and quests, grid movement, combat,
mage/druid training through level 10, items/trading, persistent learning across deaths,
class selection, five save slots, and the first demon stalker arrival.

Launch from PowerShell 7 with:
```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/validate.ps1
pwsh -NoProfile -File tools/godot.ps1
```

Choose **New Game**. Move with WASD + QEZC, arrows, or numpad; wait with period/numpad 5.
**F** interacts, **J** opens quests, **I** inventory, **K** spells, **P** character.
Escape cancels or opens Options. Targeted spells require Enter confirmation.

Start with Deputy Willem at (20,16), then Marshal McBride at (18,12).
The abbey door is (20,12); mage training is inside at (17,8).
Wolves live west, kobolds and Echo Ridge Mine north, and the vineyard is east across
the bridge at (32,22–24). Complete objectives, return to the named receiver, and choose
a reward. Quest log shows difficulty/progress and supports abandonment.
The stable at (7–13,12–18) contains the druid trainer and an equipment supply chest.
The trader remains at (16,18).

**K → Development → Death trigger** starts the next Loop. Learned ranks remain;
quests, loot and seeded populations reset. From Loop 2, the marshal offers druid at
level 1 before any quest acceptance. New population ordinals appear 30 turns after death.
The gate stalker arrives on turn 15. Saving requires an action boundary outside combat.

Saves use **demo revision 3**. Revision-1/2 saves remain untouched and incompatible.
Remaining classes, final content coverage, reinforcements and completion belong to
later milestones; see the [Northshire inventory](docs/data/northshire.md).
Windows desktop / Godot Compatibility is the target. Development skills are omitted
from release builds. CI and exports remain to be established.

- [Functional requirements](docs/requirements/functional.md)
- [Non-functional requirements](docs/requirements/non-functional.md)
- [Development, dependencies, and validation](docs/development.md)
- [Milestone 6 source data, adaptations and remaining content](docs/data/northshire.md)
- [GDScript coding style](docs/coding-style.md)
- [Architecture overview](docs/architecture/components.puml)
- [Project rules](AGENTS.md)
- [GitHub repository](https://github.com/VHonzik/Ostinato)
