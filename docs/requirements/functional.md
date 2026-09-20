# Functional requirements

Status: **Implementation baseline**, 2026-09-18. Owner review incorporated; no gameplay
implementation, test pass, or human acceptance is claimed.

## Scope and use

Read together with [non-functional requirements](non-functional.md). These two documents
define the Ostinato demo. Stable `FR-xxx` identifiers describe observable behavior and its
acceptance criteria. The milestone map separates temporary development fixtures from the
completed demo. No other requirement files are incorporated.

The demo combines grid movement, player-driven time, Classic-inspired combat and leveling,
and repeated deaths that reset the world while preserving learned skills. Northshire is the
playable setting; defeating one demon stalker completes the demo. The wider invasion is lore.

Unspecified numeric content is implementation research, tracked by `DATA-xxx` below; it is
not an outstanding owner questionnaire. Assemble each record before implementing its
dependent feature. Early movement work can begin independently. Values explicitly described
as initial tuning defaults are usable now and may be tuned with documented playtest evidence.

### Terms

| Term | Meaning |
| --- | --- |
| Game | One progression history created by New Game, with one world seed and potentially many Loops. Saving to another slot preserves that seed. |
| Loop | One attempt, starting at the fixed spawn and ending at death or demo completion. The first is Loop 1. |
| Turn | One simulation second; moving one tile at base speed costs one turn. Real-time input delays do not advance it. |
| Player phase / NPC phase | Player action or cast progress, followed by one shared NPC phase per elapsed turn. |
| Skill / spell | A learned, ranked ability; included passives and summons follow FR-018. |
| Same NPC across Loops | The corresponding seeded spawn instance, including its area/slot and replacement ordinal, rather than any creature of the same type. |
| Tile distance | Chebyshev distance: the larger absolute coordinate difference. All eight adjacent tiles have distance 1. |

## Game and Loop lifecycle

### FR-001 — New Game

New Game shall start Loop 1 with a newly generated world seed, the fixed spawn, and a
level-1 mage with Classic human-mage starting gear and starting skills, zero earned XP,
zero currency, and full health and mana. Starting data follow DATA-001 without racial effects.

Acceptance:

- A new game inherits no learned skills, quests, items, gold, or hotbar assignments from
  another game; global options remain unchanged.
- Later Loops keep this game's seed. New Game generates a seed rather than copying the
  current seed; random generation need not guarantee that collisions are impossible.

### FR-002 — Death resets the attempt

Player death shall initiate the next Loop exactly once, increment its count, restore the
fixed spawn, and apply the following changes, unless FR-006 has already ended the demo.

| State | Effect of a new Loop |
| --- | --- |
| World seed | Preserved. |
| World objects, NPCs, spawn/replacement sequences, corpses, chests, vendor stock | Reset to the starting world for that seed; timed arrivals and replenishment restart. |
| Position, level, XP, stats | Fixed spawn, level 1, zero earned XP, and the same starting mage baseline as New Game. |
| Carried/equipped items and currency | Previous items and currency lost; fresh mage starter gear granted, currency zero. |
| Quests, objectives, and class-selection eligibility | Cleared; normal quest prerequisites apply again. |
| Active buffs, debuffs, pets, totems, and pending actions | Removed; no ended-Loop effect can run in the new Loop. |
| Learned skills and ranks | Preserved under FR-003. |
| Health and mana | Restored to the starting maxima, including starting equipment. |
| Cooldowns, swing timers, movement/casting/melee credits | Cooldowns cleared, swings ready, accumulated credits zero. |
| Selected class and sprite | Mage until a permitted marshal selection. |
| Hotbar assignments and layout lock | Preserved for this game, including explicit rank choices. |
| Global settings | Unchanged. |

Acceptance:

- Die after gaining a level, gold, an item, quest progress, a pet, and a buff: transient
  gains disappear, learned ranks remain, and the new Loop matches the table.
- An initial killed NPC and emptied chest return with the same seeded identities and loot.
- No pending attack or callback from the ended Loop can damage the reset player.

### FR-003 — Persistent learning

Learned skills and their ranks shall survive every Loop. Neither current class nor current
level shall prevent use of an already learned skill. Other applicable conditions, including
resources, target validity, and cooldowns, still apply.

Acceptance:

- Learn a rank whose training level exceeds 1, die, and retain that rank at level 1.
- After selecting another class, the rank remains usable when its other conditions are met.
- Looping does not grant unlearned higher ranks or duplicate an already learned rank.

### FR-004 — Health and mana

Health and mana shall be the only player resources in the demo and shall always be visible.
There is no resource discovery system, rage, energy, or form-specific resource switching.

Acceptance:

- New Game and every Loop start with full health and mana.
- Class selection neither replaces these resources nor changes the mage stat baseline.
- Spending and regeneration follow the sourced mage rules in DATA-002 in simulation time.

### FR-005 — Marshal class selection

From Loop 2 onward, the marshal near spawn shall offer one class selection per Loop, only
while the player is level 1 and has never accepted a quest in that Loop. Opening the
marshal's conversation does not itself accept a quest. Declining or canceling keeps the
choice available; accepting any quest closes it even if that quest is later abandoned.

Selection shall exchange the starter outfit for the chosen class's starter outfit, change
the sprite and trainer access, and preserve learned skills and base stats. Current health
and mana are preserved except for clamping after equipment changes.
Selection itself grants no skills; level-1 skills of a newly chosen class shall be available
free at its trainer without quest prerequisites. This keeps class selection's effects
limited to equipment, presentation, and training access.

Acceptance:

- Loop 1 starts as mage; an eligible Loop 2 player can choose druid exactly once.
- Selecting a class replaces only remaining items from the granted starter outfit,
  including carried pieces; acquired equipment is not deleted. Replaced slots with acquired
  gear keep that gear and put the new starter piece in inventory. Insufficient capacity
  rejects the whole exchange without consuming the choice.
- Selection does not refill resources or grant currency; ordinary equipment modifiers apply
  and current health/mana are clamped if a maximum falls.
- Abandoning a quest or returning to level 1 does not reopen an expired choice.
- Dialogue identifies the player and provides suitable clothes.

### FR-006 — Demo completion

Killing any demon stalker shall immediately stop simulation and show “Thanks for playing”.
The completion screen shall offer Load and Main Menu; it shall not continue the completed
attempt. Loading an earlier save resumes that save normally.

Acceptance:

- One stalker death completes the demo; ordinary NPC deaths do not.
- After a lethal stalker effect, no remaining queued damage, NPC action, or arrival executes.
- Check terminal outcomes after each resolved effect, in FR-013 order. For a single effect
  killing both player and stalker, completion takes precedence over Loop reset.

## Movement and simulation time

### FR-007 — Eight-direction grid movement

The player shall move between grid tiles in eight directions. At base speed, one successful
movement action shall move one tile and consume one turn. Diagonal movement has the same cost.

Acceptance:

- Cardinal and diagonal moves into free tiles each move exactly one tile at base speed.
- Passing diagonally between two blocked neighboring tiles succeeds if the destination is free.
- Keyboard movement supports all eight directions; layouts are covered by FR-043.

### FR-008 — Blocking and invalid movement

