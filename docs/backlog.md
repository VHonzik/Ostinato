# Local backlog

Use small playable tasks, followed by a short playtest and an adjustment. No PR, issue,
or milestone metadata is required. Task notes describe the change, the open decision,
and how to try it; the final chat carries temporary playtest instructions.

## Completed — Make iteration lighter

- [x] Replace formal requirements and source-data docs with direction and this backlog.
- [x] Replace historical development walkthroughs with current setup/check commands.
- [x] Make local work the default; remove required PRs, source audits, and handoff files.
- [x] Simplify validation into quick, targeted, and full modes and verify their failure paths.

## Completed — A readable playground

- [x] Build the screen prototype from [UI_design.svg](UI_design.svg): 1280×720,
  32px tiles, two rows of ten hotbar slots, compact log and dedicated player menus.
  Keep existing gameplay playable; the mage/resources are placeholders for the pivot.
- [x] Remove automated resolution, control-fit and readability acceptance. Keep input,
  menu behavior, hotbar and save checks; visual acceptance belongs to human review.
- [x] Draft the [reduced valley and sprite list](art-plan.md). World population changes
  belong to the later world milestone; the owner’s [map sketch](map.svg) supplies the layout.
- [x] Establish the [local art pipeline](../art/README.md): ComfyUI world/static
  generation, selected individual PNGs, and separate atlas packing. The prototype
  is accepted; rejected experiments are removed.
- [x] Play the screen prototype. The owner's quick playtest found it satisfactory;
  the valley sketch and sprite plan are ready for the first playable map prototype.

## Paused milestone — A memorable valley

Paused at the owner's request for the time-loop RPG v0.1 milestone below. Keep the
completed map and selected art as the prototype's starting area. Unfinished art, story
and valley playtest work stays paused; revisit its relevance after the new combat and
progression are playable.

- [x] Build a playable route from the marshal through one encounter area using the
  [valley sketch](map.svg) and selected AI-created sprites. Try ground, boundaries,
  actors and props together before expanding to the whole valley. The owner accepted the first slice;
  **New Game** now uses the expanded valley as the sole game map.
- [ ] Refine selected sprite equipment, remains, and terrain joins in the western
  woods slice, especially cliff joins, abbey doors and wolf remains. The owner-selected
  original sprites are restored for actors, abbey walls/entrance, nature, chests
  and a shared corpse. Review silhouettes at native size before further art changes.
- [x] Expand the valley with fewer NPCs, no within-Loop respawns, deliberate
  encounters and exploration destinations. Add a timed arrival at the southwestern gate.
  Branch rewards are an initial tuning pass; routes and XP still need playtesting.
- [ ] Add a small story pass with recognizable contacts and dialogue that changes
  as the player realizes the Loop. NPCs remain unaware of it; settle the shaman's
  identity and keep invasion knowledge limited.
- [ ] Playtest navigation, landmark recognition, encounter/XP pacing, the timed gate
  threat and early/returning-Loop conversations; adjust the map, story and art together.

## Completed playable slice — Warrior first

The owner playtested the current Warrior state; that feedback led to the time-loop RPG v0.1 redesign. The implemented slice remains available in the current build.

- [x] Replace the mage start with warrior, rage, Slam and Battle Shout while retaining
  bump-to-next-swing timing. Expose only warrior for this slice; keep legacy class code
  for later work.
- [x] Add persistent warrior ability-use progression, a trainer notification and Llane's
  first passive checkpoint; preserve learning across death and saves.
- [x] Add a second-bump attack on stationary neutral enemies and reuse the last attacked
  enemy for Slam in combat, preserving melee range and the existing swing wait.
- [x] Make friendly bumps interact, add Charge as the next trainer checkpoint, retain
  progression points on unlock, and add a development ability for class points.
- [x] Owner playtested rage generation, Slam, Charge, shout upkeep and trainer progression; feedback informed the v0.1 redesign, planned in the current milestone below.

## Current milestone — Time-loop RPG v0.1

Plan an end-to-end playable prototype of [the current direction](direction.md), including
**every active and passive in the owner's consolidated v0.1 snapshot**. Deliver it through
small runnable slices and playtest between them; do not build the whole catalogue before
trying combat.

The milestone should let a weak first-Loop warrior die, retain mastery and learning,
develop the other classes, combine the full toolkit, rebuild temporary level and gear,
and eventually defeat the exit boss and escape under pressure from timed clones.
Reuse the valley and selected art. Art refinement and a larger story pass remain paused.
Numerical tuning goes in code/data as each mechanic is implemented; do not copy the
snapshot's provisional tables or simulation results into planning documents.

### Implemented slice — Warrior attack timing and starting kit

