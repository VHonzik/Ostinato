# Ostinato

A 2D roguelike game development project inspired by World of Warcraft Classic leveling.

Milestones 1–2 are playable: grid movement and wandering NPCs, a mage character sheet,
a spell book, one-turn development skills, and Classic XP progression with chat feedback. The initial development
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
The [development guide](docs/development.md#milestone-2-hero-emerges) describes the fixture.
The repository is hosted at [VHonzik/Ostinato](https://github.com/VHonzik/Ostinato).
CI and export builds remain to be established.
Local engine binaries and generated reports are excluded by the prepared Git configuration.
