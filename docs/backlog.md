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
- [x] Establish the prototype's selected art. Generation tooling and unused sprites
  are now removed; keep [editable sources and runtime sheets](../art/README.md).
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
- [x] Move the existing valley into an editable Godot scene with terrain layers,
  actor placeholders, spawn markers and exploration regions, retaining grid gameplay.
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
current priority is the coordinated class rotation and passive overhaul following itemization.
Keep intermediate changes runnable; deferred playtests
do not gate completion of the catalogue. Tuning still needs human playtesting.

The milestone should let a weak first-Loop warrior die, retain learning,
develop the other classes, combine the full toolkit, rebuild temporary level and gear,
and eventually defeat the exit boss and escape under pressure from timed clones.
Reuse the valley and selected art. Art refinement and a larger story pass remain paused.
Numerical tuning goes in code/data as each mechanic is implemented; do not copy the
snapshot's provisional tables or simulation results into planning documents.

### Implemented slice — Warrior attack timing and starting kit

Implementation is ready for the owner's playtest, deferred at the owner's request.
Combat tuning remains provisional until that playtest and lives in code/data.

- [x] Start with Mortal Strike and Whirlwind; remove Slam and Heroic Strike from the runnable toolkit.
  Battle Shout is a trainer unlock; retain existing Anger Management and Charge learning.
- [x] Advance fractional weapon timers on every world turn, including active abilities,
  movement and waits. Preserve bump commitment, friendly interaction and second-bump
  neutral protection. Implement the owner's chosen effect/swing ordering, readiness,
  targeting, no banking out of range and stopping multiple due swings on death.
- [x] Replace queued Heroic Strike with a direct, repeatable Whirlwind rage spender
  against adjacent enemies. Both starting actives leave weapon timing running.
- [x] Add provisional baseline crit tuning and base-speed swing rage, independent of
  haste. Preserve incoming rage, out-of-combat decay and ordinary ability cooldown timing.
- [x] Show the attack target, rage and cooldown state through the existing
  target highlight, log and hotbar. Preserve fractional timers and learning through saves;
  bump the save revision while leaving incompatible files unchanged.
- [x] Replace obsolete attack checks and cover timing, cancelled attacks, misses,
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
  Seal of Command and Execution Sentence, Eviscerate and Relentless Assault. Use rage;
  trainers expose only implemented skills, leaving legacy mana kits unavailable.
- [x] Retain learned abilities/passives and cumulative class XP across death and class
  choice. Only uses belonging to the selected class grant XP; retained abilities grant
  none to either track. Count misses and repeated buff uses without anti-spam filters.
  Keep matching trainers, cumulative unlock thresholds and immediate availability.
- [x] Build player-held combo points from landed direct active attacks and ordinary
  main-hand hits after learning Relentless Assault, across classes and targets, with
  one base point per turn. Exclude off-hand hits, procs, buffs and misses.
  Eviscerate requires points and spends all held points; Execution Sentence leaves
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
  Mortal Strike and Whirlwind near an enemy's health threshold. Try different rage
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
- [x] Add Shaman Flurry, nonrecursive procs, guaranteed crit consumption, defenses,
  deliberate finisher spending/refunds, and the Holy-event counting limit.
- [x] Add independent off-hand attacks and equipment selection, spirit wolves with
  damage-based healing, movement credit and the Execution Sentence haste exception. Keep Charge's
  existing commitment; tune it with the full toolkit during playtesting.
- [x] Preserve selected targeting during cleave and stop multi-hit effects and later
  due swings when their target dies or the attempt ends.
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
  use the current [simulation bench](../bench/README.md) for further class tuning.
  Early guard death, reinforcements and victory over all present stalkers are implemented;
  their feel remains for playtesting.
- [x] Implement the potion, stalker, class-kit and weapon-and-shield tuning pass.
  Give Rogue independent main-hand combo building through Relentless Assault, temper
  stacked damage and cooldown effects, and strengthen developed Warrior and Paladin
  payoffs. Numerical tuning lives in data and the spell book.
- [ ] Redistribute damage within the developed toolkit while preserving overall strength.
  Explore Execution Sentence and Consecration for Paladin's distinct role, redistributing
  its existing damage contribution rather than simply adding more damage.
  Sudden Death now rewards physical actives without auto-attack triggers or Execute
  self-procs. Review the resulting damage distribution, Whirlwind's action/rage
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
current deliberate spender is Eviscerate, with passive Slice and Dice haste when learned.

### Implemented slice — Coordinated class rotation and passives

The owner's mixed-kit priority in [direction](direction.md) supersedes the earlier
Seal/Might maintenance and Earth Shock implementation below. The coordinated change
is implemented and ready for owner QA. Current tuning, learning requirements and
interactions live in [class mechanics](class-mechanics.md); prices and balance remain
provisional. The [bench](../bench/README.md) now compares production rules.

