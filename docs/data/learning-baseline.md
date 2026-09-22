# Milestone 5: learning, items, and combat data

This record extends DATA-002/003 and supplies DATA-004 for the runnable training grounds.
Scope: FR-019, FR-028, FR-036–038; the equipment/stat and spell expansion of FR-015,
FR-017 and FR-026; timing remains FR-010/012/013. Other classes arrive in milestone 7.
Northshire populations, quests and replenishment belong to milestone 6.

## Sources and version

The numeric baseline is Vanilla 1.12.1, matching the previous source records:

- [ClassicDB, pinned database](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz):
  `spell_template`, `spell_chain`, `npc_trainer_template` (mage 71, druid 91),
  `item_template`, `npc_vendor`, and `creature_loot_template`.
- [CMaNGOS Classic, pinned implementation](https://github.com/cmangos/mangos-classic/tree/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f):
  `src/game/Entities/Unit.cpp` (resistance distribution and spell hit),
  `src/game/Spells/SpellAuras.cpp` (Polymorph regeneration), and
  `src/game/Spells/UnitAuraProcHandler.cpp` (damage breaking roots).
  These are community reconstructions, not Blizzard source code.
- Wowhead Classic spell pages were checked for Fireball 143, Frostbolt 116/205,
  Arcane Missiles 5143, Entangling Roots 339, Healing Touch 5185/5186,
  Wrath 5177, Rejuvenation 774/1058, Frost Nova 122, Moonfire 8921/8924,
  Fire Blast 2136, and Polymorph 118. The linked spell IDs below identify the records.
  Base damage uses database rank/level scaling rather than the site's level-60 display.
- WoW Wiki pages for Resistance, Spell power coefficient, Mage abilities, Root and
  Polymorph were attempted but blocked by the site (robots/access errors). They were
  not read. Wowhead plus the pinned Vanilla reconstruction provide the usable evidence;
  no Retail, expansion, or seasonal behavior is selected.

## DATA-003: complete included mage/druid trainer ranks through level 10

Costs are whole copper. Rank 2 requires its rank 1. FR-005 makes all level-1 ranks free;
the new mage still starts with only Fireball and Frost Armor. Selected class and training
level restrict learning, never use of an already learned rank. A successful training
transaction costs no turn and charges once. Each rank remains separately selectable.

The table lists base values; `TrainerData.RANKS` also records school, level scaling,
range, duration, cooldown, direct/periodic coefficients and family. Seconds convert to
simulation turns, ranges to five-yard tiles. Instant casts use one turn under FR-012.

| Class / rank | Source | Level | Copper | Mana | Cast seconds | Base effect |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Mage: Fireball 1 | [133](https://www.wowhead.com/classic/spell=133) | 1 | 0 | 30 | 1.5 | damage 14–22; 1/2s for 4s |
| Mage: Frost Armor 1 | [168](https://www.wowhead.com/classic/spell=168) | 1 | 0 | 60 | 1.0 | armor 30 |
| Mage: Arcane Intellect 1 | [1459](https://www.wowhead.com/classic/spell=1459) | 1 | 0 | 60 | 1.0 | armor 2 |
| Mage: Frostbolt 1 | [116](https://www.wowhead.com/classic/spell=116) | 4 | 100 | 25 | 1.5 | damage 18–20 |
| Mage: Conjure Water 1 | [5504](https://www.wowhead.com/classic/spell=5504) | 4 | 100 | 60 | 3.0 | conjure |
| Mage: Fireball 2 | [143](https://www.wowhead.com/classic/spell=143) | 6 | 100 | 45 | 2.0 | damage 31–45; 1/2s for 6s |
| Mage: Conjure Food 1 | [587](https://www.wowhead.com/classic/spell=587) | 6 | 100 | 60 | 3.0 | conjure |
| Mage: Fire Blast 1 | [2136](https://www.wowhead.com/classic/spell=2136) | 6 | 100 | 40 | 1.0 | damage 24–32 |
| Mage: Frostbolt 2 | [205](https://www.wowhead.com/classic/spell=205) | 8 | 200 | 35 | 1.8 | damage 31–35 |
| Mage: Polymorph 1 | [118](https://www.wowhead.com/classic/spell=118) | 8 | 200 | 60 | 1.5 | polymorph |
| Mage: Arcane Missiles 1 | [5143](https://www.wowhead.com/classic/spell=5143) | 8 | 200 | 85 | 3.0 | channel 24 |
| Mage: Frost Armor 2 | [7300](https://www.wowhead.com/classic/spell=7300) | 10 | 400 | 110 | 1.0 | armor 110 |
| Mage: Frost Nova 1 | [122](https://www.wowhead.com/classic/spell=122) | 10 | 400 | 55 | 1.0 | nova 19–21 |
| Mage: Conjure Water 2 | [5505](https://www.wowhead.com/classic/spell=5505) | 10 | 400 | 105 | 3.0 | conjure |
| Druid: Wrath 1 | [5176](https://www.wowhead.com/classic/spell=5176) | 1 | 0 | 20 | 1.5 | damage 12–14 |
| Druid: Healing Touch 1 | [5185](https://www.wowhead.com/classic/spell=5185) | 1 | 0 | 25 | 1.5 | heal 37–51 |
| Druid: Mark of the Wild 1 | [1126](https://www.wowhead.com/classic/spell=1126) | 1 | 0 | 20 | 1.0 | armor 25 |
| Druid: Rejuvenation 1 | [774](https://www.wowhead.com/classic/spell=774) | 4 | 100 | 25 | 1.0 | heal over time; 8/3s for 12s |
| Druid: Moonfire 1 | [8921](https://www.wowhead.com/classic/spell=8921) | 4 | 100 | 25 | 1.0 | damage 7–9; 4/3s for 9s |
| Druid: Thorns 1 | [467](https://www.wowhead.com/classic/spell=467) | 6 | 100 | 35 | 1.0 | armor 3 |
| Druid: Wrath 2 | [5177](https://www.wowhead.com/classic/spell=5177) | 6 | 100 | 35 | 1.7 | damage 25–29 |
| Druid: Entangling Roots 1 | [339](https://www.wowhead.com/classic/spell=339) | 8 | 200 | 50 | 1.5 | root; 5/3s for 12s |
| Druid: Healing Touch 2 | [5186](https://www.wowhead.com/classic/spell=5186) | 8 | 200 | 55 | 2.0 | heal 88–112 |
| Druid: Rejuvenation 2 | [1058](https://www.wowhead.com/classic/spell=1058) | 10 | 300 | 40 | 1.0 | heal over time; 14/3s for 12s |
| Druid: Mark of the Wild 2 | [5232](https://www.wowhead.com/classic/spell=5232) | 10 | 300 | 50 | 1.0 | armor 65 |
| Druid: Moonfire 2 | [8924](https://www.wowhead.com/classic/spell=8924) | 10 | 300 | 50 | 1.0 | damage 13–17; 8/3s for 12s |

Excluded: druid forms and form-dependent abilities (Bear Form, Maul, Growl and
Demoralizing Roar), Cure Poison's class-quest reward, racial/talent skills, and weapon
proficiency buttons. FR-018 excludes these forms/quest rewards; FR-019 removes the
proficiency grind. There are 14 mage and 12 druid ranks, with no ranks above learning level 10.

### Effects and arithmetic

- Direct values roll the inclusive base range, add truncated per-level growth through
  the rank's scaling cap, and add `floor(power * coefficient)`. Healing uses healing
  power; damage uses spell power. Direct crits multiply by 1.5, truncating once.
  Mage-baseline crit is `3.7 + intellect / (14.77 + 0.65 * min(level, 60))` percent,
  plus bonus spell crit, consistent with the race/class-independent player baseline.
- Selected direct coefficients: Fireball .123/.271, Frostbolt .163/.269,
  Fire Blast .204, Nova .018, Wrath .123/.231, Healing Touch .123/.314,
  Moonfire .060/.094, and Arcane Missiles .157 per missile. Periodic coefficients:
  Rejuvenation .080/.125, Moonfire .052/.081, Roots .033; Fireball's residual burn has none.
  For example, 100 spell power adds 27 direct damage to Fireball 2;
  100 healing power adds 31 healing to Healing Touch 2 before crit.
- Hit begins at 96% against equal level, subtracts one point per level difference
  through +2 and eleven points per additional level; spell hit then applies.
  Clamp final hit to 1–99%. Resistance uses `75 * R / max(100, 5 * caster_level)`,
  capped at 75%; nonbinary spells add .4 per positive defense-skill difference.
  Frostbolt, Roots and Polymorph are binary: the resistance percentage reduces hit.
  Other spells use the pinned five-column resistance distribution, interpolating
  between integer percentages: full resist enters the hit roll, then conditional
  partial mitigation selects 0/25/50/75%. This selects Classic quarter-damage buckets.
- Armor buffs of different families stack. Recasting the same family replaces its
  previous rank; a weaker active armor or healing-over-time rank cannot be overwritten.
  Rejuvenation and damage-over-time families refresh their own target's schedule;
  distinct families coexist. Periodic amounts snapshot power and do not crit.
- Frostbolt slows movement 40%; Frost Armor chills attackers for five turns (30%
  movement and longer swing delay). Roots prevent movement but allow adjacent attacks.
  External direct damage breaks a root with chance `damage / threshold`, where
  threshold is 50 through target level 8, otherwise `25 * level - 150`.
  Its own periodic damage does not break the root. Roots require an outdoor player tile.
- Polymorph controls one beast, humanoid or critter, suppresses attacks and wanders
  through legal neighbors unless also rooted. It heals 10% maximum health per second
  after application; any positive damage breaks it. NPC primary stats irrelevant to
  their actions are omitted, as FR-026 permits. Nova roots enemies in a visible
  two-tile radius; it never hits friendlies.
- Arcane Missiles delivers three one-second ticks. The first tick charges the full
  mana cost once; later cancellation or target failure retains delivered damage/cost
  and adds no casting credit. Ordinary casts retain FR-012's completion revalidation.
  Haste divides cast and melee duration, clamped to at least one turn for ordinary casts.
- Conjuring produces `clamp(2 + 2*(level - training_level), 2, 20)` items and checks
  capacity again at completion. Failed completion gives no items, cost or new credit.
  Fire Blast/Nova cooldowns are 8/25 turns; ranks share their family cooldown.

The existing turn-based cast rules remain authoritative. Experimental emulator heartbeat
resists are not selected: the pinned source explicitly calls its approximation unverified.
The implemented control durations end at their stated boundary or documented damage break.
No player spell pushback is added to FR-012's fixed completion-credit calculation.

## DATA-004: items, loot and trade

`ItemData.ITEMS` preserves source IDs, level, stack limits, armor, primary attributes,
weapon damage/speed, shield block, slot, prices and consumable values. No durability,
race/class armor gates, weapon proficiency grind or dual wield is added (FR-019).
Weapon/defense skill remain five times current level. Shield block chance is 5%; block
value adds `max(0, floor(strength/20)-1)` to the shield value, after armor mitigation.
Player rear attacks cannot dodge, parry or block. Item changes recompute maxima without
refilling resources; removal clamps current values to the smaller maxima.

| Source IDs | Included purpose |
| --- | --- |
| 35, 55, 56, 1395, 6096, 6123, 6124 | Granted mage/druid outfits; retained provenance for class exchange |
| 2139, 2129, 85 | Dirk, Large Round Shield, Dirty Leather Vest |
| 2572, 6527 | Red Linen Robe (+1 intellect), Ancestral Robe (+2 intellect, +1 stamina) |
| 4560, 2950 | Fine Scimitar, Icicle Rod |
| 117, 159 | Tough Jerky and Refreshing Spring Water |
| 118, 2455 | Minor Healing/Mana Potions |
| 5349, 5350, 2288 | Conjured Muffin, Water and Fresh Water; cannot be sold |
| 7073, 7074, 4865 | Broken Fang, Chipped Claw and Ruined Pelt |
| 750 | Quest-only Tough Wolf Meat; cannot be sold |

Food restores 61 health over 18 turns; ordinary water 151 mana over 18 turns;
Fresh Water 436 mana over 21 turns. To preserve exact totals on integer boundaries,
each elapsed second restores the difference between successive truncated cumulative
fractions. Use costs one turn; restoration begins after that completion boundary.
Food and water can coexist. Movement, another committed action, or combat interrupts
restoration; wait advances it. Potions restore inclusive 70–90 health / 140–180 mana
and share a 120-turn cooldown. Mana potions require level 5. Rejected uses are free.

Loot RNG is private per source: game seed XOR stable spawn-ID hash XOR 32452843.
It never consumes the combat or wandering RNG stream. Assigned contents and remaining
money/items are saved. Death assigns NPC loot; first opening assigns chest loot.
Quest eligibility is captured at assignment and rechecked at collection without rerolls.
The `wolves` eligibility set is an integration point tested here; a playable quest
accept/hand-in/abandon lifecycle belongs to milestone 6.

Young Wolf (69) / Timber Wolf (299) use the three source junk rows, respectively
38.3399/38.3736/39.122% and 37.8937/37.7572/36.9481%, each quantity 1–2.
Tough Wolf Meat rolls 80%, independently of whether currently eligible.
The later zone's rare world-drop/reference tables are outside this fixture subset.

The **Training supplies** chest at (19,19) is an explicit development fixture table:
350–450 copper, one seeded Fine Scimitar or Dirk, a leather vest, two healing potions,
and a Red Linen Robe. This provides runnable equipment/training QA before Northshire
and its final chest tables. It never replenishes during a Loop.

The **Trader** at (16,18) combines source vendor rows for a small development service:
Dirk (vendor 945), shield (1104), leather vest (2113), jerky (1464), spring water
(unlimited vendor row), and three mana potions (958). Source `BuyPrice / BuyCount`
gives per-unit price: 57/77/62/5/5/40 copper. Source sell prices are preserved.
All stock is unlimited except the three mana potions. FR-038 intentionally replaces
source timed replenishment with no replenishment until the next Loop. Reputation
adjustments and buyback are not part of this fixture. Buying/selling quantities is atomic.

Forty fixed bag slots support stack merge, split, move, swap, use, equip and unequip.
Two-handed swaps must fit both displaced items before committing; no partial changes.
A full bag leaves offered loot untouched. Looting, rearranging, training and trading
are free; successful equip/unequip/consume spends one full shared turn (FR-010).
Death during that turn closes the old service menu and adopts the next Loop.

## Persistence and implementation shape

Saves now use **demo revision 2**. Revision-1 files are reported incompatible and left
unchanged; there is no migration. Revision 2 stores equipment, inventory placement,
money, vendor stock, assigned/remaining loot, effect schedules and cooldowns. Restore
recomputes gear/buff-dependent resource limits before accepting saved resources.
Death preserves learned ranks/hotbar and resets all item/currency/effect/stock state.

`InventoryRules` centralizes atomic copy-then-commit operations shared by loot, trade,
gear and conjuring. Duplicating them in menu handlers would make rollback inconsistent.
`SpellEffects` holds concrete spell effects separately from `GridWorld`'s turn scheduler;
putting all rank behaviors inline obscured completion/cancellation ordering. Both are
ordinary stateless helpers, with no manager, registry framework or extra inheritance.
`SpellResistance` isolates the numeric table and calculations for controlled-roll tests.