Living NPCs and objects designated as blocking shall prevent entry to their tiles. Corpses
shall not block movement. An impossible move shall leave position and simulation time
unchanged, except when the input requests an attack under FR-009.

Acceptance:

- Moving into a blocking object or beyond the traversable map does not advance NPCs or timers.
- A corpse on an otherwise traversable tile allows entry.
- Movement cannot leave two living actors occupying the same tile.

### FR-009 — Movement into NPCs

Attempting to move into a hostile NPC shall request a melee attack without moving the player.
Moving into a friendly or neutral NPC shall only block movement; attacking a neutral NPC
requires an explicit interaction.

Acceptance:

- A hostile bump requests combat using FR-014 timing.
- A friendly or neutral bump causes no damage, hostility change, or turn advancement.
- Explicit engagement changes a neutral NPC to hostile under FR-020.

Use F (Interaction) to select and confirm a neutral melee target under FR-021.

### FR-010 — Player-driven time and waiting

Simulation time shall progress only through time-consuming player actions. One turn shall
represent one second of source time, with a one-turn global cooldown (GCD) for ordinary
spells. This GCD is an explicit adaptation from Classic's usual 1.5 seconds (REF-006).
Cooldowns, regeneration, periodic effects, and arrivals shall use simulation time.

| Action | Simulation cost |
| --- | --- |
| Movement input with a legal next tile | One turn, with movement progress under FR-011. |
| Wait | Exactly one turn. |
| Melee request | Whole turns until a swing is available; fractional timing under FR-014. |
| Spell | Cast duration rounded under FR-012, minimum one turn when on the GCD. |
| Explicitly free instant spell/action without a GCD | Zero; no NPC phase or fractional credit. Other resource/cooldown conditions still apply. |
| Equip, unequip, or consume an item successfully | One turn; item effects/cooldowns still apply. |
| Conversation, quest operations, training, trading, looting, inventory rearrangement | Zero. Attacking through interaction uses melee timing. |
| Menus, targeting, cancellation, and actions rejected before execution | Zero. Time already spent on an interrupted/failed cast is not refunded. |

Acceptance:

- Awaiting input never moves NPCs, regenerates resources, expires effects, or advances arrivals.
- A Wait grants every applicable system exactly one turn, regardless of NPC count.
- A rejected equip/use/cast changes neither simulation time nor resources.
- A multi-turn action permits cancellation between boundaries; each completed boundary
  still grants NPCs their phase. A committed melee request advances these boundaries
  automatically without repeated confirmation, while Escape can cancel before the next
  boundary. Real-time animation may continue while simulation is paused.

### FR-011 — Fractional movement

Movement speed shall be tiles per movement turn. Each accepted movement action adds that
speed to a separate movement balance and spends one unit for each tile traversed in the
requested direction. Fractional and unspent whole credit shall persist through action-type
changes, collisions, interruptions, and speed changes; a Loop reset clears it.

Acceptance:

- From zero credit, speed 1.5 over two unobstructed actions moves 1 then 2 tiles.
- From zero credit, speed 0.5 moves 0 then 1 tile; both inputs consume one turn.
- An initially blocked destination rejects the action without time cost or added credit.
- If an extra step is blocked, stop at the last legal tile and retain unspent credit.
  A hostile encountered on an extra step stops movement; it does not add an automatic attack.
- Check blocking and aggro at every traversed tile. Crossing acquisition range can engage
  an enemy even if the final tile is outside it; enemies act in the following shared phase.
- Waiting or casting does not add movement credit. Credit cannot pay for another action type.

### FR-012 — Cast completion and fractional credit

All player spells shall share one casting-credit balance, separate from movement and melee.
For a positive-duration cast, let `D = max(1, source_cast_seconds)` after applicable speed
modifiers and `C` be existing credit. Consume `max(1, ceil(D - C))` whole turns. On success,
new credit is `C + consumed_turns - D`. Ordinary instant spells use D = 1; explicitly free
instant spells bypass this calculation and leave credit unchanged.

Acceptance:

- A 1.4-turn cast from zero credit consumes two turns and leaves 0.6 credit. A subsequent
  1.4-turn cast consumes one turn and leaves 0.2 credit, even for a different spell.
- Instant and sub-turn ordinary casts consume one turn; a one-turn spell preserves prior credit.
- Effects and resource costs apply once at successful completion; NPC phases occur at
  intervening boundaries. Validate target, range, line of sight, and resources again then.
- Canceling or failing at completion retains credit held before the cast and awards no new
  credit. Elapsed turns stay spent; an uncompleted spell has no effect or resource charge.
- The GCD starts on cast start; an individual spell cooldown starts on success unless its
  sourced data specifies otherwise. Time already advanced also advances active cooldowns.
- Credit survives action-type/speed changes and is only cleared by Loop reset.
- Channels use their sourced periodic ticks on simulation boundaries; delivered ticks and
  their resource costs remain delivered after interruption, without completion credit.

### FR-013 — Shared NPC phase

Each elapsed turn shall resolve player action/progress, then one shared NPC phase, then
remaining periodic effects, regeneration, and scheduled world events. Timers advance once
per turn, never once per actor. Within each stage use stable saved ordering and check deaths
and completion after every effect. Summoned allies also use the shared actor phase.

Acceptance:

- Moving into aggro range permits pursuit in the immediately following phase.
- Ten base-speed NPCs each receive one turn of opportunity; cooldowns advance only one turn.
- NPC order is reproducible, with spawned actors appended; stable spawn identity breaks ties.
  Sorting initial actors by starting distance is permitted but not required.
- Earlier resolved movement claims a free tile; later actors find a legal alternative or wait.
- A new arrival may aggro immediately but first moves/attacks in the next shared phase.
- Terminal completion or Loop reset discards the remainder of the ended attempt's phase.

### FR-014 — Melee range and swing timing

All eight adjacent tiles shall be melee range. Swing timers shall advance with simulation
time even outside melee range. A ready NPC entering melee shall attack in the same phase.
A hostile bump or confirmed neutral attack shall spend whole turns until at least one
swing can resolve, provided the target remains valid and adjacent. After that request,
waiting turns advance automatically with no additional confirmation menu. Input may cancel
between boundaries under FR-010; simulation stops again when the requested swing resolves.

Fractional swing progress shall persist between turns. Resolve all swings due in a phase
in order while the target is alive and adjacent; faster weapons can produce multiple
swings, slower weapons can have intervening phases without a swing. Outside active melee,
readiness shall stop at one ready swing rather than bank unlimited attacks. Entering melee
with a ready timer resolves one initial swing and starts its next delay at that phase
boundary; subsequent active-melee phases retain elapsed fractional remainder.

Acceptance:

- Adjacent cardinal/diagonal opponents are in range; tile distance 2 is outside melee.
- A ready enemy moves adjacent and attacks; entering range does not erase a positive delay.
- With a fresh 1.5-turn swing delay, subsequent due swings occur after 2, then 1 elapsed turns.
  A 0.5-turn delay permits two due swings in one elapsed turn.
- A player melee request has a minimum one-turn cost, including a ready swing. If waiting
  for a later swing, NPCs still receive every intervening phase.
