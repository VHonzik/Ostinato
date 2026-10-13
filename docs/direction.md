# Game direction

The October 2026 time-loop RPG design snapshot v0.1 guides the current pivot.
It replaces the old requirements and Vanilla content-completion plan.
This is intended direction, not a claim about what the current build implements.
Current work lives in [the backlog](backlog.md). Earlier requirements, research and
the transitional pivot retrospective remain in Git history.

## Game and Loop

A keyboard-first, turn-based grid RPG in a small, finite starting area with one guarded
exit. Keep the sense of a familiar human starting zone threatened by an invasion.
WoW supplies flavor and ideas, not binding formulas or content inventories.

Death is the only Loop reset. It restores the physical world while preserving learned
class abilities, passives, cumulative class mastery and player knowledge. Character
level, character XP, equipment, gold, quests and world state belong to the current
Loop and reset on death. There is no permanent equipment.

A powerful boss guards the exit from early in each Loop; additional copies arrive on
a fixed global world-turn schedule. Victory means defeating the obstacle and escaping.
The intended route to victory combines roughly three developed classes with near-maximum
character level for the finite area. Exceptional earlier victories should remain possible
through skill and route optimization. Simulation results are exploratory, not final
balance measurements; do not impose the old ten-minute first-Loop target.

## Classes, learning and combat

- Start as warrior. The roster is warrior, shaman, paladin and rogue; remove obsolete
  mage, druid, warlock and priest content in runnable gameplay changes.
- Choose which class track to advance at the marshal before accepting any quest.
  Warrior is mandatory in the first Loop; Shaman, Paladin and Rogue are selectable
  from Loop two. Returning Loops begin in the previous class; confirming a class,
  including that same class, locks the choice until death. Selection keeps gear and
  refers the player to the matching trainer. Keep the initial Warrior pair at New Game;
  learn other classes' starter skills free at their trainers, with no class XP requirement.
  Once learned, skills stay usable across classes and death without relearning;
  selection does not lock out the retained toolkit.
- All classes use rage, with no mana or energy. Learned Relentless Assault builds
  player-held combo points from landed direct active attacks, including retained
  attacks across classes. Auto-attacks, procs, buffs and misses grant no points.
  Points persist across targets and encounters and reset on death. Slice and Dice
  requires points and deliberately spends all held points to extend its attack haste.
  Judgement takes a turn and leaves Seal of Command active.
- Warrior supplies physical burst, rage and execution; shaman supplies weapon
  enhancements, reactive damage and tactical procs; paladin supplies Holy damage,
  buffs and guaranteed-critical payoffs; rogue supplies combo points, dual wielding,
  speed and opportunistic damage. The milestone covers the full v0.1 toolkit.
- Only abilities belonging to the selected class advance that class's XP. Retained
  abilities from other classes remain usable but award no class XP. Count all uses
  of the selected class's abilities for now, without meaningful-use or anti-spam
  restrictions. Class XP accumulates toward thresholds and is not spent on unlocks.
  Keep the current trainer structure: visit
  the matching trainer to learn eligible abilities, which become usable immediately
  and remain learned across death. Character XP comes from kills and quests and resets.
- Every world turn advances independent, fractional weapon timers, including turns
  spent on active abilities, movement and waiting; abilities must not pause the timer.
  Deliberate attack bumps and Heroic Strike commit to advancing until the next swing.
  Keep friendly-bump interaction and the existing second-bump protection for neutral
  enemies; hostile enemies are attacked on the first bump. A fresh weapon is ready.
  Resolve the action's effect, then due player swings, then enemy actions. Continue
  attacking the selected enemy in melee range; never silently retarget or bank swings
  while out of range. Retargeting retains remaining weapon delay. Resolve multiple
  due swings in order and stop on death. Playtest this ordering and control rhythm.
- Main-hand auto-attacks and incoming hits supply rage; rage decays outside combat.
  Ordinary swing rage scales with base weapon speed, independently of haste.
  Heroic Strike reserves rage and commits until the next main-hand swing, replacing it
  and forfeiting its ordinary rage. A miss consumes the queue; cancellation or target
  loss refunds the reservation while preserving elapsed turns.
  Attack speed changes weapon timing, not action count or ordinary ability cooldowns;
  Sanctity of Battle is an explicit cooldown exception with its formula still open.