- [x] Rename Execution Sentence to Judgement across learning, effects, targeting,
  tooltips and saved state. Preserve snapshot damage/hit/crit, delayed delivery,
  early-target-death loss and impact-only attack rewards.
- [x] Make Seal of Command an always-on learned passive on ordinary main-hand hits,
  removing its cast, timer and hotbar assignment. Judgement requires learned Seal.
- [x] Replace Might with passive Kings on learned, active Battle Shout. Rebuild stats
  from those dependencies; apply learning immediately without healing on refresh.
- [x] Replace Earth Shock with long-cast, damage-only Fire Lava Burst. Replace
  Elemental Assault with early Maelstrom Weapon; remove Improved Earth Shock and
  its control. Keep Flurry's existing early training. Reuse orange-tinted target art.
- [x] Bank guaranteed Maelstrom on the first qualifying primary physical hit per
  action, including off-hand and finishers, without bonus/proc recursion. Snapshot
  stacks/time at cast start, cap reserved plus new stacks together, preserve stacks
  on cancellation/invalid completion and spend only reserved stacks on completion,
  including misses. Give five stacks a distinct instant payoff; no casting-credit gain.
- [x] Keep Art of War's critical readiness; make Sacred Duty strengthen that empowered
  critical. Keep Sanctity's damage with fixed cooldown. Redistribute damage into
  Consecration. Keep Charge rage, cooldown-free Whirlwind and Rogue rewards unchanged.
  Existing per-hit Seal Fate behavior is retained; no extra multi-target cap added.
- [x] Check Charge's ordinary arrival swing and prepared Mortal Strike affordability
  across weapons. Compare requested priorities against alternate orders using real
  low-rage preparation, ordinary groups, ranged pulls, durable groups and Stalker;
  include starter/native and all three-kit combinations. Observer fights replay
  against plain world rules and reconcile player/enemy HP.
- [x] Update trainer completion/gifts, passive/hotbar handling, stack/cast feedback,
  effect placement and class summaries. Save revision 31 rejects incompatible older
  files without migration or overwriting them; banked stacks persist in valid saves.
- [x] Test snapshots, cancellation, failure/miss/target loss, stack caps, physical versus
  spell hooks, delayed impacts, Kings expiry, retained learning, save validation and
  death reset. Full validation passes; obsolete active/control tests are replaced.
- [ ] Owner QA: play the opener, full-stack ranged pull, empowered delayed verdict,
  five-point haste refresh and three-enemy ground/cleave choices. Judge commitment,
  readable feedback and practical exceptions to the preferred priority.
- [ ] Tune contribution and training budgets from QA. Revisit the intended
  three-developed-kit boss goal, purchase routes, passive-removal comparisons,
  prior-encounter buff expiry and banked-point entries. The fixed isolated bots do
  not cover these routes or establish final balance or human acceptance.

### Implemented slice — Fewer passive unlocks

- [x] Fold Shaman's shield strength, Windfury damage and wolf healing into their
  existing actives; fold Judgement's flat damage and stronger Art of War critical
  into their existing definitions. Preserve fully learned values.
- [x] Remove Divine Purpose, Eye for an Eye and Ruthlessness. Put the former
  Relentless Strikes rage refund directly on Eviscerate, including misses, without
  combo-point refunds. Retain parent learning levels/prices; gift completion uses
  the smaller catalogues automatically.
- [x] Update mechanics, trainer/save/retained-effect checks and the current Stalker
  bench. Revision 32 rejects older saves unchanged, without migration.
- [ ] Owner playtest: judge stronger parent abilities when first learned, training
  and gift pacing, wolf healing, empowered verdicts and finisher resource flow.
  Full-unlock simulations do not settle early progression or human balance acceptance.

### Current class-identity follow-up — Warrior rage spending

- [x] Replace starter Heroic Strike with Whirlwind and remove Incite and strike-queue
  mechanics. Keep Execute's later unlock and the existing per-target proc interactions.
- [x] Replace Warrior Flurry with early Enrage and Death Wish learning. Enrage can
  trigger from surviving damaging enemy hits at any health; passive Death Wish ramps
  the physical damage reward and incoming damage risk as health falls, with a modest cap.
  Keep Shaman Flurry and retained effects across classes. Preserve proc expiry and save
  boundaries; leave incompatible saves untouched.
- [ ] Later owner playtests and simulations: compare saving for Mortal Strike with
  spending on Whirlwind, single enemies versus groups, and retained mixed-class kits.
  Playtest prepared large pulls after removing Whirlwind's Sweeping Strikes copies,
  redistributing damage and limiting kill-heal frequency; review remaining per-target procs.