- Losing adjacency while waiting stops the request without refunding elapsed time.
- Changing action type or speed preserves accumulated fractional progress; reset clears it.

### Worked timing example

For an unobstructed base-speed enemy and a nonlethal 1.4-turn test spell:

| Turn | Player phase | Following NPC phase |
| --- | --- | --- |
| 1 | Move north into aggro range. | Enemy detects the player and moves south toward them. |
| 2 | Begin a 1.4-turn cast; one turn of casting elapses. | Enemy moves one tile closer. |
| 3 | Finish the cast at the second casting boundary, resolve its effect, retain 0.6 casting credit. | Enemy moves adjacent and attacks immediately if its swing is ready. |

## Character and skills

### FR-015 — Character stats

The player shall have strength, agility, stamina, intellect, and spirit, plus the combat
values needed for attack power, critical strikes, haste, hit, defense, armor, spell power,
and resistances. Starting values shall use the same Classic human-mage baseline in every
Loop, independent of later class selection. NPCs need only the subset used by their behavior.

Acceptance:

- New Game and a reset Loop have matching starting stats after removing transient effects
  and equipment.
- Stats used by an implemented spell or attack affect its outcome under FR-026.
- Class selection does not substitute another class's starting stat profile.

Use human-mage base attributes and mage level growth with all active and passive racial
effects removed; the player is mechanically raceless. DATA-001 records numeric values and
their provenance before stat implementation. No class choice substitutes another growth curve.

### FR-016 — Experience and leveling

The player shall gain XP from eligible kills and quest rewards and level up at the selected
Classic/Vanilla thresholds. Threshold crossings shall retain excess XP, including when one
reward crosses multiple levels, and apply the corresponding stat growth.

Acceptance:

- From 0 XP, 399 XP leaves level 1; a further 1 XP reaches level 2.
- A 450-XP award at level 1 leaves level 2 with 50 XP toward its next 900-XP threshold.
- Kill XP is awarded once on death, not again when looting.

There shall be no demo-specific level cap. Trainers stop at ranks learned by level 10.
Ordinary zone enemies eventually become gray and grant no kill XP under the Classic rules;
progress much beyond level 15 is therefore a tuning expectation, not a hard prohibition.
Only eligible kills, quests, and development skills award XP; exploration/rested XP are excluded.
Player-owned pet/totem kills count as player kills, once.

REF-002 and DATA-002 supply the thresholds and reward rules through Classic level 60.
For development awards beyond the sourced range, continue using the last verified
next-level XP threshold and mage stat increment rather than silently imposing a cap.
This fallback is an Ostinato extension, not a claim about Classic progression beyond 60.

### FR-017 — Learned ranks and casting conditions

Skills shall have ranks and appear in the spell book once learned. Trainer learning shall
enforce the rank's training level; casting a learned rank shall not enforce that level.
Casting shall apply the rank's effects and its resource, cooldown, range, and target conditions.

Acceptance:

- An unlearned rank is unavailable for ordinary casting.
- An otherwise valid learned spell succeeds below its training level.
- Insufficient required resources or an invalid target prevents a successful cast.
- A successful cast applies its effect and resource cost once.

Rejected actions and completion failures follow FR-010/FR-012. Rank data belong to DATA-003.
Class and learning level do not gate use; required weapon/shield type still does.
Consumable reagents and carried casting tools such as elemental totem items are ignored.

### FR-018 — Demo classes and skill coverage

The completed demo shall support mage, druid, warlock, priest, shaman, and paladin, with
their Classic non-racial starting/trainer skills and ranks available at learning levels
1–10 inclusive. Mage is initial. Warrior, rogue, hunter, professions, and talent trees are
outside the demo. Included trainer passives persist like learned active abilities.

Acceptance:

- Every class has a selectable sprite, free starting-skill training, and a sourced inventory
  of included ranks, costs, and prerequisites (DATA-003).
- Exclude druid forms and all form-only abilities, racial actives/passives, and quest-awarded
  skills, except the summon exceptions below. Ignore consumable reagents and casting tools.
- Warlock Imp and Voidwalker and shaman Earth/Fire totems available by level 10 are included.
  To make them accessible without class quests, teach summon/unlock spells at trainers at
  their original availability levels; do not implement the source unlock quests (REF-007).
- A single warlock pet can follow, attack, stop/follow, and be dismissed. Pet actions use
  simulation time, valid targets, and normal obstruction rules. Pet state is saved; death
  removes the active pet without unlearning the summon. Resummoning is permitted in later Loops.
- Totems are stationary and use their sourced health, duration, range, and effects. One per
  element is active; a new same-element totem replaces the old one.
- Pet abilities/ranks available by pet level 10 are included and use the pet's current level.
  No new above-10 ability ranks are granted by player leveling.
- Summons appear on a free adjacent tile, selected in stable order. If none is available,
  the cast fails under FR-012 without deleting an existing summon. Living summons block
  tiles like other actors. Replacing a totem may reuse its tile if it is adjacent.
- Class changes leave learned abilities usable. Active pets/totems disappear on Loop reset.

### FR-019 — Weapon proficiency and durability exceptions

The player shall be proficient with all weapon types without separate weapon-skill training.
Items shall not lose durability or require repair.

Acceptance:

- Using another weapon type does not require weapon-skill training or grinding.
- Combat and death do not introduce repair costs or broken equipment.

Effective weapon proficiency and defense shall always equal the Classic maximum for the
current level: 5 × level, with no practice grind. All weapon and armor proficiencies are
available; selected class and race do not restrict item use. Preserve item level requirements,
slot rules, hand occupancy, and unique-equip rules; dual wield still requires its capability,
which no included demo class learns by level 10. DATA-002/004 record the resulting calculations.

## NPCs, targeting, and combat

### FR-020 — NPC relationships

NPCs shall be friendly, neutral, or hostile. In the default palette, their sprites shall
communicate these states with green, yellow, and red respectively. Friendly NPCs support
interaction only; explicitly engaging a neutral NPC makes that NPC hostile.

Acceptance:

- Friendly NPCs cannot be damaged through ordinary player attacks.
- A neutral NPC stays neutral after a blocked movement attempt but becomes hostile when
  explicitly engaged and adopts the hostile presentation.
- Relationship rules remain the same under alternate palettes (NFR-008).

Story-driven exceptions remain future design space; no generic faction/event framework is
required by this reservation.

### FR-021 — NPC interaction

F shall interact with NPCs/corpses at tile distance 1, and corpses on the player's own tile.
With exactly one candidate, skip target selection and request its interaction immediately.
With several candidates, preselect the closest and use the directional selector; Enter
chooses the target and Escape cancels. A neutral living NPC always requires a separate,
explicit attack confirmation naming the target, including when it is the only candidate.
No candidate gives feedback without advancing time. This single-candidate shortcut applies
to Interaction, not targeted skills under FR-024.

Acceptance:

- Friendly NPCs expose their applicable conversation, quest, trade, training, or
  class-selection choices; corpses expose remaining loot choices. If an interaction offers
  no player choice, write its result in chat and open no dialogue.
- Choosing a hostile living target requests melee immediately. Choosing a neutral living
  target first shows “Attack <name>?” with an Attack control bound to Enter and a Cancel
  control bound to Escape. Previewing or canceling either selection or confirmation
  changes neither hostility nor simulation time.
