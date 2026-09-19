# Ostinato

A 2D roguelike game development project inspired by World of Warcraft Classic leveling.

Milestone 1 is playable: eight-direction grid movement, fractional speed, blocking, and
wandering NPCs that act only after a player turn. The initial development
target is Windows desktop using Godot's Compatibility renderer.

From this directory in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/validate.ps1
pwsh -NoProfile -File tools/godot.ps1 --editor
```

To run the movement fixture directly:

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
Use the fixture speed controls to try fractional movement, and Esc to return focus to play.
The [development guide](docs/development.md#milestone-1-movement-fixture) describes the fixture.
The repository is hosted at [VHonzik/Ostinato](https://github.com/VHonzik/Ostinato).
CI and export builds remain to be established.
Local engine binaries and generated reports are excluded by the prepared Git configuration.
