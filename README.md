# Ostinato

A 2D roguelike game development project inspired by World of Warcraft Classic leveling.

Milestones 1–3 are playable: grid movement, hero progression, melee combat, NPC
pursuit, friendly/neutral interactions, kill XP, and a temporary death overlay. The initial development
target is Windows desktop using Godot's Compatibility renderer.

From this directory in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/validate.ps1
pwsh -NoProfile -File tools/godot.ps1 --editor
```

To run the training fixture directly:

```powershell
pwsh -NoProfile -File tools/godot.ps1
```

- [Functional requirements](docs/requirements/functional.md)
- [Non-functional requirements](docs/requirements/non-functional.md)
- [Development, dependencies, and validation](docs/development.md)
- [GDScript coding style](docs/coding-style.md)
- [Architecture overview](docs/architecture/components.puml)
- [Project rules](AGENTS.md)

Move with WASD + QEZC, arrows, or the numpad; wait with period or numpad 5.
Open Character with P or the spell book with K. In the Development tab, cast Gain 450 XP
to reach level 2 with 50 XP left over. Use the fixture speed controls to try fractional
movement, and Esc to return focus to play.
Use F to interact with an adjacent NPC; a lone candidate skips selection. Neutral
attacks explicitly ask for confirmation with Enter; Esc cancels. Hostile bumps request
melee, automatically waiting until the swing is ready. Esc or Cancel attack stops a
pending attack between turns. Interactions with no choices report in chat. Reset
restarts after death.
The [development guide](docs/development.md#milestone-3-fight) describes the fixture.
The repository is hosted at [VHonzik/Ostinato](https://github.com/VHonzik/Ostinato).
CI and export builds remain to be established.
Local engine binaries and generated reports are excluded by the prepared Git configuration.
