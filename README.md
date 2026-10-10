# Ostinato

A keyboard-first Godot roguelike about learning across repeated lives, inspired by WoW.
The project is pivoting toward melee combat, persistent class tracks, and a smaller,
more readable world. The current playable build still contains the earlier caster design.

From PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/godot.ps1
```

Choose New Game. Move with WASD + QEZC, arrows, or numpad; wait with period/numpad 5.
F interacts, I opens inventory, K spells, J quests, P character, and 1–5 the hotbar.
Escape cancels or opens Options. Targeted spells require Enter confirmation.

- [Game direction](docs/direction.md)
- [Local backlog](docs/backlog.md)
- [Setup, current build, and checks](docs/development.md)
- [Coding style](docs/coding-style.md)
- [Working rules](AGENTS.md)