- Interaction prompts use visible keyboard shortcuts and mouse buttons. Tab does not move
  focus through these prompts; Enter cannot activate a different action than its label.
- Conversation, services, and looting are allowed in combat and cost no time. Equipping,
  consuming, and attacking retain their ordinary time costs.
- A corpse beneath another actor remains selectable if in range. Menus never grant
  simulation time merely because they remain open.

### FR-022 — Aggro, pursuit, and blocked routes

Hostile NPCs shall acquire the player with clear line of sight within their configurable
tile aggro range, initially 5 tiles. Engaged enemies shall pursue outside that radius and
after losing sight. No ordinary distance leash is required.

Acceptance:

- Initial aggro requires both range and sight; subsequent pursuit navigates around obstacles.
- If static terrain prevents any route to a valid attack position for 5 consecutive turns
  (initial tuning default), disengage and return toward the home tile, restoring health on
  reaching it. If home is unreachable, remain legally placed and idle until a route opens.
- Congestion caused only by other living actors does not trigger leashing: wait or approach
  the nearest reachable position instead. Evaluate static reachability separately.
- A new reachable route resets the blocked-route counter. Dead actors never remain engaged.

### FR-023 — Wandering and crowded pursuit

Designated NPCs shall wander randomly within a configured area. Engaged NPCs shall attempt
to use available positions around the player when space is limited.

Acceptance:

- Repeated waits let a wandering NPC change tiles within its allowed area, respecting blocking.
- Pursuers first follow a shortest terrain route to melee range, ignoring actors beyond
  their next step. Among equally short routes prefer approaching the player's tile directly,
  with stable tie handling. Only when the chosen next step is occupied by another living
  actor do they seek an alternate route/free melee position. They never overlap or enter
  blocked terrain.
- With no legal step, an NPC remains on a legal tile.

Movement conflict ordering follows FR-013. No optimal formation or specific navigation
algorithm is mandated.

### FR-024 — Target selection

A targeted skill shall enter target selection and automatically select the closest valid
target, or the only valid target. With none, selection shall exit without casting. Movement
keys shall navigate multiple candidates directionally with wraparound.

Acceptance:

- One valid target is selected; with several, the nearest is selected initially.
- Directional selection changes the candidate without moving the player.
- Navigation past the last candidate in a direction wraps to an eligible candidate.
- No valid targets produces no spell effect or resource expenditure.

Preselection never casts: Enter confirms and Escape cancels. Damage abilities may select
neutral or hostile targets; friendly NPCs are invalid damage targets. Healing/buffs use their
own eligible targets, including self when applicable. Distance is Chebyshev; ties use stable
identity ordering. Directional candidate/wrap ordering is an implementation choice that must
be fixed and reproducible without consuming combat randomness.

Confirming a harmful action on a neutral starts engagement before its cast progresses;
previewing/canceling selection does not. An enemy remains engaged even if the attack later misses.

### FR-025 — Line of sight without hidden world vision

Targeting and hostile aggro acquisition shall respect line of sight. World objects shall not
hide the player's world view merely because they obstruct line of sight.

Acceptance:

- A target behind a designated sight-blocking object remains visible but cannot be selected
  for an action requiring clear line of sight.
- The same obstruction prevents initial hostile aggro through it.
- Removing the obstruction permits targeting/aggro when other conditions are satisfied.

Sight checks shall trace between tile centers against designated solid sight blockers.
A ray crossing a blocker interior fails; touching only a corner does not, matching permitted
diagonal movement. Living actors do not block sight. Recheck at cast completion.

For converting Classic ranges, one tile represents 5 yards. Convert maximum ranges with
floor(yards / 5), with a minimum of one tile for a positive ranged value; compare Chebyshev
distance. Apply source minimum ranges with ceil(yards / 5). Melee remains exactly one tile.
Thus 30 yards becomes 6 tiles; distance 7 is invalid. This grid scale is an Ostinato
adaptation independent of tentative sprite pixels and the final map dimensions.

### FR-026 — Classic combat with explicit adaptations

Damage, mitigation, attack outcomes, resource use, and stat effects shall follow documented
Classic/Vanilla behavior except for the explicit adaptations in these requirements.
Combat shall retain level/stat differences and randomness; it is not guaranteed damage on
every attack. NPC data may omit stats irrelevant to their actions.

Acceptance:

- With controlled random outcomes, an attack's recorded result and health change match the
  selected combat rule and attacker/defender data.
- Relevant changes to armor, resistances, offensive stats, or active effects produce the
  corresponding documented outcome.
- The same initial simulation state and action sequence reproduce outcomes under NFR-013.
- Every implemented formula and exception has a version-qualified reference or an explicit
  game-specific decision in its feature data record.

REF-001 records the baseline; DATA-002 supplies version-qualified formulas before use.
Actors have eight-way facing, changed by movement or a committed targeted attack. For combat,
the three neighbor directions opposite the defender's facing are behind: NW/W/SW when
facing east. For distant attackers, quantize the relative direction to the nearest of the
eight directions with stable tie handling. Preserve Classic player-versus-NPC rear-attack
differences in the attack tables; rear position is not automatically a critical hit.

### FR-027 — NPC death and corpses

A killed NPC shall stop acting, award its applicable XP once, and leave a non-blocking corpse
that can be interacted with for loot.

Acceptance:

- A dead NPC neither moves nor attacks in subsequent phases.
- Repeated corpse interaction does not repeat kill XP or previously collected loot.
- A new Loop restores the corresponding living spawn.

A corpse disappears after it is fully looted or after 300 turns from death (initial default),
whichever comes first. Empty corpses can disappear immediately. The story guard's corpse
persists for the Loop. Friendly NPCs other than that guard respawn at their fixed home after
30 turns if killed by a scripted event. Player attacks cannot kill friendlies.

Hostile/neutral populations replenish under FR-029 with new seeded identities, not by
reviving the looted actor. Chests do not replenish within a Loop.

### FR-028 — Deterministic loot

Each seeded NPC instance and treasure chest shall have reproducible loot for that game.
Killing corresponding NPCs in a different order shall not change their individual drops.

Acceptance:

- Record loot from NPC A, NPC B, and chest C; reset the Loop with matching quest eligibility
  and collect B, C, A. Each source gives the same item identities and quantities as before.
- Two NPCs of the same creature type are not required to have identical loot.
- A source cannot be emptied repeatedly for duplicate rewards during the same lifecycle.
- Loading preserves both the assigned loot and which items have already been taken.

Loot is selected from source tables (DATA-004) independently of combat randomness.
Quest-item rolls belong to the seeded source too, but eligibility is captured at death
(or first chest opening): grant such drops only for accepted, not yet handed-in quests,
even when their objective count is already fulfilled. Accepting a quest later does not
add loot retroactively. Non-quest loot is unaffected by eligibility. Hand-in or abandonment
removes eligibility to collect remaining quest-only drops.

The same instance with the same eligibility yields the same loot across Loops; different
eligibility changes only the quest-item filter, never rerolls ordinary loot.

## World and content

### FR-029 — Fixed and seeded world elements

