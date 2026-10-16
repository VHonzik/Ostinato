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
class abilities, passives and player knowledge. Character
level, character XP, equipment, gold, quests and world state belong to the current
Loop and reset on death. There is no permanent equipment.

A powerful boss arrives early enough that a player heading directly for the exit sees
it kill the guard. Its first arrival serves that scene. Additional copies arrive on a
fixed global world-turn schedule. Defeating every currently present stalker immediately
wins the game. Escape into the world beyond is the story outcome; there is no gate lock
or movement requirement. Future copies do not prevent victory.
The intended route to victory combines roughly three developed classes with near-maximum
character level for the finite area. Two developed kits should usually struggle against
the boss, three should offer a viable attempt, and the complete set should give a strong
chance of victory. Aim for comparable class contributions while allowing modest weapon
preferences. Exceptional earlier victories should remain possible through skill and
route optimization. Simulation results are exploratory, not final
balance measurements; do not impose the old ten-minute first-Loop target.

## Classes, learning and combat

- Start as warrior with Mortal Strike and Whirlwind. Mortal Strike is the stronger
  single-target spender; Whirlwind spends spare rage and gains value against adjacent
  groups. Execute remains a later finisher. Heroic Strike and Incite are removed;
  further passive development remains open until the revised kit has been playtested.
  The roster is warrior, shaman, paladin and rogue.
- Choose the class to train at the marshal before accepting any quest.
  Warrior is mandatory in the first Loop; Shaman, Paladin and Rogue are selectable
  from Loop two. Returning Loops offer class selection first, focusing the previous class; choosing
  once locks the class until death and immediately reveals quests. Other contacts
  redirect the player to the marshal until that choice. Selection keeps gear and
  refers the player to the matching trainer. Keep the initial Warrior pair at New Game;
  learn other classes' starter skills free at their trainers, with no level requirement.
  Once learned, skills stay usable across classes and death without relearning;
  selection does not lock out the retained toolkit.
- All classes use rage, with no mana or energy. Learned Relentless Assault builds
  player-held combo points from landed direct active attacks, including retained
  attacks across classes, and ordinary main-hand hits. Relentless Assault grants at most
  one base point per world turn; Seal Fate can add its extra active-critical point.
  Off-hand hits, procs, buffs and misses grant no points.
  Points persist across targets and encounters and reset on death. Eviscerate is the
  starter active finisher: it requires a melee target and spends all held points.
  Learned Slice and Dice passively grants attack haste from the same spent points,
  including on a missed finisher. Finisher refunds happen once after spending.
  Execution Sentence replaces Judgement with a delayed verdict, without stacks or
  damage accumulation. It commits damage and hit/critical results on casting and
  delivers its attack rewards on impact, without retargeting. Consecration adds fixed
  Holy ground for positional play; its periodic damage has no attack procs or defense bonus.
  Preserve roughly the current overall damage contribution by redistributing damage
  rather than adding both abilities at full strength. Execution Sentence leaves Seal
  of Command active. Execute and Execution Sentence do not spend combo points.
- Warrior supplies physical burst, rage, execution and strength through taking damage.
  Enrage rewards surviving enemy hits; passive Recklessness trades more incoming damage
  for more physical damage as health falls, with a modest cap. Warrior has no Flurry;
  Shaman retains its attack-haste passive. Shaman starts with Lightning Shield and
  Earth Shock, supplies free weapon/shield preparation, reactive damage and tactical
  procs. Earth Shock deals flat Nature damage independent of weapons and Strength.
  Earth Elemental is a mobile, lasting summon that draws nearby engaged enemies
  away from the player; only one may be alive. Spirit wolves supply damage and healing.
  Strength of Earth Totem and Elemental Warding are removed.
  Paladin supplies Holy damage,
  buffs and guaranteed-critical payoffs. Blessing of Might is free maintenance;
  Seal of Command retains its rage cost for rotational flavor. Benediction is removed.
  Rogue supplies combo points, dual wielding,
  speed, poisons and finishers. Opportunity is removed. Seal Fate and Bandit's Guile
  reward qualifying retained attacks from other classes. The milestone covers the full v0.1 toolkit.
- Poisons cost no rage and offer a preparation choice: Instant rewards short fights, while Deadly
  builds sustained damage. A later Rogue passive rewards mixed coatings with Instant
  on the faster weapon and Deadly on the slower. Its extra stack is a deliberate
  interaction; poison damage does not trigger further attack procs. Keep finishers
  from bypassing Deadly's buildup for free.
- Training requires the current Loop's character level and charges gold per skill;
  player XP is not spent. Starter skills are free. Learning remains permanent across
  death and classes, and retained skills work below their original training level.
  Ability use grants no separate class XP. Aim for roughly five completed Loops to
  learn a class, preserving early core tools and spreading later purchases through
  rising prices. Do not require earlier skills to buy an eligible later skill.
  Character XP comes from kills and quests and resets with gold and level on death.
