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
**every active and passive in the owner's consolidated v0.1 snapshot**. The owner's
current priority is itemization following completion of all four class toolkits.
Keep intermediate changes runnable; deferred playtests
do not gate completion of the catalogue. Tuning still needs human playtesting.

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

### Implemented slice — Loop-start class selection and retained learning

Implementation is ready for the owner's playtest, deferred at the owner's request.
Combat and starter tuning remain provisional; the earlier Warrior playtest is still
deferred. The Execute slice is implemented below.

- [x] Keep Warrior mandatory in Loop one. From Loop two, choose Warrior, Shaman,
  Paladin or Rogue at the marshal before accepting any quest. Returning Loops start
  in the previous class; confirm once, including the same class, to lock the track.
  Selection preserves gear and costs no world turn.
- [x] Keep the initial Warrior pair at New Game. The marshal locks class choice and
  names its trainer; learn other classes' starters free at the matching trainer, with
  no class XP requirement. Learning is permanent and fills empty hotbar slots for actives
  without replacing assignments. Implement Lightning Shield and Strength of Earth Totem,
  Seal of Command and Judgement, Slice and Dice and Relentless Assault. Use rage;
  trainers expose only implemented skills, leaving legacy mana kits unavailable.
- [x] Retain learned abilities/passives and cumulative class XP across death and class
  choice. Only uses belonging to the selected class grant XP; retained abilities grant
  none to either track. Count misses and repeated buff uses without anti-spam filters.
  Keep matching trainers, cumulative unlock thresholds and immediate availability.
- [x] Build player-held combo points from landed direct active attacks and ordinary
  main-hand hits after learning Relentless Assault, across classes and targets, with
  one base point per turn. Exclude off-hand hits, procs, buffs and misses.
  Slice and Dice requires points and spends all held points; Judgement leaves
  Seal of Command active. Clear combat resources and effects on death.
- [x] Save class choice, learning, class XP, combo points, buffs and totems in revision 14;
  leave older files incompatible and unchanged. Cover selection confirmation, quest and
  combat locks, retained passives, XP credit, starter interactions, saves before/between
  trainer learning and death boundaries.
- [ ] Owner playtest: return to the marshal before taking a quest, choose a class and
  visit its referred trainer. Learn each starter pair over successive Loops, then combine
  retained attacks and buffs in another class.
  Judge selection clarity, starter usefulness, combo spending and progression feedback.

### Implemented slice — Execute and Warrior trainer checkpoint

Implementation is ready for the owner's later playtest. Combat tuning remains provisional
in code/data; optional combo empowerment remains unresolved for the later finisher slice.

- [x] Add Execute as a melee finisher using the owner's chosen health eligibility,
  weapon/rage damage formula and capped automatic rage spending. Spend rage on misses;
  reject invalid uses without spending resources or turns. Keep a one-turn action with
  no ability cooldown, continuous weapon timing and effect/swing/enemy ordering.
- [x] Add Llane's free Execute checkpoint after Charge in cumulative Warrior XP order,
  without requiring previous unlocks or spending XP. Notify on reaching the checkpoint;
  expose learning, spell-book assignment, current rage cost and eligible target selection.
- [x] Retain Execute across classes and death. Count all selected-Warrior uses, including
  misses; retained uses grant neither class XP track. Landed Execute attacks build
  Relentless Assault points across targets and never spend them.
- [x] Cover health boundaries, capped rage/damage, physical mitigation/crit, misses,
  target commitment, ordering, trainer/UI behavior, retained use, death and save loading.
  Keep revision 14: the existing learned-skill format supports Execute without new state.
- [ ] Owner playtest: learn Execute at Llane, find it on the hotbar and compare it with
  Mortal Strike and Heroic Strike near an enemy's health threshold. Try different rage
  reserves, then use retained Execute with Relentless Assault in another class.
  Judge the finishing window, rage payoff, trainer pacing and feedback.

### Implemented slice — Complete all four class toolkits

The owner approved provisional mechanics for missing definitions. The full Warrior,
Shaman, Paladin and Rogue catalogues are implemented; tuning and exact descriptions
live in game data and the spell book. Human balance and readability review remains open.

