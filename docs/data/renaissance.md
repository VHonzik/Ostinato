# DATA-003: Renaissance person (milestone 7)

Implements the remaining class coverage in FR-018/036/046, with FR-005/012/013/017,
FR-026/035/041 integration. Adds 59 ranks to the 26 mage/druid ranks documented in
[learning-baseline.md](learning-baseline.md). Training level restricts learning only;
all retained ranks remain usable after death, regardless of class and current level.

## Sources and scope

Numeric authority is the Vanilla 1.12.1 community reconstruction in the
[pinned ClassicDB snapshot](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz).
Read tables: spell_template, spell_chain, spell_bonus_data, npc_trainer_template,
pet_levelstats, creature_template, creature_template_classlevelstats, item_template
and quest_template. Trainer templates are 21 (paladin), 51 (priest), 61 (shaman),
81 (warlock). Rank predecessors come from spell_chain; starting spells and the
FR-018 summon exceptions are added explicitly. This is not Blizzard source code.

Formula references are the matching pinned CMaNGOS implementation:
[Unit.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Unit.cpp),
[StatSystem.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/StatSystem.cpp),
[Pet.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Pet.cpp),
[Creature.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Creature.cpp), and
[UnitAuraProcHandler.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/UnitAuraProcHandler.cpp).

