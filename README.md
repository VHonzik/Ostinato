# Ostinato

A 2D roguelike inspired by World of Warcraft Classic leveling.

Milestones 1–5 are playable: grid movement, melee combat, hero progression,
mage/druid training through level 10, loot, equipment, consumables, trading,
persistent learning across deaths, class selection,
five save slots, and the first demon stalker arrival. The development target is
Windows desktop using Godot's Compatibility renderer.

From this directory in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/validate.ps1
pwsh -NoProfile -File tools/godot.ps1
```

Choose **New Game**. Move with WASD + QEZC, arrows, or the numpad; wait with
period or numpad 5. **P** opens Character, **K** the spell book, **I** inventory/equipment,
and **F** interacts. Targeted spells require Enter confirmation; Escape cancels
targeting or a pending cast/attack. Escape from gameplay opens Options and save/load.

To try the Loop: use **K → Development → Death trigger**. Loop 2 starts at level 1.
Move northwest beside Marshal McBride and interact to choose druid, then visit the
druid trainer southwest of him. Learn free starting skills, use them, and die again:
the next mage retains those ranks. The first stalker arrives at the eastern gate on
turn 15. Saving requires a completed action outside combat; loading restores the
saved Loop and its simulation state.

For items, interact beside **Training supplies** at (19,19). Collect its copper and
equipment, use **I** to equip, and visit the trader at (16,18). The mage/druid trainers
at (17,14)/(17,16) list each rank's level, cost and prerequisite. Learned ranks survive
death; items and copper reset. Saves use **demo revision 2**; earlier revision-1 saves
are incompatible and remain untouched.

The training grounds remain a development map. The populated Northshire zone, other
classes, reinforcements, and demo completion belong to later milestones. Development skills are omitted from release
builds. CI and export builds remain to be established.

- [Functional requirements](docs/requirements/functional.md)
- [Non-functional requirements](docs/requirements/non-functional.md)
- [Development, dependencies, and validation](docs/development.md)
- [Milestone 5 source data and adaptations](docs/data/learning-baseline.md)
- [GDScript coding style](docs/coding-style.md)
- [Architecture overview](docs/architecture/components.puml)
- [Project rules](AGENTS.md)
- [GitHub repository](https://github.com/VHonzik/Ostinato)