- [x] Complete every v0.1 active and passive, with cumulative trainer checkpoints,
  free learning, immediate use, and retained cross-class effects.
- [x] Retune class unlock paths toward roughly five completed Loops, with early core
  attacks and active/passive milestones spread through each trainer's XP-ordered list.
- [x] Add shared Flurry, nonrecursive procs, guaranteed crit consumption, defenses,
  deliberate finisher spending/refunds, and the Holy-event counting limit.
- [x] Add independent off-hand attacks and equipment selection, spirit wolves with
  damage-based healing, movement credit and the Judgement haste exception. Keep Charge's
  existing commitment; tune it with the full toolkit during playtesting.
- [x] Preserve selected targeting during cleave, stop multi-hit effects on terminal death,
  and refund a queued strike when an earlier off-hand attack kills its target.
- [x] Save off-hand timing, wolves and transient procs in revision 16, retaining learning
  and mastery while clearing temporary effects on death. Leave older save files unchanged.
- [x] Cover trainer eligibility, retained effects, proc consumption, finishers, defenses,
  summons, timer ordering, save/death boundaries and keyboard inspection of passives.

### Implemented slice — Shared stats and obsolete class cleanup

- [x] Use Strength, Agility and Stamina as primary stats and Armor, Crit and Haste as
  secondary stats, with shared class-independent effects and derived weapon power/dodge.
  Keep existing weapon-based ability scaling; universal damage/healing scaling stays open.
- [x] Make stat gear usable in the valley, expose percentage bonuses in item descriptions
  and attack haste on the character screen, and keep the existing equipment slots.
- [x] Remove obsolete class abilities, pets, mana/spell stats, caster outfits, conjured
  supplies and class referrals. Replace Janos's mana potion with healing supplies;
  remove unused Intellect equipment and repurpose the Red Linen Robe.
- [x] Retire parry, block, glancing, crushing and spell resistance. Shields supply armor;
  physical damage uses armor while Holy/Nature damage bypasses it. Keep explicit class defenses.
- [x] Rebuild derived gear stats when loading revision 17; preserve older files as
  incompatible. Retain inventory, save, input, timing and current-toolkit checks while
  removing tests solely for retired behavior.
- [ ] Owner playtest: compare stat gear, shields and both weapon hands across classes;
  judge survivability, swing pacing, character/item feedback and retained mixed-class skills.

### Implemented slice — Difficulty and toolkit playtest

- [x] Give ordinary valley encounters increasing levels across the early patrol/camp,
  stronger wolves, mine and vineyard, ending with Garrick. Tune their combat profiles
  and implement shared level-gap accuracy, crit, dodge and damage effects.
- [x] Explore starter, partial Warrior and retained mixed-class matchups with temporary
  seeded simulations under ignored `reports/`; keep experiments out of game code.
- [x] Adopt the simulated stalker combat profile for every arrival and reinforcement;
  preserve the earlier [balance comparisons](../balance/2026-10-14/results.md) for later
  class tuning. Early guard death, reinforcements and victory over all present stalkers are implemented;
  their feel remains for playtesting.
- [x] Implement the potion, stalker, class-kit and weapon-and-shield tuning pass.
  Give Rogue independent main-hand combo building through Relentless Assault, temper
  stacked damage and cooldown effects, and strengthen developed Warrior and Paladin
  payoffs. Numerical tuning lives in data and the spell book.
- [ ] Redistribute damage within the developed toolkit while preserving overall strength.
  Postpone the agreed free, off-turn Judgement rework and its Divine Purpose replacement.
  Sudden Death now rewards physical actives without auto-attack triggers or Execute
  self-procs. Review the resulting damage distribution, Heroic Strike's action/rage
  tradeoff, Windfury, poison and Eviscerate use. Run further simulations with all four
  developed classes.