The world shall combine fixed quest givers, their quests, and a fixed player spawn with
seeded neutral/hostile spawns inside configured areas. The seed shall persist across Loops.

Acceptance:

- The same game recreates corresponding spawn instances and their initial placement across
  Loops, with the same fixed quest givers and player spawn.
- Seeded spawns stay within their configured areas and legal tiles.
- Distinct seeds may produce different random elements without relocating fixed elements.

Each population slot shall have a seeded sequence of replacement NPCs from its area's
allowed types. Death schedules its next ordinal after 30 turns (initial default). Derive
type and loot from seed, area, slot, and ordinal, never global kill order; placement must
respect legal unoccupied tiles. A blocked spawn stays pending and retries each turn.
Live positions and spawn timing may differ with actions; corresponding ordinals still have
the same loot. Reset returns every slot to ordinal zero. Save/load preserves ordinals and
pending delays. Initially budget at most 100 active world NPCs including stalkers;
the five stalker positions are reserved when setting ordinary population limits.

### FR-030 — Northshire demo content

The completed demo shall model Classic Northshire Abbey and its starting area, including
all applicable Classic Northshire NPCs and quests and the world objects needed to use them.
Adaptations for a 2D grid, single-floor interiors, and the invasion shall be documented.

Acceptance:

- A content inventory maps each required source NPC, quest, and necessary object to an
  implemented counterpart and records any adaptation.
- Every included quest has accessible givers, required targets/objects, and a completable
  objective and hand-in path.
- Added class trainers support the game's classes even where the original setting differs.

The playable boundary is the valley enclosed by impassable hills/walls and its gate.
No outside world is built. Exclude outbound quests and all class quests except the initial
class-specific trainer referral. Preserve ordinary prerequisites/minimum levels; remove race
restrictions for this raceless player. Class-specific referrals use the currently selected
class at acceptance. Add missing class trainers at accessible locations in the enclosed zone.

DATA-004 shall enumerate all in-boundary Classic NPCs and quests, mark exclusions with these
reasons, and record the guard's scripted death and added trainers. Source “all” refers to
this bounded inventory, not a convenient sample. Modern layouts may inspire placement of
added trainers only; mechanics and ordinary content remain Classic.

### FR-031 — Invasion setting

The story shall depict a sudden Burning Legion invasion spanning the continent, besieged
major cities, and NPCs with differing awareness of the crisis. A high-level demon stalker
shall threaten the Northshire gate, where a guard has been killed.

Acceptance:

- Dialogue, world presentation, or messages establish the invasion and confusion.
- The gate scene makes the dead guard and stalker threat observable.
- The marshal remains accessible near the player's spawn.

The guard starts alive. The first stalker enters from the gate on its scheduled turn,
kills the guard as a story event, and idles nearby, presented as feasting. Subsequent
stalkers enter and idle around the gate; normal aggro still triggers combat. Tune the first
arrival to precede the earliest ordinary base-speed route from spawn to gate; development
shortcuts may expose the living guard. The guard does not respawn until the next Loop.

### FR-032 — Enterable buildings

The world shall contain enterable buildings with usable interiors, without multiple floors.

Acceptance:

- The player can enter and leave an included building and interact with its interior content.
- Blocking, targeting, and turn rules continue to apply inside.
- Required content does not depend on stairs or another floor.

The representation of interiors is an implementation choice.

### FR-033 — Escalating stalker arrivals

The first stalker shall arrive a small number of turns after each Loop begins. Additional
stalkers shall arrive after initially large but decreasing intervals. Every arrival shall
be announced in chat.

Acceptance:

- With a free entry tile, each arrival occurs on its configured turn and is announced once.
  A blocked entry remains pending under the rule below.
- Consecutive reinforcement intervals decrease according to the chosen schedule.
- Waiting for real time without taking actions does not advance the schedule.
- Death resets the schedule; loading restores its saved progress.
- Existing stalkers remain threats when another arrives unless normal gameplay removes them.

Initial tuning: arrivals at turns 15, 215, 395, 555, and 695 from Loop start. The first
reinforcement follows after 200 turns; later gaps shrink by 20 (180, 160, 140). Stop after
five total arrivals per Loop; there is no additional interval-floor rule to implement.
Use level-20 stalkers with sourced ordinary creature stats as the starting combat profile.
Gate tiles shall accommodate arrivals without overlap; if all are blocked, queue the
arrival and announce once when it can enter, without shifting later scheduled deadlines.

Tune schedule, placement, and stats through the balance playtest below. These are initial
values, not a guarantee that a player must die or succeed at a particular Loop count.

## Quests, inventory, and services

### FR-034 — Quest lifecycle

Quests shall support acceptance, objective completion, hand-in, and abandonment. Completion
of objectives shall be distinct from handing in the quest. Repeatable quests are excluded;
Loop reset makes ordinary quests available again.

Acceptance:

- Accepting adds a quest to the log; meeting objectives makes it ready for hand-in.
- Handing in grants its rewards once and records it as handed in for the current Loop.
- An incomplete quest cannot be handed in.
- Abandonment removes it from the active log; a new Loop clears all progress and restores
  availability subject to the normal prerequisites.

Prerequisites and rewards follow DATA-004. Abandoning resets objectives and deletes all
quest-only items associated with that quest from inventory and pending collectible loot;
ordinary items are unaffected. Reacceptance starts fresh, subject to normal prerequisites.
Hand-in consumes required items and removes surplus quest-only copies so they cannot leak
into a subsequent acceptance. A full inventory prevents a reward transaction atomically.

### FR-035 — Quest objectives and difficulty

Quests shall support kill, loot, location, and NPC-conversation objectives. Their displayed
difficulty shall use Classic's gray, green, yellow, orange, and red relative to player level.

Acceptance:

- Only the specified NPC, item, location, or conversation advances the corresponding objective.
- A quest with multiple objectives becomes complete only when all are satisfied.
- Objective counts and completion status are visible and survive save/load.
- Changing player level updates displayed difficulty according to the chosen thresholds.

Use the five Classic bands, including orange (REF-008). Quest levels at least 5 above the
player are red; 3–4 above are orange; from 2 below through 2 above are yellow. Lower quests
are green until the Classic quest-gray cutoff, then gray. DATA-004 shall record the
level-dependent cutoff table and boundary fixtures before the quest UI is implemented.
Difficulty display does not by itself determine quest availability or zero out quest XP.

### FR-036 — Class training

Class trainers shall expose a skill-learning window through conversation. Learning shall
require the matching selected class and the skill rank's training level, plus source
prerequisites and costs after the explicit FR-005/FR-018 exceptions.

Acceptance:

- A matching-class player below the training level cannot learn the rank.
- An eligible player meeting the requirements can learn it and see it in the spell book.
- A mismatched class cannot use that trainer to learn the rank, but retains skills already
  learned from that class.
- Repeatedly selecting an already learned rank cannot charge for or duplicate it.

Trainer costs and rank prerequisites belong to DATA-003.

### FR-037 — Inventory and equipment

The player shall have a WoW-inspired inventory with increased but fixed bag capacity, item
storage, and usable equipment. Items and equipment acquired during a Loop shall be lost on
reset under FR-002.

