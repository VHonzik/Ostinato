# Game direction

Durable design goals and open decisions. Implemented details live in
[class mechanics](class-mechanics.md) and [quests, dialogue and NPCs](npc-dialogue.md);
current tasks live in [the backlog](backlog.md).

The current project target is a playable demo of the full game. The valley is the
demo's playable scope; escaping it completes the demo and points toward the wider world.
PC is the primary platform; Android is a secondary build for portable play and testing.

## Game and Loop

A turn-based grid RPG, with keyboard-first desktop controls and a separate landscape
touch interface, in a small, finite starting area with one guarded
exit. Keep the sense of a familiar human starting zone threatened by an invasion.
WoW supplies flavor and ideas, not binding formulas or content inventories.

Death is the only Loop reset. It restores the physical world while preserving learned
class abilities, passives and player knowledge. Character
level, character XP, equipment, gold, quests and world state belong to the current
Loop and reset on death. There is no permanent equipment.

A powerful boss arrives early enough that a player heading directly for the exit sees
it kill the guard. Its first arrival serves that scene. Additional copies arrive on a
fixed global world-turn schedule. Defeating every currently present stalker immediately
completes the demo. Escape into the world beyond is the story outcome; there is no gate lock
or movement requirement. Future copies do not prevent victory.
The intended route to victory combines roughly three developed classes with near-maximum
character level for the finite area. Two developed kits should usually struggle against
the boss, three should offer a viable attempt, and the complete set should give a strong
chance of victory. Aim for comparable class contributions while allowing modest weapon
preferences. Exceptional earlier victories should remain possible through skill and
route optimization. Simulation results are exploratory, not final
balance measurements. Let playtesting determine Loop length.

Stalker Fel Breath is a one-action sideways dodge check. Normal combat comparisons
should assume leaving the marked cone, rather than balancing around taking its hit.
Keep its warning, response window and melee pause; tune boss health and melee damage
for encounter difficulty.

## Classes, learning and combat

- The roster is Warrior, Shaman, Paladin and Rogue. Start as Warrior with Mortal
  Strike for single-target burst and Whirlwind for adjacent groups.
- Choose the class to train at the marshal before accepting any quest. Warrior is
  mandatory in the first two Loops; the other classes unlock from Loop three.
  Returning Loops focus the previous class; selection locks training until death,
  keeps gear and refers the player to the trainer and Janos. Remember class choices
  independently of training. Other contacts redirect the player until selection.
- All classes use rage. Retained actives and passives work across classes and death.
  Rogue combo points belong to the player across targets and encounters; Eviscerate
  spends them for a finisher and learned passive haste. Execute and Judgement use
  their own gates rather than combo points.
- Preserve distinct contributions: Warrior offers physical burst, rage and risk from
  taking damage; Shaman offers weapon/shield preparation, reactive damage, banked
  Lava Burst and summons; Paladin offers Holy damage, a delayed verdict, fixed ground
  and defensive buffs; Rogue offers combo points, dual wielding, poisons and finishers.
  Exact abilities, proc interactions and tuning belong in the class reference.
- Aim for this typical developed mixed-kit priority: prepare poisons, Windfury, Battle
  Shout and Lightning Shield before pulling; Charge into Mortal Strike; full-stack
  Lava Burst (also a ranged pull when Charge is unavailable); passively empowered
  Judgement if its target will survive the delay; five-point Eviscerate, especially
  to sustain Slice and Dice; available Execute; exhausted Lightning Shield;
  Whirlwind against at least three adjacent enemies; Consecration against at least
  three enemies that will stay in its area; Mortal Strike; remaining actions.
  This describes usual offensive choices, allowing emergency defenses, movement and
  encounter-specific decisions. Review the interacting passives and resource economy
  together so the choices earn their positions. Do not implement an automatic rotation
  or ability locks to enforce a preferred ordering.
- Poisons cost no rage and offer a preparation choice: Instant rewards short fights, while Deadly
  builds sustained damage. A later Rogue passive rewards active Instant
  and Deadly coatings on opposite hands regardless of weapon speeds. Its extra stack is a deliberate
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
  attacking the selected enemy in melee range; keep a valid commitment and never bank swings
  while out of range. With no valid commitment, an enemy attempting to attack the player
  becomes committed; melee bumps can select another. Retargeting retains remaining weapon delay. Resolve multiple
  due swings in order and stop on death. Playtest this ordering and control rhythm.
- Developed characters should gain efficient large-pull clearing through area damage.
  Evaluate these fights with normal maintenance buffs prepared. Roughly sixteen
  same-level regular enemies should be a serious pull that rewards defensive cooldowns;
  kill healing should not sustain arbitrarily large melee packs.
- Main-hand auto-attacks and incoming hits supply rage; rage decays outside combat.
  Ordinary swing rage scales with base weapon speed, independently of haste.
  Attack speed changes weapon timing, not action count or ordinary ability cooldowns;
  Judgement also keeps its base cooldown regardless of haste.
  Pursuit of Justice adds fractional movement credit,
  occasionally allowing an extra grid step in the chosen direction.