- [x] Integrate the poison prototype: Instant for short encounters, a Rogue
  catalyst passive rewarding faster-weapon Instant and slower-weapon Deadly for sustained
  fights. Keep the proposed free full-stack Eviscerate bonus out of this version because
  a banked finisher bypasses the intended buildup. Both coatings unlock together;
  Catalytic Venom follows later. Per-hand choices preserve independent coating timers.
  Tuning remains provisional pending playtesting.
- [ ] Further balance work: investigate partial unlocks, uncommon gear, ordinary fights
  and reinforcement pressure as playtesting identifies a need. Keep isolated Stalker
  comparisons separate from the route and reinforcement experience.
- [ ] Owner playtest: compare single enemies and multiple pulls before and after learning
  skills, including enemies above character level. Adjust difficulty and route pacing
  from play; simulations do not establish feel or balance acceptance.
- [ ] Playtest the adopted stalker against attainable valley levels and equipment,
  including pressure from reinforcements; revisit its tuning with the exit-boss slice.

Try the complete learned toolkit over returning Loops alongside the new itemization.
Judge unlock pacing, rage economy, buff/proc feedback, cleave, wolves, dual wielding,
defensive windows and mixed-class combinations. Adjust code/data from that feedback;
do not treat catalogue completion or automated tests as balance/readability acceptance.
Optional combo empowerment of Execute/Judgement remains a later design choice; the
current deliberate spender is Slice and Dice, with a passive Eviscerate attack when learned.

### Current playable task — Simplified itemization

- [x] Replace individual armor pieces and hands with armor, neck, two rings and a
  bundled weapon setup. Keep two-hand, weapon-and-shield and dual-wield choices;
  allow all gear without level or learning requirements. Retained Ambidexterity
  improves off-hand damage.
- [x] Add gray poor, white common and green uncommon progression. Start poor,
  provide a complete common loadout through quests and merchants, and reserve
  uncommon for rare world drops and occasional chest upgrades. Guarantee gear in chests.
- [x] Keep vendor gear attainable from ordinary kills and sold loot; offer limited
  healing potions and abundant food. Preserve seeded loot, atomic rewards and Loop resets.
  Revision 18 explicitly breaks the old equipment save layout while preserving old files.
- [x] Adopt the owner-selected world/chest uncommon rates. Give both qualities of
  accessories primary and secondary stats, keep item bonuses small, and make primary
  stat math impactful without losing fractional weapon damage to early rounding.
- [ ] Owner playtest: rebuild gear through quests, compare all three weapon setups,
  try selling mob loot for a vendor upgrade, and judge the impact of small stat bonuses.

### Current playtest follow-up — Menus and encounter feedback

The October playtest adjustments are implemented: separate Equipment/Bags pages,
slot replacement lists and selection previews, inspectable training, compact auras,
health/rage bars, consumable proc persistence, and valley faction/guard/prop changes.
Playtest keyboard inspection and gear swaps, proc consumption between encounters,
the outdoor camp versus mine, and the stalker arrival. Readability and feel remain
for owner review.

### Remaining slices — after itemization

- [ ] **Temporary character progression and gear:** tune kill/quest XP, the finite-area
  level ceiling and revisit the implemented level-difference effects. The simplified gear,
  shared stat model and combat simplification are implemented; retain those while tuning
  slow/fast and dual-wield/two-handed choices.
  Settle level differences, gear ranges and healing through playtesting.
- [ ] **Repeatable route rewards:** seeded enemy/chest loot, fixed merchants/prices and
  quest gear are implemented. Playtest the same seed across deaths and different
  action/loot orders; revisit chest placement if the deliberate landmarks change.
  Decide ordinary respawning rather than silently adopting the current absence of it.
  Preserve temporary gear/gold/quest resets and avoid unbounded XP farming by accident.
- [ ] **Exit boss and timed clones playtest:** the first stalker arrives early for the
  guard-death scene; later copies follow the fixed global schedule. Defeating every present
  stalker immediately ends the attempt in victory; escape is the story outcome.
  Blocked arrivals retry without shifting deadlines. Playtest the direct route, then a
  developed quest/loot route and escape before reinforcements. Tune readable attack
  patterns, HP/damage and clone pressure
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