Wowhead Classic was consulted for [Summon Imp](https://www.wowhead.com/classic/spell=688),
[Summon Voidwalker](https://www.wowhead.com/classic/spell=697),
[Stoneskin Totem](https://www.wowhead.com/classic/spell=8071),
[Searing Totem](https://www.wowhead.com/classic/spell=3599), and the
[warlock pet guide](https://www.wowhead.com/classic/guide/wow-classic-warlock-demon-pets).
WoW Wiki [Warlock abilities](https://wowwiki-archive.fandom.com/wiki/Warlock_abilities)
and [Shaman abilities](https://wowwiki-archive.fandom.com/wiki/Shaman_abilities)
were attempted but blocked; their contents were not read.
[Paladin abilities](https://wowwiki-archive.fandom.com/wiki/Paladin_abilities) was
accessible but mixes expansion eras; it is not used for numeric values. Indexed priest
summaries likewise do not override the version-qualified database. No Retail,
seasonal, or expansion ranks are selected.

Exclude racial skills (including priest racials), talents, warrior/rogue/hunter skills,
professions, druid forms/form skills, quest-awarded Redemption, pet abilities first
available above level 10, and all above-10 trainer ranks. Obsolete trainer row 1973
(zzOLDHip Shot III, spell level 99 despite trainer reqlevel zero) is not a class skill.
Imp (level 1), Voidwalker (10), Stoneskin (4) and Searing Totem (10) are taught directly
without unlock quests. Consumable reagents and casting tools are ignored (FR-018).
Drain Soul therefore deals damage without producing a reagent-only soul shard.

## Included ranks

Copper is the training cost; all level-1 starts are free. Each rank above 1 requires
its preceding included rank. Mana is fixed unless shown as a percent of base mage mana
(before intellect/equipment). Range is already converted at five yards per tile;
source GCD instants use one turn, sourced off-GCD Judgement uses zero. Durations and
cooldowns use simulation seconds/turns. Fractional casts retain FR-012 credit.
ClassSkillData.RANKS also stores school, scaling cap/rate and direct/periodic coefficients.

### Warlock

| Spell (source ID) | Rank | Learn / copper | Mana | Cast / range | Duration / cooldown | Effect |
| --- | ---: | --- | --- | --- | --- | --- |
| Immolate (348) | 1 | 1 / 0 | 25 | 2s / 6 | 15 / 0 | damage 8–8; 4 per 3s |
| Shadow Bolt (686) | 1 | 1 / 0 | 25 | 1.7s / 6 | 0 / 0 | damage 12–16 |
| Demon Skin (687) | 1 | 1 / 0 | 50 | 1s / 0 | 1800 / 0 | Armor and +3 / +5 health every 5 turns, including combat. |
| Summon Imp (688) | 1 | 1 / 0 | 80% | 10s / 0 | 0 / 0 | Summon one Imp on a free adjacent tile. Firebolt ranks at pet levels 1/8; Blood Pact at 4. Replaces your pet only on success. |
| Corruption (172) | 1 | 4 / 100 | 35 | 2s / 6 | 12 / 0 | damage 0–0; 10 per 3s |
| Curse of Weakness (702) | 1 | 4 / 100 | 20 | 1s / 6 | 120 / 0 | Reduces physical damage by 3 for 120 turns. One warlock curse per target. |
| Shadow Bolt (695) | 2 | 6 / 100 | 40 | 2.2s / 6 | 0 / 0 | damage 23–29 |
| Life Tap (1454) | 1 | 6 / 100 | 0 | 1s / 0 | 0 / 0 | Converts health to mana; cannot consume your last health point. |
| Curse of Agony (980) | 1 | 8 / 200 | 25 | 1s / 6 | 24 / 0 | 84 shadow damage over 24 turns, rising from half to normal to 1.5x ticks. One curse per target.; 7 per 2s |
| Fear (5782) | 1 | 8 / 200 | 15% | 1.5s / 4 | 10 / 0 | One feared enemy flees through legal tiles for up to 10 turns; damage can break fear. |
| Demon Skin (696) | 2 | 10 / 300 | 120 | 1s / 0 | 1800 / 0 | Armor and +3 / +5 health every 5 turns, including combat. |
| Summon Voidwalker (697) | 1 | 10 / 300 | 100% | 10s / 0 | 0 / 0 | Summon one Voidwalker on a free adjacent tile. Torment at pet level 10. Reagents ignored. |
| Immolate (707) | 2 | 10 / 300 | 45 | 2s / 6 | 15 / 0 | damage 19–19; 8 per 3s |
| Drain Soul (1120) | 1 | 10 / 300 | 55 | 15s / 6 | 15 / 0 | Five damage ticks, one every 3 turns. Mana charged once at start; cancellation preserves delivered ticks. |
| Create Healthstone (Minor) (6201) | 1 | 10 / 300 | 95 | 3s / 0 | 0 / 0 | Creates one unique Minor Healthstone, restoring 100 health when used. Reagents ignored. |

### Priest

| Spell (source ID) | Rank | Learn / copper | Mana | Cast / range | Duration / cooldown | Effect |
| --- | ---: | --- | --- | --- | --- | --- |
| Smite (585) | 1 | 1 / 0 | 20 | 1.5s / 6 | 0 / 0 | damage 13–17 |
| Power Word: Fortitude (1243) | 1 | 1 / 0 | 60 | 1s / 6 | 1800 / 0 | +3 stamina for 1800 turns. |
| Lesser Heal (2050) | 1 | 1 / 0 | 30 | 1.5s / 8 | 0 / 0 | heal 46–56 |
| Shadow Word: Pain (589) | 1 | 4 / 100 | 25 | 1s / 6 | 18 / 0 | damage 0–0; 5 per 3s |
| Lesser Heal (2052) | 2 | 4 / 100 | 45 | 2s / 8 | 0 / 0 | heal 71–85 |
| Power Word: Shield (17) | 1 | 6 / 100 | 45 | 1s / 8 | 30 / 4 | Absorbs 44 damage for 30 turns; applies 15-turn Weakened Soul. |
| Smite (591) | 2 | 6 / 100 | 30 | 2s / 6 | 0 / 0 | damage 25–31 |
| Renew (139) | 1 | 8 / 200 | 30 | 1s / 8 | 15 / 0 | heal over time 9–9; 9 per 3s |
| Fade (586) | 1 | 8 / 200 | 40 | 1s / 0 | 10 / 30 | Temporarily reduces your threat by 55 for 10 turns; other engaged allies can take aggro. |
| Shadow Word: Pain (594) | 2 | 10 / 300 | 50 | 1s / 6 | 18 / 0 | damage 0–0; 11 per 3s |
| Resurrection (2006) | 1 | 10 / 300 | 75% | 10s / 6 | 0 / 0 | Out of combat: revive an ordinary friendly NPC at its unoccupied corpse with 70 health. Cannot revive the story guard or summons. |
| Lesser Heal (2053) | 3 | 10 / 300 | 75 | 2.5s / 8 | 0 / 0 | heal 135–157 |
| Mind Blast (8092) | 1 | 10 / 300 | 50 | 1.5s / 6 | 0 / 8 | damage 39–43 |

### Shaman

| Spell (source ID) | Rank | Learn / copper | Mana | Cast / range | Duration / cooldown | Effect |
| --- | ---: | --- | --- | --- | --- | --- |
| Healing Wave (331) | 1 | 1 / 0 | 25 | 1.5s / 8 | 0 / 0 | heal 34–44 |
| Lightning Bolt (403) | 1 | 1 / 0 | 15 | 1.5s / 6 | 0 / 0 | damage 13–15 |
| Rockbiter Weapon (8017) | 1 | 1 / 0 | 15 | 1s / 0 | 300 / 0 | Main-hand enchant: +2 / +4 damage per second for 300 turns. One weapon enchant. |
| Earth Shock (8042) | 1 | 4 / 100 | 30 | 1s / 4 | 2 / 6 | Nature damage and a 2-turn school interrupt; shares Shock cooldown. |
| Stoneskin Totem (8071) | 1 | 4 / 100 | 30 | 1s / 0 | 120 / 0 | Earth: 5 health, 120 turns, 4-tile aura reducing melee damage by 4. |
| Healing Wave (332) | 2 | 6 / 100 | 45 | 2s / 8 | 0 / 0 | heal 64–78 |
| Earthbind Totem (2484) | 1 | 6 / 100 | 6% | 1s / 0 | 45 / 15 | Earth: 5 health, 45 turns, slows enemies 50% within 2 tiles. |
| Lightning Shield (324) | 1 | 8 / 100 | 45 | 1s / 0 | 600 / 0 | Three 13-nature-damage charges over 600 turns; at most one discharge per 3 turns. |
| Lightning Bolt (529) | 2 | 8 / 100 | 30 | 2s / 6 | 0 / 0 | damage 26–30 |
| Stoneclaw Totem (5730) | 1 | 8 / 100 | 15 | 1s / 0 | 15 / 30 | Earth: 50 health, 15 turns; attracts enemies within 1 tile. 30-turn cooldown. |
| Rockbiter Weapon (8018) | 2 | 8 / 100 | 25 | 1s / 0 | 300 / 0 | Main-hand enchant: +2 / +4 damage per second for 300 turns. One weapon enchant. |
| Earth Shock (8044) | 2 | 8 / 100 | 50 | 1s / 4 | 2 / 6 | Nature damage and a 2-turn school interrupt; shares Shock cooldown. |
| Searing Totem (3599) | 1 | 10 / 400 | 25 | 1s / 0 | 30 / 0 | Fire: 5 health, 30 turns; fires for 9–11 damage every 2.2 seconds within 4 tiles. |
| Flametongue Weapon (8024) | 1 | 10 / 400 | 30 | 1s / 0 | 300 / 0 | Main-hand enchant: fire damage proportional to weapon speed on landed hits for 300 turns. |
| Flame Shock (8050) | 1 | 10 / 400 | 55 | 1s / 4 | 12 / 6 | Fire damage and a 12-turn burn; shares Shock cooldown.; 7 per 3s |
| Strength of Earth Totem (8075) | 1 | 10 / 400 | 25 | 1s / 0 | 120 / 0 | Earth: 5 health, 120 turns; +10 strength within 4 tiles. |

### Paladin

| Spell (source ID) | Rank | Learn / copper | Mana | Cast / range | Duration / cooldown | Effect |
| --- | ---: | --- | --- | --- | --- | --- |
| Devotion Aura (465) | 1 | 1 / 0 | 0 | 1s / 0 | 0 / 0 | Toggle a 6-tile party armor aura; one aura at a time. Costs one turn. |
| Holy Light (635) | 1 | 1 / 0 | 35 | 2.5s / 8 | 0 / 0 | heal 39–47 |
| Seal of Righteousness (21084) | 1 | 1 / 0 | 20 | 1s / 0 | 30 / 0 | Adds holy damage on landed melee hits for 30 turns. Judgement consumes the seal. |
| Blessing of Might (19740) | 1 | 4 / 100 | 20 | 1s / 6 | 300 / 0 | Adds 20 attack power for 300 turns; one blessing per target. |
| Judgement (20271) | 1 | 4 / 100 | 6% | 1s / 2 | 0 / 10 | Consume the active seal to judge an enemy. No GCD or turn cost; 10-turn cooldown. |
| Divine Protection (498) | 1 | 6 / 100 | 15 | 1s / 0 | 6 / 300 | Physical immunity for 6 turns; prevents melee. Applies 60-turn Forbearance. |
| Holy Light (639) | 2 | 6 / 100 | 60 | 2.5s / 8 | 0 / 0 | heal 76–90 |
| Seal of the Crusader (21082) | 1 | 6 / 100 | 25 | 1s / 0 | 30 / 0 | Attack power and 40% faster swings with reduced weapon damage. Judgement increases holy damage taken. |
| Hammer of Justice (853) | 1 | 8 / 100 | 30 | 1s / 2 | 3 / 60 | stun 0–0 |
| Purify (1152) | 1 | 8 / 100 | 8% | 1s / 6 | 0 / 0 | Removes one poison and one disease from the selected ally. |
| Parry (3127) | 1 | 8 / 100 | 0 | 1s / 0 | 0 / 0 | Passive: 5% frontal parry, retained across classes and Loops. |
| Lay on Hands (633) | 1 | 10 / 300 | 0 | 1s / 8 | 0 / 3600 | Heals for your maximum health; spends all current mana. 3600-turn cooldown. |
| Blessing of Protection (1022) | 1 | 10 / 300 | 25 | 1s / 6 | 6 / 300 | Physical immunity for 6 turns; prevents melee. Applies 60-turn Forbearance. |
| Devotion Aura (10290) | 2 | 10 / 300 | 0 | 1s / 0 | 0 / 0 | Toggle a 6-tile party armor aura; one aura at a time. Costs one turn. |
| Seal of Righteousness (20287) | 2 | 10 / 300 | 40 | 1s / 0 | 30 / 0 | Adds holy damage on landed melee hits for 30 turns. Judgement consumes the seal. |

## Effects and stacking

Direct damage/healing uses the existing spell hit, critical and resistance rules.
The database coefficient applies its below-level-20 penalty at the rank's learning
level: `1 - (20 - learning level) × 0.0375`. Family coefficient fallback uses the
first rank when a later rank has no own row. Life Tap uses its explicit 0.8 coefficient
without that penalty. Level scaling stops at each source rank's cap; retained ranks
below learning level never receive negative scaling. Independent fixture: level-1
Shadow Bolt rank 1 with 100 spell power has minimum 36 (12 + floor(100 × .857143 × .2875)).

- Warlock curses are exclusive per target. Agony's 12 two-second ticks use four half,
  four normal, four 1.5-strength ticks; cumulative rounding preserves the base total
  84. Fear affects one enemy for up to 10 turns; it chooses a clear adjacent tile
  farther from the player in stable direction order. Damage uses the existing
  controlled break roll (damage / 50, capped naturally at certainty); this discrete flee behavior is the grid adaptation.
  Demon Skin grants 40/120 armor and 3/5 health per five turns, including combat.
  Life Tap cannot kill the caster. Drain Soul channels five ticks at three-second
  intervals; mana is charged once at the first committed boundary, not first damage.
- Priest Fortitude gives 3 stamina for 1,800 turns. Shield absorbs 44 plus its
  low-rank healing coefficient for 30 turns and applies 15-turn Weakened Soul;
  absorption occurs after mitigation. Fade temporarily subtracts 55 player threat
  for 10 turns without disengaging combat. Resurrection is adapted to ordinary
  friendly corpses (70 HP, capped to their maximum), out of combat and on a clear
  tile. It cannot resurrect the player, a summon or the story guard.
- Shaman shocks share the six-second family cooldown. Rockbiter adds 2/4 weapon DPS;
  Flametongue uses source speed scaling `(3.26 + .19 × capped levels above 10) × speed`
  plus the low-rank coefficient, with normal fire resistance. Weapon enchants are
  mutually exclusive and bound to the enchanted item ID. Lightning Shield has three
  charges for 13 nature damage, a three-second proc interval and 600-turn duration.
- Paladin Devotion Aura toggles and gives 55/160 armor indefinitely; one activation
  costs a turn. Blessings are exclusive per recipient, seals per player. Might gives
  20 attack power. Divine/Blessing Protection prevents physical damage and melee
  attacks for six turns, with 60-turn Forbearance; harmful spells remain usable.
  Purify removes one poison and one disease where present. Parry is a retained
  passive adding the source 5% chance. Lay on Hands heals the caster's maximum HP,
  spends all current mana, and has a 3,600-turn cooldown.
- Judgement costs 6% base mana, consumes the active seal even on resist, has a
  ten-turn cooldown and no GCD/turn/credit effect (`StartRecoveryTime = 0`).
  Righteousness uses the pinned proc formula, weapon speed and handedness, plus
  low-rank holy scaling; its judgement starts at 15/25 damage. Crusader adds 31 AP,
  40% swing speed with corresponding physical-damage reduction; its judgement adds
  20 holy spell power against that target for ten turns, refreshed by melee.
- Minor Healthstone (5512) is unique in the bag, restores 100 HP, takes one use turn
  and has a 120-turn cooldown separate from potion cooldowns. Failed creation with
  a full bag or existing stone preserves mana and inventory under FR-012.

## Pets and totems

SummonRules is a stateless helper over GridWorld's existing GridActor array. A separate
actor hierarchy would duplicate occupancy, ordering, targeting and serialization.
ClassSpellEffects similarly isolates the four classes' concrete effect branches while
SpellEffects retains shared damage/healing/ticks. These helpers keep the turn scheduler
readable without adding managers or an extensible ability framework.

One pet, one Earth totem and one Fire totem may coexist. Summons append to stable actor
order; they act only in committed player turns, including casting/channel boundaries.
A summon uses the first free adjacent tile in GridWorld.DIRECTIONS. A replacement
Earth/Fire totem can reuse its adjacent predecessor's tile. A failed placement never
removes the old summon. Expiry removes a totem before NPC target/occupancy decisions at
that boundary. Death/dismissal removes living occupancy and aura contribution, leaves
no corpse or loot, and does not unlearn anything. Summon kills credit player XP/quests
once through the ordinary death path. Summons do not occupy population spawn slots.

**Pets:** Imp entry 416 and Voidwalker 1860 use pet_levelstats at the owner's current
level, including the sourced base HP/mana/armor/attributes through 60. Above 60, repeat
the final numeric row while keeping current combat level (explicit uncapped-game
adaptation). No owner-stat inheritance is added. Armor adds twice pet agility;
attack power is strength−10 for Imp and 2×strength−20 for Voidwalker. Base weapon
minimum comes from class-level damage plus `floor(base AP / 14) × 2`, multiplied by
1.3 (Imp) or 1 (Voidwalker); maximum is 1.5× minimum. The ordinary two-second melee
calculation then applies pet attack power. Added stamina uses the pinned Pet formula:
one HP per point through 20, ten thereafter; added intellect uses
`max(0, (added intellect−20)×15+20)` mana. This differs from player growth.
Level-10 Voidwalker fixture: 260 HP, 744 armor, 38 AP, weapon range 7.9604–11.9406.
Level-10 Imp with its own Blood Pact: 225 HP, 200 armor, 19 AP.

Pet abilities through learning level 10 activate automatically at their original pet
level, replacing grimoire purchase UI in this single-player adaptation: Imp Firebolt
rank 1 at 1, rank 2 at 8; Blood Pact rank 1 at 4; Voidwalker Torment rank 1 at 10.
No later ranks are granted. Firebolt casts for two seconds at range six tiles, costs
10/20 mana, and deals 6–8/12–14 fire damage plus capped source level scaling. Blood
Pact adds 2 stamina (scaling to 3 at 14) within six tiles, including the Imp itself.
Voidwalker melees and uses Torment for 20 mana every five turns: 45 threat plus two
per level above 10, capped at 15. Pet spell damage uses level-based hit/resistance.

Attack, Stop/Follow and Dismiss commands appear in the Warlock spell-book tab after a
summon is learned. Commands are free; Attack requires a living nonfriendly target in
sight. Pets path through ordinary clear tiles, follow when idle, and stop casting if
the commanded target disappears or loses sight. Stop/Follow clears the target and
unfinished Firebolt. Commands cannot advance actors or random streams by themselves.
Mana regeneration checks every four turns after five seconds without spending:
`sqrt(intellect) × (spirit/4+12.5) × .4` for Imp,
`sqrt(intellect) × (spirit/5+15) × .4` for Voidwalker. Out-of-combat HP per four turns
is `(spirit×.11+1)×4` / `spirit×.25×4`, rounded down and capped.

**Totems:** stationary, 5 HP except Stoneclaw's 50. Stoneskin (120 turns, radius four)
reduces physical damage by 4. Strength of Earth (120 turns, radius four) adds 10 strength.
Earthbind (45 turns, radius two) slows hostile movement 50%. Stoneclaw (15 turns,
radius one) adds 22 threat every two seconds. Searing (30 turns, range four) attacks
the nearest visible hostile in stable order for 9–11 fire damage every 2.2 seconds,
retaining the fractional firing deadline. Aura range uses tile distance; offensive
selection also checks line of sight. Buffs reach the player and active pet.

Threat is the current single-player adaptation: damage adds its amount, effective healing splits
half its amount across engaged enemies, and they attack the highest valid threat among
player and living summons (ties retain player/array order). It omits multiplayer
110%/130% switching hysteresis. Fade and Torment adjust this same threat state;
combat and save restrictions remain active while any enemy is engaged.

## Class services, outfits and persistence

Class selection remains once per Loop from Loop 2, at level 1 before accepting any
quest. It grants no skills or stat growth changes. All classes retain the sourced
human-mage baseline under FR-005. New starter item IDs are recorded in ClassItems;
shaman uses the Vanilla orc starter outfit without racial stats. Acquired equipment
is preserved; replacement outfit pieces go into inventory if occupied, and insufficient
space rejects the whole exchange. Distinct existing-sheet sprites identify all six classes.

Trainers: Drusilla (29,18), Anetta (23,9), Sammuel (16,10), added shaman (12,17),
Khelden (17,8), added druid (12,15). Marshal referrals 3105/3103/3101 use source letters
9576/9548/9570, prerequisite 7, and 40 XP. The shaman counterpart likewise follows
quest 7 and gives 40 XP but requires no invented source letter. See
[northshire.md](northshire.md) for remaining M8 content.

Demo save revision **4** adds all summon state, cast/ability deadlines, pet mana,
threat, shields, control/debuff timers, aura contributions and healthstone cooldown.
Restoration validates the separate world and recomputes derived aura/pet stats before
restoring current resources. Stable actor indexes and both RNG streams preserve
continuation. Revisions 1–3 remain untouched and incompatible; no migration is claimed.
Loop death clears summons/effects/cooldowns/items and retains all learned ranks,
including passive Parry. Class selection and stat refresh do not grant extra ranks.