Acceptance:

- Acquiring an item places it in available inventory capacity with its correct quantity.
- Equipping or unequipping an item applies or removes its documented stat/effect contribution.
- A full inventory does not silently destroy newly offered loot; the player can recognize
  that it was not collected.
- Save/load restores item quantities, placement, and equipment.

There shall be 40 fixed inventory slots with no expandable bags. Preserve Classic stacks,
consumable effects, slot and level rules, except for class/race/proficiency adaptations in
FR-019. Equipment slots are head, neck, shoulders, back, chest, shirt, tabard, wrists, hands,
waist, legs, feet, two rings, two trinkets, main hand, off hand, and ranged/relic.
A two-handed weapon occupies both hands. Moving equipped items requires inventory space;
failed swaps leave all items and stats unchanged. DATA-004 records per-item values.

### FR-038 — Currency and trading

The player shall earn and spend gold. Trader interaction shall open a trade window that
allows buying and selling the included tradable items using their configured prices.

Acceptance:

- Buying with enough currency and capacity transfers the item and deducts its price once.
- Insufficient currency or capacity prevents completion of a purchase.
- Selling transfers the selected item/quantity and grants the configured proceeds once.
- A Loop resets gold; save/load restores the saved amount.

Store currency as whole copper: 100 copper = 1 silver; 100 silver = 1 gold. Use source
prices and finite/unlimited stock flags from DATA-004. Finite stock never replenishes within
a Loop; reset restores it. Unlimited stock remains unlimited. Buyback is excluded.
Buying/selling an explicitly selected quantity is atomic, with no partial charge or transfer.

## Saving, menus, and interface

### FR-039 — Five save slots and overwrite confirmation

The game shall initially provide five fixed save slots through a shared save/load interface.
Occupied slots shall show the save's system timestamp and Loop count. Overwriting shall
require confirmation.

Acceptance:

- Exactly five slots are available; empty and occupied slots are distinguishable.
- Saving to an empty slot records the game and its timestamp/Loop metadata.
- Canceling overwrite leaves the previous save unchanged; confirming replaces that slot only.
- Copying a game to another slot preserves its seed and progression history.

Changing slot count later requires a deliberate requirements update.

### FR-040 — Saving outside combat

Saving shall be available only outside combat. Save attempts in combat shall not create or
overwrite a save. Failure handling is specified by NFR-010.

Acceptance:

- A valid out-of-combat game can be saved.
- During combat, both UI and bound save actions enforce the restriction.
- A rejected save attempt leaves existing slot contents unchanged.

Combat begins when a hostile actively engages the player or a player-owned ally, or when
the player starts a harmful cast against a hostile/neutral. It ends when no such engagement,
harmful pending cast, or continuing harmful effect remains. Saving also requires an action
boundary with no pending skill or partially resolved turn, even outside combat.
Loading is allowed during combat and pending actions; it discards the abandoned continuation.

### FR-041 — Complete saved-state restoration

Loading shall restore the entire saved game state unless an explicit requirement states an
exception. It shall resume the saved Loop rather than starting a new Loop or generating a seed.

Acceptance:

- Save outside combat, then change location, stats/resources, inventory, quests, and world
  state: loading restores all their saved values.
- Restore seed, Loop count, learned ranks, selected class and selection eligibility,
  NPC/pet/totem states, corpses, loot, chests, active effects, and scheduled arrivals.
- Restore simulation time, cooldowns, fractional progress, and random state needed for
  reproducible continuation; loading is not a free reroll.
- Save-slot copies and repeated loads do not add skills, items, or completed objectives.

Global settings are not rolled back by loading. Hotbar assignments/lock are per-game state;
keybindings are global. Pending work in the replaced world cannot execute after a load.
Damaged and unsupported saves are covered by NFR-011 and NFR-012.

### FR-042 — Main menu

The main menu shall have centered New Game, Load, Options, and Exit controls, a bottom-right
version label in `major.minor.githash` form, and a bottom-left copyright label.

Acceptance:

- New Game starts FR-001; Load and Options open their interfaces; Exit closes the application.
- Version and copyright labels remain visible at supported display sizes.

Use “Copyright Postperson studio, 2026”. Before Git metadata exists, use `xxx` as the hash,
for example `0.1.xxx`; replace it with the build's short commit hash once available.

### FR-043 — Options and keybindings

Options shall be accessible from the main menu and game. Shared save/load and keybinding
interfaces shall be available in the appropriate context; in-game options shall offer return
to the main menu. Core play shall use keyboard controls with mouse support under NFR-007.

Acceptance:

- The player can rebind supported actions and use the new bindings.
- All eight movement directions are available through the chosen WASDQEZC and/or numpad
  defaults; these include diagonal controls.
- In-game options reach save/load and return to the main menu.
- The main-menu context offers loading and does not save an absent active game.

Default controls:

| Action | Default |
| --- | --- |
| N / W / S / E | W / A / S / D; arrow keys; numpad 8 / 4 / 2 / 6 |
| NW / NE / SW / SE | Q / E / Z / C; numpad 7 / 9 / 1 / 3; simultaneous orthogonal arrow keys |
| Wait | Period or numpad 5 |
| Interact | F |
| Target/menu navigation | Movement directions; Enter confirms, Escape cancels/returns |
| Hotbar slots | Top-row 1, 2, 3, 4, 5 (distinct from numpad movement) |
| Inventory / spell book / quest log / character | I / K / J / P |
| Options | Escape when no modal action/window is active |
| Fullscreen | F11 or Options toggle |
| Save/load | Options; no quick-save bypass |

Rebinding within the same active context shall report a conflict and require an explicit
swap/reassignment; it shall not silently trigger two actions. Gameplay input is suppressed
while a menu/text field/selector owns focus. Options, palette, display settings, and bindings
persist globally across restarts and save slots. Unsaved Exit, Main Menu, New Game, or Load
that would discard the current attempt asks for confirmation; confirming discards changes.

### FR-044 — Player-centered camera

The gameplay camera shall remain centered on the player at a fixed view scale.

Acceptance:

- Moving or resetting the player recenters the view on their tile.
- The player remains centered at world edges; the camera does not silently switch to
  edge-clamped tracking.
- Display resizing follows NFR-002: aspect-ratio changes may expose more world while pixels
  retain a uniform integer scale and the camera remains centered.

There is no gameplay zoom control; display scaling follows the base art resolution.

### FR-045 — Hotbar

The hotbar shall support dragging skills from the spell book, binding keys to slots, and
locking the layout.

Acceptance:

- Assigning a learned skill to a slot allows activation with its bound key.
- Locking prevents layout changes while preserving activation.
- Activation uses the same targeting and casting conditions as the spell book.

There shall be five slots, bound to top-row 1–5 by default. Assignment stores an explicit
learned rank; learning a higher rank does not silently replace it. The tooltip shows rank,
cost, and effects without requiring rank text on the icon. Assignments and layout lock
persist across Loops and saves for the same game. New Game starts with empty assignments.
Keyboard users can select a spell/rank, choose Assign, and choose a slot with 1–5.

### FR-046 — Spell book

The spell book shall organize skills by class tabs and include a development tab. Clicking
a learned spell shall request its cast, including target selection where applicable.

