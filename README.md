# Ostinato

A keyboard-first, turn-based Godot roguelike about learning across repeated lives,
inspired by WoW. Explore the valley, complete quests and train Warrior, Shaman,
Paladin and Rogue abilities that remain learned after death. Defeat every present
demon stalker to win.

From PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/godot.ps1
```

Choose New Game. Move with WASD + QEZC, arrows, or numpad; wait with period/numpad 5.
F interacts, I opens inventory, K spells, J quests, P character and M the player menu.
Hotbar: 1–6, R, T, G, V; Shift for the upper row. Enter confirms target choices;
Escape cancels or opens Options; F11 toggles fullscreen.

Start with Marshal McBride north of spawn, then ask Janos inside the abbey for gear.
New Game starts as Warrior; returning Loops require a class choice at the marshal,
with Shaman, Paladin and Rogue available from Loop three.

- [Game direction](docs/direction.md)
- [Local backlog](docs/backlog.md)
- [Setup, current build, and checks](docs/development.md)
- [Current class mechanics and abilities](docs/class-mechanics.md)
- [Current quests, dialogue and NPCs](docs/npc-dialogue.md)
- [World art and sprite workflow](art/README.md)
- [Coding style](docs/coding-style.md)
- [Working rules](AGENTS.md)