- [ ] Playtest the early health/rage tradeoff, healing and Enrage feedback, then compare
  developed kits against the stalker. Removing Warrior haste also changes rage income;
  the capped Death Wish penalty has no boss-specific exception. Revisit tuning from
  these later playtests and simulations.
- [ ] Decide later passive development after moving Whirlwind out of trainer progression
  and adding the early risk/reward passives.
- [x] Add later Shield Block training for a passive defense while a shield is equipped,
  preserving partial-hit rage and reactive effects. Combat equipment swaps remain available.
- [ ] Owner playtest: compare shield survival with two-hand clearing, and swap into/out of
  a shield during combat. Review large retained-kit pulls before settling balance.

### Current class-identity follow-up — Shaman preparation and summons

- [x] Make Lightning Shield and Windfury free to apply and move Earth Shock into the
  starter pair. Remove weapon/Strength scaling from Earth Shock, compensate its flat
  damage and retain its interrupt and critical empowerment.
- [x] Remove Strength of Earth Totem and Elemental Warding. Add one lasting mobile
  Earth Elemental with a long cooldown and a local taunt of already engaged enemies.
  Keep its health, cooldown and singleton state through saves; clear it on Loop reset.
- [x] Strengthen spirit-wolf attacks and their damage-based healing. Keep tuning in
  game data and descriptions, with a placeholder elemental sprite for playtesting.
- [ ] Owner playtest after the coordinated replacement above: compare Lava Burst's
  pull and Maelstrom payoff across weapon setups, summon the elemental during a Stalker
  fight and against a group, then compare wolves' damage/healing. Judge whether the
  elemental buys useful time without making ordinary pulls trivial.

### Current class-identity follow-up — Paladin

- [x] Remove Benediction and make Blessing of Might free maintenance. Keep Seal of
  Command's rage cost.
- [x] Replace Judgement with a fixed delayed Execution Sentence, retaining its
  Holy/critical synergies. Keep damage and critical results fixed at cast; no stacks
  or damage accumulation. Add fixed Consecration ground without extra mitigation,
  preserve both effects through saves, and clear them on Loop reset.
- [x] Compare the reworked damage contribution against a fresh current-kit baseline
  in ordinary and Stalker fights, alone and with retained class abilities. Tune the
  delay and ground's damage/rage budget against the mixed-kit comparisons.
- [ ] Owner playtest: judge the short verdict delay, targets dying before impact,
  and staying on or leaving the consecrated ground. Cold Paladin-only group fights
  remain less forgiving, especially with a two-hander; revisit that timing tradeoff
  from play. Simulations do not settle feel or balance.

### Current class-identity follow-up — Rogue

- [x] Remove Opportunity, make Eviscerate the starter active finisher and move Slice
  and Dice to its early passive upgrade. Require a valid melee target; spend points
  on misses, grant learned haste and resolve refunds once after spending.
- [x] Make both poison coatings free in rage while keeping their preparation action
  and per-hand choices. Keep Seal Fate and Bandit's Guile working with qualifying
  retained attacks from other classes.
- [x] Compare Rogue alone, Warrior + Rogue and all four kits in ordinary and Stalker
  simulations across weapon setups and cold/prepared entries. Keep damage accounting
  and sample replays against the plain game model.
- [ ] Owner playtest finisher frequency, haste feedback and poison preparation,
  including the extra preparation action in short cold fights. Simulations do not
  decide feel or balance.

### Current combat timing follow-up

- [x] Align longer preparation buffs, retain the shorter rotational Seal and Shield,
  and normalize timed damage-bonus procs. Keep tuning in ability data.
- [x] Resolve combat expiry, delayed verdicts, ground damage and poison in one phase
  before weapon swings and enemy actions. Preserve final ticks and stop on terminal death.
- [ ] Owner playtest poison kills before enemy retaliation and combined ground/poison
  damage, plus preparation refresh frequency and damage-proc feedback.

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

### Current playtest follow-up — Route, training and returning Loops

- [x] Move the guard/stalker scene south, restore local outdoor wandering, credit broad
  exploration areas, and make closed chests block movement and collect loot on bumps.
- [x] Add random idle pauses and staggered wandering starts, preserve pending pauses
  through saves, and give horizontal save/load buttons space alongside wrapped menus.
- [x] Speed up held movement, wrap item previews without truncation, gray learned
  training entries, and reduce Eviscerate's noncritical burst against wolves.
- [x] Replace class XP with current-Loop level requirements and gold purchases, retaining
  free starters and permanent learning. This supersedes the older class-XP slices below.
- [x] Put class selection before returning-Loop quests, preselect the previous class,
  redirect other NPCs until selection, and advance the choice wording across Loops.