- Every world turn advances independent, fractional weapon timers, including turns
  spent on active abilities, movement and waiting; abilities must not pause the timer.
  Deliberate attack bumps commit to advancing until the next swing.
  Keep friendly-bump interaction and the existing second-bump protection for neutral
  enemies; hostile enemies are attacked on the first bump. A fresh weapon is ready.
  Resolve the action's effect, then due player swings, then enemy actions. Continue
  attacking the selected enemy in melee range; never silently retarget or bank swings
  while out of range. Retargeting retains remaining weapon delay. Resolve multiple
  due swings in order and stop on death. Playtest this ordering and control rhythm.
- Main-hand auto-attacks and incoming hits supply rage; rage decays outside combat.
  Ordinary swing rage scales with base weapon speed, independently of haste.
  Attack speed changes weapon timing, not action count or ordinary ability cooldowns;
  Sanctity of Battle explicitly divides Execution Sentence's cooldown by current attack haste,
  rounding up to a whole turn. Pursuit of Justice adds fractional movement credit,
  occasionally allowing an extra grid step in the chosen direction.
- Bonus strikes do not recursively trigger procs or generate ordinary swing rage.
  Define qualifying events consistently for crits, combo points and procs.
  Art of War counts at most one Holy event per attack action. Shaman Flurry grants
  attack-haste charges. Bonus strikes cannot crit or trigger primary
  attack hooks. Spirit wolves follow the selected enemy;
  Spirit Hunt heals from their actual damage taken by the target.
- Consumable triggered procs persist until used or death. Timed buffs persist between
  encounters until their duration expires. Timed hero buffs expire at
  the advanced world-turn boundary after the committed action's effect. Expire timed
  combat effects first, then resolve delayed verdicts, ground damage and poison ticks
  before due player swings and enemy actions. Simplify combat to
  health, armor, dodge and weapon hit chance (needed by Precision), with physical,
  Holy and Nature damage and the explicit class defenses. Attacks can miss, be dodged,
  hit or crit; shields contribute armor. Holy and Nature damage bypass armor.
  Higher-level enemies reduce accuracy; their percentage penalty to player damage
  matches their percentage increase to incoming damage,
  without the old attack tables. A starter Warrior should struggle against one enemy
  two levels higher or a pair near its own level; larger pulls should usually kill it.
  Retained mixed-class learning should eventually make three enemies two levels higher
  manageable. Costs, durations, chances, damage formulas
  and stat scaling belong in code/data; the snapshot's tuning remains provisional.
- Keep the existing session/save structure and bump the save revision when compatibility
  changes. Preserve old files and failed-write/load protections; do not add experimental
  migrations. Keep saving at action boundaries outside combat.

## World and equipment

- Keep a deliberate world with recognizable contacts and route choices rather than
  a complete Northshire database replica. Ordinary enemy respawning remains open;
  the current build has none within a Loop.
- Keep temporary equipment, inventory, gold, quests and traders as tactical route
  resources. Use armor, neck, two ring slots and one weapon setup: two-hand,
  main-hand plus shield pair, or dual-wield pair. Weapon names are flavor;
  Gear has no class, level or learning requirements. Ambidexterity improves
  off-hand damage in any class once learned.
  Shields should offer a defensive preference without becoming the strongest
  general-purpose weapon setup.
  Poor gear is gray with no stat bonuses and low damage/armor. Common gear is white
  with modest damage/armor and small crit/haste bonuses; common necklaces and rings
  also have primary stats. Uncommon gear is green with
  primary and secondary bonuses and better damage/armor. Start poor; quests and
  merchants supply a complete common loadout, including guaranteed final weapons.
  Uncommon gear comes from rare world drops and less frequent chest rolls; each chest
  guarantees common or uncommon gear. Necklaces and rings are common or uncommon.
  Merchants stock limited healing potions and abundant food. Keep bonuses small but
  meaningful, and prices attainable through ordinary encounters and sold loot.
  The primary stats are strength, agility and stamina; the secondary stats
  are armor, crit and haste. Strength increases weapon damage, agility increases crit
  and dodge, stamina increases health, armor reduces physical damage, crit adds critical
  chance and haste speeds weapon swings. These effects are independent of the selected
  class. Small primary bonuses must matter; preserve fractional weapon power through
  damage resolution so rounding cannot erase them. Crit and haste bonuses remain direct
  percentages, with small numbers on gear. Keep existing weapon-based Holy/Nature scaling
  except for flat-damage Earth Shock;
  broader damage/healing scaling
  remains open. Slow weapons favor weapon-damage abilities; fast
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
- Next: Whirlwind versus Mortal Strike rage economy and later passive development;
  optional combo empowerment for Execute/Execution Sentence; gear ranges, weapon progression,
  respawns and healing.
- During the complete-toolkit playtest: revise provisional passive/proc behavior,
  wolf usefulness, movement credit and the Execution Sentence haste exception as needed.
- Later: additional talents/synergies and leaderboard categories or achievements.

Keep answers brief here when they become durable direction. Keep tuning values and
implemented rules in code/data, not duplicated tables in documentation.