Acceptance:

- Skills retained from earlier classes remain visible under their corresponding tabs.
- Clicking a targeted spell enters FR-024; clicking an otherwise valid untargeted spell
  requests its effect.
- Learned ranks are identifiable; the development tab exposes FR-050 in development builds.

The spell book shall expose every learned rank with a readable rank label/tooltip and
keyboard selection/activation. The development tab and debug skills are hidden in the
delivered demo and visible only in development builds.

### FR-047 — Quest log

The quest log shall show accepted quests, their objectives and progress, and readiness for
hand-in, and shall permit abandonment.

Acceptance:

- Accepting, progressing, completing, and abandoning a quest update the log.
- A ready-for-hand-in quest remains distinguishable from a handed-in quest.
- Loading and Loop reset update the log consistently with FR-034 and FR-041.

### FR-048 — Chat and combat feedback

The game shall provide chat-style messages including combat results, development-skill
feedback, and announcements of new stalkers. Multiple chat tabs are not required.

Acceptance:

- A resolved attack or spell provides enough information to identify its action and outcome.
- Every stalker arrival produces a recognizable announcement.
- Development actions such as XP gain visibly report their result.

Exact message format and history retention are implementation/UI details subject to
readability requirements, not a requirement for a multiplayer chat system.

### FR-049 — Player frame

The player frame shall show current/maximum health and mana.

Acceptance:

- Values update after spending, regeneration, damage, healing, equipment changes, load,
  and Loop reset.
- Both remain visible for every class; no resource-discovery state or unused resource bars
  are displayed.

### FR-050 — Development skills

Development gameplay shall provide test skills, including adding a known amount of XP and
killing the player, with observable feedback. Initial dummy skills shall consume one turn.

Acceptance:

- The XP skill grants its stated amount and exercises ordinary level progression.
- The death skill exercises the currently implemented death flow: the temporary milestone-3
  overlay, then the real Loop flow from milestone 4.
- Initial dummy skills advance NPC/simulation time by one turn and report their effects.

These are development fixtures, not normal progression rewards. They are excluded from
the delivered demo's spell book and normal inputs.

## Milestone map

These are planned, independently observable increments, not completed work or approved
feature PRs. Earlier milestones implement only their stated portions of the final requirements. NFRs apply as their systems appear; the
completed demo must meet all applicable final requirements.

| Milestone | Planned scope and requirement links | Reviewable outcome |
| --- | --- | --- |
| 1 — It's good to move | FR-007, FR-008, FR-010, FR-013, FR-023, FR-044; movement bindings from FR-043. Include fractional movement under FR-011. | Move through a small fixture with blocking objects, fixed NPCs, and wandering NPCs. Observe eight-direction movement, blocked moves without time cost, camera tracking, and NPC movement only after player actions. |
| 2 — Hero emerges | Initial FR-015, FR-016, FR-017, FR-046, FR-048, FR-050. | View starting stats and skills, cast one-turn dummy skills, and gain enough XP to level with chat feedback. The Loop is not implemented yet; a development death trigger can report its invocation until milestone 3 adds the death state. |
| 3 — Fight! | Initial FR-009, FR-014, FR-020 through FR-027, FR-049; kill XP from FR-016. | Engage a neutral or hostile test NPC, observe pursuit/spreading and random melee damage, gain kill XP, and interact with a friendly NPC. Death blocks gameplay input and displays a temporary overlay instead of FR-002. Use a documented melee subset with sourced values; this stage does not claim final formula coverage. |
| 4 — Here we go again... | FR-001 through FR-005, FR-018 for mage/druid, FR-039 through FR-043, first stalker from FR-033 and minimum FR-036 starting-skill training. | Die, restart at level 1 with learned ranks retained, choose druid through the marshal, use retained skills, and save/load a game. Replace the temporary death overlay with the Loop. A minimal free starting-skill trainer fixture provides access to druid skills under FR-005/FR-036. |
| 5 — Always be learning.. | FR-019, FR-028, FR-036 through FR-038; expand FR-015, FR-017, FR-026. | Train a higher rank, loot/equip an item, earn/spend currency, observe combat effects, and verify rank retention after death. |
| 6 — Chillin' at Northshire | FR-029 through FR-032, FR-034, FR-035, FR-047. | Play the populated zone, complete the four objective types, hand in rewards, enter buildings, and reproduce seeded spawns/loot after a Loop. Remaining content is tracked against DATA-004. |
| 7 — Renaissance person | Remaining class coverage in FR-018, FR-036, FR-046. | Select warlock, priest, shaman, and paladin; learn and use their included skills and combine retained skills across Loops. |
| 8 — Final stretch | FR-006, remaining FR-033 escalation, complete FR-030 inventory, FR-045, remaining options/accessibility and all unfinished final requirements. | Complete the Northshire demo, encounter announced reinforcements, and end it by defeating a stalker. Verify all required content against the inventory and the NFR benchmark fixtures. |

The last milestone is a completion check, not permission to postpone missing dependencies.
Targeted skills require FR-024/FR-025 when first introduced. Timed real spells require the
resolved FR-012 timing when they replace one-turn development fixtures. Save failure and
compatibility behavior apply when the save system is introduced; migrations are needed
only when a supported older schema exists.

### Balance acceptance for human playtesting

Evaluate this intended experience with a player familiar with Classic combat, initially unfamiliar
with this seed, then repeating the same game while learning routes and loot:

- Loop 1: the player explores and quests; the stalker is overwhelming when engaged.
- Loop 2: the player discovers class selection and levels more efficiently.
- Loops 3–5: retained skills and buffs make ordinary encounters more manageable.
- Around Loop 10: route/loot knowledge and accumulated skills make defeating the first
  stalker before reinforcements feasible.

These are tuning goals, not hard-coded outcomes or a requirement to force death in Loop 1.
Record seed, route, class choices, learned ranks, arrival times, and Loop of first victory.
An individual player winning earlier or later is not automatically a defect.

## Reference-data implementation tasks

These records supply sourced content before each dependent feature is implemented. They do
not require the owner to provide formulas or reapprove settled behavior. Keep source URLs,
applicable version, selected values, adaptations, and independently checkable examples with
each record. Use Classic Era/Vanilla 1.12 behavior by default, excluding seasonal runes,
expansion changes, and modern balance changes unless explicitly adapted here.

| ID | Required record | First dependency |
| --- | --- | --- |
| DATA-001 | Human-mage base attributes, resources, initial gear/skills, and mage level growth with racial effects removed; exact item/spell IDs and numeric start/reset fixtures. | Milestone 2 stats; milestone 4 full loadout/reset. Reconcile archived racial-inclusive values rather than averaging them. |
| DATA-002 | Classic XP thresholds through 60, solo kill eligibility/level modifiers/rounding and quest XP; combat tables, facing, stat effects, mitigation, regeneration, periodic timing. Record FR-016's beyond-table fallback separately. | Milestone 2 XP and resources; milestone 3 melee; later spells as introduced. |
| DATA-003 | Every included class/rank through learning level 10: source IDs, learning cost/level, prerequisites, effects, mana, cooldown/cast/channel/tick timing, range, targets, stacking, and pet/totem data. List excluded forms, racials, talents, and quest skills with FR-018's summon exceptions. | Minimum starting-skill subset at milestone 4; full trainers at milestone 5; remaining classes at milestone 7. Use FR-010/025 conversions. |
| DATA-004 | Bounded Northshire inventory of NPCs, quests, objects, loot, spawn slots, vendors/items, and trainers; explicit exclusions, quest-gray cutoff table, rewards and boundary fixtures. | First loot/equipment at milestone 5; complete zone/quests at milestone 6 and final coverage at milestone 8. |

