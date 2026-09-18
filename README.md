# Ostinato

A 2D roguelike game development project inspired by World of Warcraft Classic leveling.

The current project is a development bootstrap with a title scene. The initial development
target is Windows desktop using Godot's Compatibility renderer.

From this directory in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/validate.ps1
pwsh -NoProfile -File tools/godot.ps1 --editor
```

To run the title scene directly:

```powershell
pwsh -NoProfile -File tools/godot.ps1
```

- [Functional requirements](docs/requirements/functional.md)
- [Non-functional requirements](docs/requirements/non-functional.md)
- [Development, dependencies, and validation](docs/development.md)
- [GDScript coding style](docs/coding-style.md)
- [Architecture overview](docs/architecture/components.puml)
- [Project rules](AGENTS.md)

Gameplay requirements incorporate the owner review; gameplay implementation has not started.
The repository is hosted at [VHonzik/Ostinato](https://github.com/VHonzik/Ostinato).
CI and export builds remain to be established.
Local engine binaries and generated reports are excluded by the prepared Git configuration.