Implementation is ready for the owner's playtest, deferred at the owner's request.
Combat tuning remains provisional until that playtest and lives in code/data.

- [x] Start with Mortal Strike and Heroic Strike; remove Slam from the runnable toolkit.
  Battle Shout is a trainer unlock; retain existing Anger Management and Charge learning.
- [x] Advance fractional weapon timers on every world turn, including active abilities,
  movement and waits. Preserve bump commitment, friendly interaction and second-bump
  neutral protection. Implement the owner's chosen effect/swing ordering, readiness,
  targeting, no banking out of range and stopping multiple due swings on death.
- [x] Reserve Heroic Strike's rage and commit until the next main-hand swing. Replace
  that swing, forfeit its ordinary rage and consume misses. Cancellation or target
  loss refunds the reservation; elapsed turns remain spent. Mortal Strike is a direct
  active attack that leaves weapon timing running.
- [x] Add provisional baseline crit tuning and base-speed swing rage, independent of
  haste. Preserve incoming rage, out-of-combat decay and ordinary ability cooldown timing.
- [x] Show the attack target, queued strike, rage and cooldown state through the existing
  target highlight, log and hotbar. Preserve fractional timers and learning through saves;
  bump the save revision while leaving incompatible files unchanged.
- [x] Replace obsolete Slam checks and cover timing, cancellation/refunds, misses,
  physical/critical damage, multiple due swings, death/save boundaries and UI input.
- [ ] Owner playtest: compare slow and fast weapons against one enemy, then two;
  interleave movement, waiting and both actives. Judge commitment, target control,
  rage economy and readability; revisit tuning when feedback arrives.

### Current playable task — Loop-start class selection and retained learning

Implementation is ready for the owner's playtest, deferred at the owner's request.
Proceed with the small Execute slice next. Combat and starter tuning remain provisional;
the earlier Warrior playtest is still deferred.

- [x] Keep Warrior mandatory in Loop one. From Loop two, choose Warrior, Shaman,
  Paladin or Rogue at the marshal before accepting any quest. Returning Loops start
  in the previous class; confirm once, including the same class, to lock the track.
  Selection preserves gear and costs no world turn.
- [x] Keep the initial Warrior pair at New Game. The marshal locks class choice and
  names its trainer; learn other classes' starters free at the matching trainer, with
  no class XP requirement. Learning is permanent and fills empty hotbar slots for actives
  without replacing assignments. Implement Lightning Shield and Strength of Earth Totem,
  Seal of Command and Judgement, Slice and Dice and Relentless Assault. Use rage;
  trainers expose only implemented ranks, leaving legacy mana kits unavailable.
- [x] Retain learned abilities/passives and cumulative class XP across death and class
  choice. Only uses belonging to the selected class grant XP; retained abilities grant
  none to either track. Count misses and repeated buff uses without anti-spam filters.
  Keep matching trainers, cumulative unlock thresholds and immediate availability.
- [x] Build player-held combo points from landed direct active attacks after learning
  Relentless Assault, across classes and targets. Exclude auto-attacks, procs, buffs and
  misses. Slice and Dice requires points and spends all held points; Judgement leaves
  Seal of Command active. Clear combat resources and effects on death.
- [x] Save class choice, learning, class XP, combo points, buffs and totems in revision 14;
  leave older files incompatible and unchanged. Cover selection confirmation, quest and
  combat locks, retained passives, XP credit, starter interactions, saves before/between
  trainer learning and death boundaries.
- [ ] Owner playtest: return to the marshal before taking a quest, choose a class and
  visit its referred trainer. Learn each starter pair over successive Loops, then combine
  retained attacks and buffs in another class.
  Judge selection clarity, starter usefulness, combo spending and progression feedback.

### Next playable task — Warrior burst and execution

Start with a small Execute slice: settle its damage/rage formula with the owner, add
its trainer checkpoint, and try it alongside Mortal Strike and Heroic Strike. Review
Charge commitment and Battle Shout when combat feedback arrives. Add related passives
in subsequent runnable tasks; keep later class catalogues coarse until they are current.

### Remaining slices — in dependency order

- [ ] **Complete Warrior:** revisit Charge and Battle Shout, add Execute and Whirlwind, and every
  Warrior passive: Anger Management, Cruelty, Incite, Flurry, Battle Trance, Sudden Death,
  Victory Rush, Sweeping Strikes, Wrecking Crew and Juggernaut. Split burst/execution,
  crit/queue interactions and cleave into playable tasks as this slice becomes current.
  Settle Execute's formula and Charge's commitment; check that Incite cannot sustain itself.