- Bonus strikes do not recursively trigger procs or generate ordinary swing rage.
  Define qualifying events consistently for crits, combo points and procs.
  Art of War counts at most one Holy event per attack action. Shaman Flurry grants
  attack-haste charges. Bonus strikes cannot crit or trigger primary
  attack hooks. Spirit wolves follow the selected enemy;
  their own hits heal from actual damage taken by the target, excluding overkill.
- Consumable triggered procs persist until used or death. Timed buffs persist between
  encounters until their duration expires. Timed hero buffs expire at
  the advanced world-turn boundary after the committed action's effect. Expire timed
  combat effects first, then resolve delayed verdicts, ground damage and poison ticks
  before due player swings and enemy actions. Simplify combat to
  health, armor, dodge and weapon hit chance (needed by Precision), with physical,
  Holy, Fire and Nature damage and the explicit class defenses. Attacks can miss, be dodged,
  hit or crit; shields contribute armor and enable learned Warrior Shield Block's
  partial physical defense. These magic schools bypass armor and Shield Block.
  Dodge is flat in every direction. Higher-level enemies
  reduce accuracy without Precision; their percentage penalty to player damage
  matches their percentage increase to incoming damage. A starter Warrior should
  struggle against one enemy two levels higher or a pair near its own level; larger
  pulls should usually kill it.
  Retained mixed-class learning should eventually make three enemies two levels higher
  manageable. Costs, durations, chances, damage formulas
  and stat scaling belong in code/data; tuning remains provisional.
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
  gear has no class, level or learning requirements. Ambidexterity improves
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
  while Lava Burst uses flat Fire damage independent of weapon power;
  broader damage/healing scaling
  remains open. Slow weapons favor weapon-damage abilities; fast
  weapons favor on-hit effects.
- Merchants have fixed inventory and prices; quest rewards are fixed. Enemy and chest
  loot is determined by the world seed and stable spawn identity. Chest placements
  are authored in the valley scene. The same seed recreates loot across Loops,
  independently of action order. New Game offers five fixed, named worlds so players
  can learn a world's loot routes and replay or share the same choice. Together the
  choices cover all uncommon weapon setups; one deliberately poor world is marked
  HARD for scarce uncommon gear and no uncommon weapon drops.
- Finite quests and encounters bound character progression. Decide the XP curve,
  level ceiling, level-difference scaling and healing availability through playtesting.
- Let new Loops reveal dialogue and the player's realization of the Loop. NPCs do not
  know about the Loop, and their knowledge of the invasion is much more limited.
- Future challenges can compare loops, total turns, lowest-level wins and class
  exclusions, preferably per seed or through shared challenge seeds. Leaderboard
  categories and achievements remain open.

## Presentation

- On desktop, use a 1280×720 logical canvas and minimum window, with 32×32 world tiles. Double
  the existing 16px art as a placeholder, preserving the base view's world scale.
  Keep the valley and selected art consistent with this scale.
- Keep outdoor ground plain. Show prominent terrain features such as trees, stones,
  flowers, sparse grass tufts, roads and landmarks rather than repeating grass tiles.
  Use fewer grass tufts in wooded areas.
- On desktop, follow the owner's [UI sketch](UI_design.svg): compact player frame at upper left,
  a scrolling combat log at lower left, two centered hotbar rows, player menus at lower right,
  and buffs/debuffs below the player. Ten slots per row: 1–6, R, T, G, V on the
  bottom row; Shift plus the same keys on the upper row. Judge layout and text
  readability through human review, without automated resolution/fit checks.
  Keep the log compact with no separate log screen; menu buttons show their shortcuts.
- Android uses landscape touch controls: eight lower-left arrows around tap-only Wait,
  both ten-slot hotbar rows, and Menu/Interact buttons. Hold arrows to repeat; an ability
  tap consumes the hold. Keep ability inspection in the spell book and recent messages
  in the player menu. Place auras beneath the upper-left player info and larger resource
  bars just above the hotbar. Share game rules and content while separating platform input,
  layout, lifecycle handling and export entry points. Human phone playtesting decides
  control fit, readability and feel.

## Open design and playtest questions

- Tune training order/prices and progression pace, character XP/level scaling, the
  finite-area level ceiling, and Stalker pressure from its behavior and arrival schedule.
- Review Mortal Strike/Whirlwind rage economy, passive contributions, gear ranges,
  weapon progression, ordinary respawns and healing through playtesting.
- Keep optional combo empowerment for Execute/Judgement as a future design question.
- Review wolf usefulness, movement credit and coordinated rotation choices with the
  complete toolkit. Stalker Enrage and recovery remain experimental ideas.
- Consider additional talents/synergies and leaderboard categories or achievements later.

Keep durable decisions brief here. Keep tuning and implemented rules in code/data
and their authoritative references; keep playable tasks in the backlog.