- Bonus strikes do not recursively trigger procs or generate ordinary swing rage.
  Define qualifying events consistently for crits, class XP, combo points and procs.
  Art of War counts at most one Holy event per attack action; Incite cannot retrigger
  itself, and Warrior/Shaman Flurry must share or upgrade one effect.
- Buffs persist between encounters until their duration expires. Simplify combat to
  health, armor, dodge and weapon hit chance (needed by Precision), with physical,
  Holy and Nature damage and the explicit class defenses. Retire legacy parry, block,
  glancing/crushing and the detailed spell-resistance model. Revisit level differences
  without retaining the old attack tables. Costs, durations, chances, damage formulas
  and stat scaling belong in code/data; the snapshot's tuning remains provisional.
- Keep the existing session/save structure and bump the save revision when compatibility
  changes. Preserve old files and failed-write/load protections; do not add experimental
  migrations. Keep saving at action boundaries outside combat.

## World and equipment

- Keep a deliberate world with recognizable contacts and route choices rather than
  a complete Northshire database replica. Ordinary enemy respawning remains open;
  the current build has none within a Loop.
- Keep temporary equipment, inventory, gold, quests and traders as tactical route
  resources. Equipment supports main/off-hand or a two-handed weapon, armor and two
  accessories. Strength, agility, stamina, crit and haste affect damage/attack mechanics
  rather than the selected class. Slow weapons favor weapon-damage abilities; fast
  weapons favor on-hit effects.
- Merchants have fixed inventory and prices; quest rewards are fixed. Enemy loot is
  determined by the world seed and stable enemy identity. Chest contents and positions
  are seeded from predefined spawn points. The same seed recreates the same world
  across Loops, independently of action order.
- Finite quests and encounters bound character progression. Decide the XP curve,
  level ceiling, level-difference scaling and healing availability through playtesting.
- Let new Loops reveal dialogue and the player's realization of the Loop. NPCs do not
  know about the Loop, and their knowledge of the invasion is much more limited.
- Future challenges can compare loops, total turns, lowest-level wins and class
  exclusions, preferably per seed or through shared challenge seeds. Leaderboard
  categories and achievements remain open.

## Presentation

- Use a 1280×720 logical canvas and minimum window, with 32×32 world tiles. Double
  the existing 16px art as a placeholder, preserving the base view's world scale.
  Reuse the valley and selected art for the new prototype.
- Keep outdoor ground plain. Show prominent terrain features such as trees, stones,
  flowers, sparse grass tufts, roads and landmarks rather than repeating grass tiles.
  Use fewer grass tufts in wooded areas.
- Follow the owner's [UI sketch](UI_design.svg): compact player frame at upper left,
  a scrolling combat log at lower left, two centered hotbar rows, player menus at lower right,
  and buffs/debuffs below the player. Ten slots per row: 1–6, R, T, G, V on the
  bottom row; Shift plus the same keys on the upper row. Judge layout and text
  readability through human review, without automated resolution/fit checks.
  Keep the log compact with no separate log screen; menu buttons show their shortcuts.

## Still to decide, when the relevant task starts

- First: unlock ordering and thresholds; character XP/level
  scaling; boss behavior and clone schedule.
- Next: Heroic Strike versus Mortal Strike rage economy; world-turn buff expiry
  ordering; Eviscerate's spending interface and optional combo empowerment for
  Execute/Judgement; gear ranges, weapon progression,
  respawns and healing.
- When their abilities are built: wolf damage/healing, shared Flurry,
  Pursuit of Justice's movement-speed meaning in a turn-based grid, Sanctity of Battle's
  cooldown formula, qualifying proc events and any otherwise unspecified passive details.
- Later: additional talents/synergies and leaderboard categories or achievements.

Keep answers brief here when they become durable direction. Keep tuning values and
implemented rules in code/data, not duplicated tables in documentation.