- [ ] **Temporary character progression and gear:** tune kill/quest XP, the finite-area
  level ceiling and level-difference effects. Support main/off-hand or two-handed weapons,
  armor, two accessories and the proposed physical/crit/dodge/health/haste stats without
  selected-class stat bonuses. Make slow/fast and dual-wield/two-handed choices useful.
  Simplify the old attack tables to armor, dodge, hit chance and the new crit rules;
  remove parry, block, glancing/crushing and detailed spell resistance. Keep explicit
  class defenses. Settle off-hand baseline, level differences and healing availability.
- [ ] **Repeatable route rewards:** fixed merchants/prices and quest rewards; enemy loot
  keyed by world seed plus stable enemy ID; seeded chest contents and placement from
  predefined points. Repeat the same seed across deaths and different action/loot orders.
  Decide ordinary respawning rather than silently adopting the current absence of it.
  Preserve temporary gear/gold/quest resets and avoid unbounded XP farming by accident.
- [ ] **Complete Shaman:** develop the implemented Lightning Shield/Strength of Earth
  starter pair; add Windfury Weapon, Earth Shock and Feral Spirit. Include Improved
  Shields, Flurry,
  Static Shock, Elemental Weapons, Elemental Assault, Spirit Hunt, Elemental Warding,
  Toughness and Improved Earth Shock. Share or upgrade Warrior Flurry; settle wolf
  damage/healing and test retaliation, interrupts, totem range and nonrecursive procs.
- [ ] **Complete Paladin:** develop the implemented Seal of Command/Judgement starter
  pair; add Blessing of Might and Divine Shield. Include Benediction, Conviction,
  Vengeance, Art of War,
  Heart of the Crusader, Divine Purpose, Pursuit of Justice, Eye for an Eye, Guardian's
  Favor, Sacred Duty and Sanctity of Battle. Include the Seal/Judgement interaction,
  Art of War's per-action counting limit and Shield's action cost/damage penalty.
  Decide grid movement speed and the explicit haste-to-Judgement cooldown exception.
- [ ] **Complete Rogue:** develop the implemented Slice and Dice/Relentless Assault
  starter pair; add Evasion and Instant Poison. Include Opportunity, Ambidexterity,
  Eviscerate, Combat Potency,
  Seal Fate, Main Gauche, Restless Blades, Bandit's Guile, Ruthlessness, Relentless
  Strikes and Precision. Keep combo points on the player across targets, generated
  by qualifying cross-class actives and spent only through deliberate finishers.
  Settle optional empowered Judgement/Execute input, refund ordering and qualifying
  hits; distinguish Combat Potency's explicit rage proc from ordinary bonus-strike rage.
- [ ] **Exit boss and timed clones:** place the boss at the guarded exit early in every
  Loop, replacing the delayed first-stalker/demo-kill ending. Add the escape outcome
  and a fixed global clone schedule; define blocked arrival behavior and whether clones
  must also be defeated. Tune readable attack patterns, HP/damage and clone pressure
  against finite route XP/gear and roughly three developed classes. Keep exceptional
  earlier wins possible rather than enforcing class or level victory gates.
- [ ] **Integration, saves and playtesting:** keep learning/mastery and the seed while
  clearing temporary levels/XP, gear, gold, quests, buffs, combat resources and clones
  on death. Check mid-Loop saves at the existing out-of-combat action boundaries,
  class selection, trainer eligibility/learning, fractional timers, proc consumption,
  world-turn expiry, multi-hit death ordering and escape state. Keep the existing
  session/save structure, using revision bumps for compatibility changes; preserve
  old saves and failed-write/load protections without adding migrations.
  Run full validation for the resulting changes across systems. Play an ordinary first
  death, a returning Loop with mixed-class skills and a developed boss attempt; adjust
  pacing, readable feedback and balance from human feedback.

Later slices remain coarse until they become the next playable task. Qualifying attack,
damage, crit and finisher events need explicit decisions as their consumers are added;
use simple code suited to the active slice, not a speculative proc framework.

## Later playable milestones

- **Presentation and story:** revisit the paused valley art/dialogue work against the
  new Loop and boss behavior; polish feedback and prepare a demo build.
- **Challenges and expanded design:** choose per-seed leaderboard categories and
  achievements, then consider additional synergies or optional talents. Hosted
  leaderboards and new class content beyond v0.1 are outside the current milestone.

## Workflow experiment

Try the owner's chosen alternative model/settings on a few comparable future tasks.
Compare accepted/playable results, corrections, actual token use if available, and
elapsed time. Keep observations in chat; only retain a useful resulting preference.
Do not add a benchmark framework, automatic model routing, or a new reporting ritual.

The old milestone-8 completion queue is retired locally. Existing GitHub issues and
milestones have not been changed; do not resume them automatically.
