# Ostinato

A 2D roguelike inspired by World of Warcraft Classic leveling.

Milestones 1–4 are playable: grid movement, melee combat, hero progression,
mage/druid starting spells, persistent learning across deaths, class selection,
five save slots, and the first demon stalker arrival. The development target is
Windows desktop using Godot's Compatibility renderer.

From this directory in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/validate.ps1
pwsh -NoProfile -File tools/godot.ps1
```

Choose **New Game**. Move with WASD + QEZC, arrows, or the numpad; wait with
period or numpad 5. **P** opens Character, **K** the spell book, **I** the outfit,
and **F** interacts. Targeted spells require Enter confirmation; Escape cancels
targeting or a pending cast/attack. Escape from gameplay opens Options and save/load.

To try the Loop: use **K → Development → Death trigger**. Loop 2 starts at level 1.
Move northwest beside Marshal McBride and interact to choose druid, then visit the
druid trainer southwest of him. Learn free starting skills, use them, and die again:
the next mage retains those ranks. The first stalker arrives at the eastern gate on
turn 15. Saving requires a completed action outside combat; loading restores the
saved Loop and its simulation state.

The training grounds remain a development map. Higher-rank training, loot/item
services, the populated Northshire zone, other classes, reinforcements, and demo
completion belong to later milestones. Development skills are omitted from release
builds. CI and export builds remain to be established.

- [Functional requirements](docs/requirements/functional.md)
- [Non-functional requirements](docs/requirements/non-functional.md)
- [Development, dependencies, and validation](docs/development.md)
- [Milestone 4 source data and adaptations](docs/data/loop-baseline.md)
- [GDScript coding style](docs/coding-style.md)
- [Architecture overview](docs/architecture/components.puml)
- [Project rules](AGENTS.md)
- [GitHub repository](https://github.com/VHonzik/Ostinato)