## Source and adaptation record

Initial source review: 2026-09-15; targeted follow-up: 2026-09-18. These requirements define
Ostinato's intended behavior. External sources supply inherited mechanics/data and cannot
override explicit adaptations.

Record a version per feature and use the Classic Era/Vanilla baseline above. Modern Classic
database paths can include seasonal content and old comments; archived wiki pages mix
expansions. A URL containing “classic” does not establish that every displayed value is Vanilla.

### REF-001 — Combat baseline

[Wowhead: Blizzard's Classic combat comparison](https://www.wowhead.com/classic/news/not-a-bug-combat-table-values-in-classic-wow-291996)
reports Blizzard's comparison of Classic against its 1.12 reference, including level-dependent
avoidance and attack outcomes. Selected behavior: retain Classic level/stat-sensitive combat
as the reference for FR-026. Adaptation: grid range, player-driven time, unrestricted learned
skills, and no weapon-skill training follow this game's requirements.

The [WoWWiki attack-table page](https://wowwiki-archive.fandom.com/wiki/Attack_table) could not
be retrieved in this review. It is not claimed as read. Full attack-table probabilities,
facing, and effective weapon proficiency are not settled by the accessible article alone.

### REF-002 — Experience

[WoWWiki: XP to level](https://wowwiki-archive.fandom.com/wiki/Formulas:XP_To_Level)
contains a pre-2.3 table alongside expansion-era tables and formulas. Selected reference:
its pre-2.3 level 1–59 thresholds, excluding level 60–70 progression and later XP reductions.
Early acceptance fixtures use 400 XP from level 1 to 2 and 900 from 2 to 3. The complete
relevant data belongs in DATA-002; progression beyond the reference range follows FR-016.

[WoWWiki: mob XP](https://wowwiki-archive.fandom.com/wiki/Formulas:Mob_XP) separates an Azeroth
same-level solo-kill base from expansion formulas. Selected base for an ordinary eligible
same-level solo kill without modifiers: `45 + 5 × player_level` XP. For example, level 1
against level 1 gives 50 XP. Do not copy its mixed-version high-level, group, or rested rules
wholesale. Eligibility, level-difference modifiers, rounding, and quest rewards need DATA-002.
Adaptation: XP is transient and resets every Loop.

### REF-003 — Spell data

[Wowhead Classic: Fireball, spell 133](https://www.wowhead.com/classic/spell=133/fireball)
exposes a mage spell with a level-1 requirement, mana cost, range, casting duration, global
cooldown, and periodic damage. The page's displayed scaling and historical comments are
not a verified complete rank dataset.

Selected behavior: represent such conditions/effects explicitly per rank. Adaptation:
the training level gates learning, not later use, and learned ranks survive Loops.
Convert seconds and yards using FR-010/FR-025; the source page itself does not define that adaptation.

### REF-004 — Northshire content

[Wowhead Classic: A Threat Within](https://www.wowhead.com/classic/quest=783/a-threat-within)
documents an interaction objective involving Marshal McBride.
[Wowhead Classic: Skirmish at Echo Ridge](https://www.wowhead.com/classic/quest=21/skirmish-at-echo-ridge)
documents a kill objective for 12 Kobold Laborers and a return to the marshal.

Selected behavior: include source quest identities, objective targets, and hand-in flow in
the content inventory. Adaptation: the world resets quests, adds the marshal's class choice,
and places the invasion in the 2D setting. These examples do not certify “all Northshire.”
The [Wowhead zone page](https://www.wowhead.com/classic/zone=9/northshire-valley) could not be
retrieved during this review; its contents were not used.

### REF-005 — Starting-stat limitation

[WoWWiki: Mage races](https://wowwiki-archive.fandom.com/wiki/Mage_races) and
[WoWWiki: Human playable race](https://wowwiki-archive.fandom.com/wiki/Human_(playable))
were available through indexed excerpts. They show differing human-mage spirit values and
contain expansion-era context. Direct wiki searches also reported access restrictions.
These mixed-version excerpts do not establish an exact starting tuple. DATA-001 shall verify
the Vanilla human-mage base tuple and growth, remove all racial multipliers under FR-015,
and record explicit start/reset fixtures before stats are implemented.

### REF-006 — Timing and grid adaptation

[Wowhead Classic: Fireball](https://www.wowhead.com/classic/spell=133/fireball) and
[Searing Totem](https://www.wowhead.com/classic/spell=3599/searing-totem) display a
1.5-second GCD, including on an instant totem. Selected game adaptation: one second per
turn and one turn per ordinary GCD, preserving source seconds for other durations.
The 5-yard tile and Chebyshev range conversion are game choices, not a claim about WoW
movement speed. [WoWWiki: Cooldown](https://wowwiki-archive.fandom.com/wiki/Cooldown)
could not be retrieved in the follow-up (access error); its current contents were not used.

### REF-007 — Early pets and totems without class quests

[Wowhead Classic: Summon Imp](https://www.wowhead.com/classic/spell=688/summon-imp),
[Summon Voidwalker](https://www.wowhead.com/classic/spell=697/summon-voidwalker), and
[Searing Totem](https://www.wowhead.com/classic/spell=3599/searing-totem) establish early
summons, with Voidwalker and Searing Totem available at level 10. The
[WoWWiki Summon Imp history](https://wowwiki-archive.fandom.com/wiki/Summon_Imp), available
through indexed text, places removal of its quest requirement in patch 3.3.0, after Vanilla.
[WoWWiki Shaman quests](https://wowwiki-archive.fandom.com/wiki/Shaman_quests) was inaccessible.

Selected adaptation: trainer access replaces the excluded unlock quests for requested
pets/totems, and casting ignores soul shards and elemental totem tools. Other quest-awarded
skills stay excluded. DATA-003 must enumerate original early availability and all included
Earth/Fire ranks, rather than adopting later automatic pet grants or expansion summons.

### REF-008 — Quest difficulty palette

[Blizzard's original game manual](https://bnetcmsus-a.akamaihd.net/cms/template_resource/263A8NGR8HLZ1556919642368.pdf)
describes color-coded quest difficulty including orange and red in its indexed text.
[WoWWiki: Quest](https://wowwiki-archive.fandom.com/wiki/Quest) indexed text distinguishes
gray quest rewards from ordinary difficulty; it mixes later content and is not sufficient
for numeric Vanilla cutoffs. The direct WoWWiki quest-difficulty page was inaccessible.

Selected behavior: use all five Classic colors under FR-035. Numeric gray thresholds remain
a bounded DATA-004 lookup before quest implementation; do not copy later expansion cutoffs
or treat gray quest XP as identical to gray mob XP.