- [x] Apply the next playtest feedback: confident Warrior wording, starter gear for every
  class each Loop, starting food and Eating feedback, passable flowers/bushes, combined
  wolf objectives, gated exploration, an engaged-enemy frame, item comparison previews,
  and Execution Sentence targeting, seal feedback and delayed impact. Preserve revision 28.
- [ ] Owner playtest: judge training purchases against gear/food spending and roughly
  five Loops per class; check tooltip readability, wandering, wolf finishers and the
  relocated guard scene. Costs and combat tuning remain provisional.

### Implemented playtest follow-up — Menus and encounter feedback

The October playtest adjustments are implemented: separate Equipment/Bags pages,
slot replacement lists and selection previews, inspectable training, compact auras,
health/rage bars, consumable proc persistence, and valley faction/guard/prop changes.
Playtest keyboard inspection and gear swaps, proc consumption between encounters,
the outdoor camp versus mine, and the stalker arrival. Readability and feel remain
for owner review.

The next notes add thin hotbar borders for critical/free-use readiness and missing
maintenance, chest bump loot menus, faster held movement, quality-sorted bag views,
deliberate Lava Burst targeting, and the abbey contact/passage changes. Maelstrom's
bar replaces its duplicate aura. Playtest border readability, mixed poison coatings,
opening/cancelling chest loot, ranged pulls with another engaged enemy, and the
hidden northeast corner. Garrick's first-Loop tuning aims for a close prepared fight;
isolated simulations inform it, while real routes and human play decide the result.

### Implemented playtest follow-up — War Horn

- [x] Replace Booming Shout with Llane's reusable War Horn gift after learning every
  Warrior ability/passive. Offer the requested farewell dialogue once per Loop; leave
  the gift available if bags are full. Retained learning permits a new gift next Loop.
- [x] Add a two-turn cast, screen-wide pull with sight, and 30-turn item cooldown.
  Support Bags and hotbar use, save the item/claim/cooldown, and lose the item on death.
  Revision 29 explicitly leaves earlier saves incompatible and unchanged.
- [ ] Owner playtest: claim the gift, pull a distant group, cancel and repeat a cast,
  and collect a replacement after death. Judge screen range and casting commitment.

### Implemented playtest follow-up — Lucky charm

- [x] Add Jorik's once-per-Loop farewell gift after every Rogue ability/passive is
  learned, using the same dialogue and full-bag handling as War Horn.
- [x] Passively prevent one lethal hit while carried, leaving 1 HP and replacing the
  charm in place with an inert Broken lucky charm. Save both item forms and the claim;
  lose them on death and permit a fresh gift next Loop. Preserve revision 29.
- [ ] Owner playtest: claim the gift, survive a lethal hit, inspect the broken charm,
  then take another hit and reclaim the gift next Loop. Judge survival feedback.

### Implemented playtest follow-up — Ancestral totem

- [x] Replace Earth Elemental training with Farseer Lopaa's once-per-Loop farewell
  gift after all remaining Shaman training. Keep the elemental's behavior and art.
- [x] Add a free, one-turn, single-use item for Bags/hotbar. Preserve it on blocked
  placement or an existing summon. Save the item, claim and summon; clear all on death.
  Revision 30 explicitly leaves earlier saves incompatible and unchanged.
- [ ] Owner playtest: claim and use the totem, let the elemental draw attacks, save
  and reload while it lives, then try to claim again before and after death.

### Implemented playtest follow-up — Wartorn Banner

- [x] Add Brother Sammuel's once-per-Loop farewell gift after every Paladin ability
  and passive is learned. Preserve the gift on full bags and use retained learning.
- [x] Plant a single-use, free, one-turn banner beside the player for 10 turns. Give
  the player and friendly summons within 3 tiles 10% damage reduction, with a ground
  marker/range outline and HUD feedback. Keep placement nonblocking and preserve failed
  uses. Save the item, banner and claim; clear them on death. Preserve revision 30.
- [ ] Owner playtest: plant beside Consecration, move in/out of range with summons,
  judge the marker and mitigation, then save/reload and reclaim the gift after death.

### Remaining slices — after itemization

- [ ] **Vanish playtest:** learn the new Rogue active, vanish in an engaged pack,
  move away while enemies approach the original tile, then break concealment with
  a bump or retained ability. Check four-turn expiry, transparency, the opening crit
  bonus and resumed pursuit. Training price and balance remain provisional.

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
- [x] Implement Stalker's dodgeable Fel Breath with two response turns, a locked
  three-tile cone, persistent wind-up/tile warnings, and ten normal turns between casts.
  Final sprites, warning readability and the easier fight from melee pauses need owner
  playtesting; Enrage and regeneration remain undecided experiments.
- [ ] **Integration, saves and playtesting:** keep learning and the seed while
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
