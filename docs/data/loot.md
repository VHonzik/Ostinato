# DATA-004: Ordinary loot and treasure (M8-E)

Implements FR-027/028/029/030/034/037, FR-002/041 and NFR-013.
Source audit: 2026-10-10. This completes loot for the currently resolved Northshire
population inventory; it does not claim M8-F's remaining world audit or human acceptance.

## Sources and scope

Numeric data use the same [ClassicDB Vanilla 1.12.1 snapshot](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz)
as earlier DATA-004 records. This is a community reconstruction, not Blizzard source code.
The gzip SHA-256 is `4f92db520868ab4e566726f68b5b2e380ae781209beaf22237b4f7f04600d0c0`.
Read `creature_loot_template`, `reference_loot_template`, `gameobject_loot_template`,
`gameobject_template`, `gameobject`, `pool_gameobject`, `pool_template`, `pool_pool`,
`creature_template`, and `item_template`.

[Wowhead Classic Battered Chest 2843](https://www.wowhead.com/classic/object=2843/battered-chest)
corroborates an Elwynn chest, and [Defias Thug 38](https://www.wowhead.com/classic/npc=38/defias-thug)
corroborates the creature. Retrieved pages did not expose complete loot tables; their
comments are not numeric evidence. [WoWWiki Battered Chest](https://wowwiki-archive.fandom.com/wiki/Battered_Chest)
and [Northshire Valley](https://wowwiki-archive.fandom.com/wiki/Northshire_Valley)
were inaccessible in this audit; their contents were not used.

The pinned [CMaNGOS LootMgr.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Loot/LootMgr.cpp)
supplies the interpretation of independent rows, exclusive probability groups,
reference traversal and count ranges. Use baseline rates without server multipliers.
Ostinato selects fixed item order instead of shuffling; for these disjoint groups
this preserves the source probabilities while defining reproducible seeded outcomes.

All 71 rows for creatures 6/38/69/80/103/257/299 and objects 2843/161557 are included
below, including rare ordinary materials and fixed-stat uncommon equipment. Neither
low chance nor lack of a profession removes an ordinary drop. The reference closure
is exactly 60000 (23 grey items) and 60441 (five bags), all 28 rows included. There
are 56 reachable item IDs; 46 previously missing definitions are in `LootItems`.
Existing definitions, including M8-D merchant food, are reused.

## Selected behavior and adaptations

- Each group-zero row rolls independently. Negative chance is a quest drop with the
  absolute percentage. A negative minimum count selects its reference table; maximum
  count is the number of reference selections. Each positive group selects at most
  one item; positive percentages reserve their probability, and zero-chance members
  split any remaining probability equally. The chest food group totals 75%, leaving
  a 25% chance of no food. Quantities use inclusive integer min/max bounds.
- Rows use ascending source item ID, independent entries before groups. A local Godot
  RNG is seeded with world seed XOR stable spawn-ID hash XOR 32452843. Copper rolls
  first, then items. Both wolf profiles also consume their fixed 0–0 copper roll.
  Neither combat nor wandering RNG is touched. IDs include area/slot/ordinal, so
  corresponding replacements retain loot independently of global kill/collection order.
- Resolve all rows and quantities before the quest filter. Death/first opening captures
  eligibility even when objectives are already fulfilled. Later acceptance cannot add
  items. Hand-in/abandonment removes only quest-only items, preserving ordinary loot
  and copper; reacceptance never rerolls an assigned source (FR-028/034).
- Preserve source copper: Vermin 1–4, Worker 1–7, Laborer 2–8, Thug 2–7, Garrick 3–9;
  wolves 0. Battered Chest contains 10–20 copper and one guaranteed grey item,
  with independent 35% water (1–2) and the exclusive food group (1–2).
- Source bags remain carried/sellable loot; equipping/using them is unavailable and
  their tooltip explains the fixed 40-slot inventory (FR-037). Materials remain
  carried/sellable; no professions are added. No source drop in this bounded closure
  requires a random suffix, recipe, scroll, ranged attack or new item-use effect.
- Skinning, pickpocketing, fishing and gathering tables are outside this ordinary-loot
  task and the demo's profession/class scope. Included quests retain their existing
  source loot. Friendlies and added invasion stalkers retain no ordinary loot table;
  killing a stalker immediately completes the demo before looting is possible.

### Chest placement

Replace the normal Abbey development supplies with object 2843 Battered Chests.
The source has three Northshire subpools, each max_limit 1, under Elwynn pool 39902.
The following grid coordinates are explicit counterparts in the compressed map;
source coordinates are not scaled directly onto the rotated valley.

| Source pool | Source gameobject GUIDs | Grid candidate tiles | Stable identity |
| --- | --- | --- | --- |
| 31006 Echo Ridge Mine | 300020, 300021, 300282, 300029 | (40,3), (43,7), (47,4), (49,8) | treasure/mine/0 |
| 31007 Northshire Vineyards | 300022, 300023, 300024 | (37,29), (43,35), (47,31) | treasure/vineyard/0 |
| 31245 Northshire Valley | 300025 | (30,29) | treasure/valley/0 |

Each pool supplies one chest per Loop; placement uses a separate per-identity RNG
with salt 67867967. The wider Elwynn shared pool is replaced by these three bounded
pools. Source real-time respawns are replaced by FR-029's no replenishment within a
Loop. Tiles are nonblocking and corpses/actors may overlap them; F can select the
chest beneath another occupant. The same game repeats placements/loot on reset.
Milly's 12 harvest crates remain object 161557, table 10119, one eligible harvest each.

The old supply table is explicitly ID -1 and confined to the isolated development
movement fixture. No generic or unknown chest falls back to supply rewards. Normal
Northshire has identical reward tables in development and release builds. The
retained supply *merchant* is unaffected; its adaptation belongs to [M8-D](merchants.md).

### Persistence and examples

**Save compatibility:** M8-E writes `demo` revision **7**. Revisions 1–6 are incompatible
and preserved unchanged; no migration is provided. This deliberate content break
prevents older normal-zone development supplies from surviving and avoids changing
unopened loot underneath a saved game. Actor fields already preserve chest tile,
identity, table, assignment, remaining item stacks/copper and visibility; no parallel
loot-state store is introduced. Loading never regenerates depleted or partial loot.

Seed 619, without accepted quests, has these independent known outcomes:

| Source | Tile (chests) | Copper | Items |
| --- | --- | ---: | --- |
| wolves/0/0 (Young Wolf) | — | 0 | Ruined Pelt 4865 ×1 |
| vermin/0/0 | — | 3 | none |
| vineyard/0/0 | — | 3 | Darnassian Bleu 2070 ×1 |
| treasure/mine/0 | (49,8) | 14 | Water 159 ×1; Ragged Leather Vest 1364 ×1; Bread 4540 ×1 |
| treasure/vineyard/0 | (47,31) | 20 | Frayed Gloves 1377 ×1; Bread 4540 ×1 |
| treasure/valley/0 | (30,29) | 16 | Flimsy Chain Cloak 2652 ×1; Tough Jerky 117 ×2 |

For the sorted food group, rolls [0,19) select Jerky, [19,37) Bleu, [37,56) Apple,
[56,75) Bread and [75,100) nothing. Bags each occupy 20% of their reference selection.
A full bag leaves offered loot unchanged; collecting an offered stack is atomic.
Free capacity for only one of a two-unit stack is insufficient. Items can be collected
separately from copper, and empty sources stay depleted through save/load and time.

The GUT suite checks these fixtures, interval boundaries, reference selection and
quantity endpoints, original RNG preservation, quest cleanup, replacement ordinals,
full/partially full bags, item effects, saved partial/depleted chests and Loop reset.
The prior save test now returns to the safe spawn after chest collection, since real
treasure is near hostile populations; it still requires saving outside combat.
The prior quest-loot test compares ordinary drops rather than assuming humanoids drop
no items. Neither change removes its original persistence/filter assertions.

### M8-F coordination and remaining audit

[M8-F](https://github.com/VHonzik/Ostinato/issues/13) is still open and has not resolved
additional populations. Rabbit 721, Deer 883 and Fawn 890 have LootId 0 in the pinned
creature templates, so they need no ordinary loot if included. Mine Spider 43 has a
separate higher-level table and additional reference families; it is a candidate,
not a verified Northshire addition in the current inventory. If F confirms it or
another loot-bearing creature, include its complete transitive loot/item closure in
that runnable addition. No missing creature is silently mapped to wolf/humanoid loot.
This record completes current bounded loot and treasure, not the entire FR-030 audit.

`NorthshireLoot` and `LootItems` hold inspectable static data alongside the existing
item catalogs. Putting these rows in `LootData.assign()` would mix a large content
listing with rolling rules. The small table traversal shares the two current reference
families across seven creatures and chests; no global manager or generic loot framework
is introduced.

## Complete source loot rows

Negative percentages mark quest-only rows; `repeat 1` means one selection from the
named reference. All condition IDs are zero. No source row is silently excluded.

### 6 — Kobold Vermin

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 159 Refreshing Spring Water | 6.5536 | 0 | 1–1 |
| 755 Melted Candle | 29.7889 | 0 | 1–1 |
| 2772 Iron Ore | 0.0073 | 0 | 1–1 |
| 4536 Shiny Red Apple | 13.4595 | 0 | 1–1 |
| 5364 Dry Salt Lick | 0.0073 | 0 | 1–1 |
| Reference 60000 | 9 | 0 | repeat 1 |
| Reference 60441 | 0.66 | 0 | repeat 1 |

### 38 — Defias Thug

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 117 Tough Jerky | 0.02 | 0 | 1–1 |
| 159 Refreshing Spring Water | 6.4011 | 0 | 1–1 |
| 752 Red Burlap Bandana | -80 | 0 | 1–1 |
| 2057 Pitted Defias Shortsword | 1.96 | 0 | 1–1 |
| 2070 Darnassian Bleu | 13.2319 | 0 | 1–1 |
| 4536 Shiny Red Apple | 0.02 | 0 | 1–1 |
| 4540 Tough Hunk of Bread | 0.02 | 0 | 1–1 |
| Reference 60000 | 9 | 0 | repeat 1 |
| Reference 60441 | 0.5 | 0 | repeat 1 |

### 69 — Timber Wolf

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 750 Tough Wolf Meat | -80 | 0 | 1–1 |
| 4865 Ruined Pelt | 39.122 | 0 | 1–2 |
| 5498 Small Lustrous Pearl | 0.0248509 | 0 | 1–1 |
| 7073 Broken Fang | 38.3399 | 0 | 1–2 |
| 7074 Chipped Claw | 38.3736 | 0 | 1–2 |
| Reference 60000 | 9 | 0 | repeat 1 |
| Reference 60441 | 0.5 | 0 | repeat 1 |

### 80 — Kobold Laborer

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 117 Tough Jerky | 0.02 | 0 | 1–1 |
| 159 Refreshing Spring Water | 6.4425 | 0 | 1–1 |
| 755 Melted Candle | 29.3913 | 0 | 1–1 |
| 2055 Small Wooden Hammer | 2.04 | 0 | 1–1 |
| 2070 Darnassian Bleu | 0.02 | 0 | 1–1 |
| 2770 Copper Ore | 0.02 | 0 | 1–1 |
| 2835 Rough Stone | 0.02 | 0 | 1–1 |
| 4536 Shiny Red Apple | 13.542 | 0 | 1–1 |
| 4540 Tough Hunk of Bread | 0.02 | 0 | 1–1 |
| Reference 60000 | 9 | 0 | repeat 1 |
| Reference 60441 | 0.66 | 0 | repeat 1 |

### 103 — Garrick Padfoot

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 117 Tough Jerky | 0.02 | 0 | 1–1 |
| 159 Refreshing Spring Water | 7.3689 | 0 | 1–1 |
| 182 Garrick's Head | -100 | 0 | 1–1 |
| 2057 Pitted Defias Shortsword | 0.83 | 0 | 1–1 |
| 2070 Darnassian Bleu | 12.364 | 0 | 1–1 |
| 4540 Tough Hunk of Bread | 0.04 | 0 | 1–1 |
| Reference 60000 | 9 | 0 | repeat 1 |
| Reference 60441 | 0.5 | 0 | repeat 1 |

### 257 — Kobold Worker

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 159 Refreshing Spring Water | 6.5174 | 0 | 1–1 |
| 755 Melted Candle | 29.5539 | 0 | 1–1 |
| 2770 Copper Ore | 0.02 | 0 | 1–1 |
| 2835 Rough Stone | 0.02 | 0 | 1–1 |
| 4536 Shiny Red Apple | 13.2892 | 0 | 1–1 |
| Reference 60000 | 9 | 0 | repeat 1 |
| Reference 60441 | 0.66 | 0 | repeat 1 |

### 299 — Young Wolf

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 750 Tough Wolf Meat | -80 | 0 | 1–1 |
| 765 Silverleaf | 0.02 | 0 | 1–1 |
| 2396 Light Mail Bracers | 0.02 | 0 | 1–1 |
| 2398 Light Chain Armor | 0.02 | 0 | 1–1 |
| 2447 Peacebloom | 0.02 | 0 | 1–1 |
| 2770 Copper Ore | 0.02 | 0 | 1–1 |
| 3471 Copper Chain Vest | 0.02 | 0 | 1–1 |
| 4302 Small Green Dagger | 0.02 | 0 | 1–1 |
| 4766 Feral Blade | 0.02 | 0 | 1–1 |
| 4865 Ruined Pelt | 36.9481 | 0 | 1–2 |
| 7073 Broken Fang | 37.8937 | 0 | 1–2 |
| 7074 Chipped Claw | 37.7572 | 0 | 1–2 |
| 7280 Rugged Leather Pants | 0.02 | 0 | 1–1 |
| Reference 60000 | 9 | 0 | repeat 1 |
| Reference 60441 | 0.5 | 0 | repeat 1 |

### 2843 — Battered Chest (object loot 2265)

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 117 Tough Jerky | 19 | 1 | 1–2 |
| 159 Refreshing Spring Water | 35 | 0 | 1–2 |
| 2070 Darnassian Bleu | 18 | 1 | 1–2 |
| 4536 Shiny Red Apple | 19 | 1 | 1–2 |
| 4540 Tough Hunk of Bread | 19 | 1 | 1–2 |
| Reference 60000 | 100 | 0 | repeat 1 |

### 161557 — Milly’s Harvest (object loot 10119)

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 11119 Milly's Harvest | -100 | 0 | 1–1 |

### 60000 — Grey world equipment

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 1364 Ragged Leather Vest | 0 | 1 | 1–1 |
| 1366 Ragged Leather Pants | 0 | 1 | 1–1 |
| 1367 Ragged Leather Boots | 0 | 1 | 1–1 |
| 1368 Ragged Leather Gloves | 0 | 1 | 1–1 |
| 1369 Ragged Leather Belt | 0 | 1 | 1–1 |
| 1370 Ragged Leather Bracers | 0 | 1 | 1–1 |
| 1372 Ragged Cloak | 0 | 1 | 1–1 |
| 1374 Frayed Shoes | 0 | 1 | 1–1 |
| 1376 Frayed Cloak | 0 | 1 | 1–1 |
| 1377 Frayed Gloves | 0 | 1 | 1–1 |
| 1378 Frayed Pants | 0 | 1 | 1–1 |
| 1380 Frayed Robe | 0 | 1 | 1–1 |
| 2210 Battered Buckler | 0 | 1 | 1–1 |
| 2211 Bent Large Shield | 0 | 1 | 1–1 |
| 2649 Flimsy Chain Belt | 0 | 1 | 1–1 |
| 2650 Flimsy Chain Boots | 0 | 1 | 1–1 |
| 2651 Flimsy Chain Bracers | 0 | 1 | 1–1 |
| 2652 Flimsy Chain Cloak | 0 | 1 | 1–1 |
| 2653 Flimsy Chain Gloves | 0 | 1 | 1–1 |
| 2654 Flimsy Chain Pants | 0 | 1 | 1–1 |
| 2656 Flimsy Chain Vest | 0 | 1 | 1–1 |
| 3363 Frayed Belt | 0 | 1 | 1–1 |
| 3365 Frayed Bracers | 0 | 1 | 1–1 |

### 60441 — Six-slot bags

| Item / reference | Chance % | Group | Quantity |
| --- | ---: | ---: | --- |
| 805 Small Red Pouch | 0 | 1 | 1–1 |
| 828 Small Blue Pouch | 0 | 1 | 1–1 |
| 4496 Small Brown Pouch | 0 | 1 | 1–1 |
| 5571 Small Black Pouch | 0 | 1 | 1–1 |
| 5572 Small Green Pouch | 0 | 1 | 1–1 |

## Item value inventory

All rows are from the pinned `item_template`; prices are copper per unit.
Bag entries are carried/sold only; they do not expand inventory. Materials are
carried/sold without adding profession systems. Food spell 433 restores 61 health
over 18 turns through the existing food timing rules. Weapons retain source damage
and delay; the three uncommon direct drops retain their fixed primary attributes.

| ID / item | Level | Stack | Sell | Slot | Armor / block | Damage / seconds | Stats / use |
| --- | ---: | ---: | ---: | --- | --- | --- | --- |
| 117 Tough Jerky | 1 | 20 | 1 | — | 0 / 0 | 0–0 / 0.0 | Food 61 / 18 turns |
| 159 Refreshing Spring Water | 1 | 20 | 1 | — | 0 / 0 | 0–0 / 0.0 | Water 151 / 18 turns |
| 182 Garrick's Head | 0 | 1 | 0 | — | 0 / 0 | 0–0 / 0.0 | — |
| 750 Tough Wolf Meat | 0 | 20 | 0 | — | 0 / 0 | 0–0 / 0.0 | — |
| 752 Red Burlap Bandana | 0 | 20 | 0 | — | 0 / 0 | 0–0 / 0.0 | — |
| 755 Melted Candle | 0 | 5 | 1 | — | 0 / 0 | 0–0 / 0.0 | — |
| 765 Silverleaf | 0 | 20 | 10 | — | 0 / 0 | 0–0 / 0.0 | — |
| 805 Small Red Pouch | 0 | 1 | 250 | — | 0 / 0 | 0–0 / 0.0 | — |
| 828 Small Blue Pouch | 0 | 1 | 250 | — | 0 / 0 | 0–0 / 0.0 | — |
| 1364 Ragged Leather Vest | 1 | 1 | 8 | chest | 31 / 0 | 0–0 / 0.0 | — |
| 1366 Ragged Leather Pants | 1 | 1 | 2 | legs | 17 / 0 | 0–0 / 0.0 | — |
| 1367 Ragged Leather Boots | 1 | 1 | 2 | feet | 16 / 0 | 0–0 / 0.0 | — |
| 1368 Ragged Leather Gloves | 1 | 1 | 2 | hands | 17 / 0 | 0–0 / 0.0 | — |
| 1369 Ragged Leather Belt | 1 | 1 | 4 | waist | 18 / 0 | 0–0 / 0.0 | — |
| 1370 Ragged Leather Bracers | 1 | 1 | 2 | wrists | 12 / 0 | 0–0 / 0.0 | — |
| 1372 Ragged Cloak | 1 | 1 | 2 | back | 3 / 0 | 0–0 / 0.0 | — |
| 1374 Frayed Shoes | 1 | 1 | 3 | feet | 5 / 0 | 0–0 / 0.0 | — |
| 1376 Frayed Cloak | 1 | 1 | 4 | back | 5 / 0 | 0–0 / 0.0 | — |
| 1377 Frayed Gloves | 1 | 1 | 1 | hands | 4 / 0 | 0–0 / 0.0 | — |
| 1378 Frayed Pants | 1 | 1 | 1 | legs | 4 / 0 | 0–0 / 0.0 | — |
| 1380 Frayed Robe | 1 | 1 | 4 | chest | 8 / 0 | 0–0 / 0.0 | — |
| 2055 Small Wooden Hammer | 1 | 1 | 16 | main_hand | 0 / 0 | 2–4 / 1.9 | — |
| 2057 Pitted Defias Shortsword | 1 | 1 | 16 | main_hand | 0 / 0 | 2–4 / 2.0 | — |
| 2070 Darnassian Bleu | 1 | 20 | 1 | — | 0 / 0 | 0–0 / 0.0 | Food 61 / 18 turns |
| 2210 Battered Buckler | 1 | 1 | 3 | off_hand | 12 / 1 | 0–0 / 0.0 | — |
| 2211 Bent Large Shield | 1 | 1 | 7 | off_hand | 32 / 1 | 0–0 / 0.0 | — |
| 2396 Light Mail Bracers | 5 | 1 | 43 | wrists | 45 / 0 | 0–0 / 0.0 | — |
| 2398 Light Chain Armor | 5 | 1 | 86 | chest | 102 / 0 | 0–0 / 0.0 | — |
| 2447 Peacebloom | 0 | 20 | 10 | — | 0 / 0 | 0–0 / 0.0 | — |
| 2649 Flimsy Chain Belt | 1 | 1 | 1 | waist | 24 / 0 | 0–0 / 0.0 | — |
| 2650 Flimsy Chain Boots | 1 | 1 | 3 | feet | 34 / 0 | 0–0 / 0.0 | — |
| 2651 Flimsy Chain Bracers | 1 | 1 | 3 | wrists | 25 / 0 | 0–0 / 0.0 | — |
| 2652 Flimsy Chain Cloak | 1 | 1 | 7 | back | 5 / 0 | 0–0 / 0.0 | — |
| 2653 Flimsy Chain Gloves | 1 | 1 | 3 | hands | 35 / 0 | 0–0 / 0.0 | — |
| 2654 Flimsy Chain Pants | 1 | 1 | 2 | legs | 37 / 0 | 0–0 / 0.0 | — |
| 2656 Flimsy Chain Vest | 1 | 1 | 9 | chest | 63 / 0 | 0–0 / 0.0 | — |
| 2770 Copper Ore | 0 | 10 | 5 | — | 0 / 0 | 0–0 / 0.0 | — |
| 2772 Iron Ore | 0 | 10 | 150 | — | 0 / 0 | 0–0 / 0.0 | — |
| 2835 Rough Stone | 0 | 20 | 2 | — | 0 / 0 | 0–0 / 0.0 | — |
| 3363 Frayed Belt | 1 | 1 | 1 | waist | 3 / 0 | 0–0 / 0.0 | — |
| 3365 Frayed Bracers | 1 | 1 | 3 | wrists | 4 / 0 | 0–0 / 0.0 | — |
| 3471 Copper Chain Vest | 5 | 1 | 142 | chest | 108 / 0 | 0–0 / 0.0 | 4:1 |
| 4302 Small Green Dagger | 5 | 1 | 146 | main_hand | 0 / 0 | 4–9 / 1.5 | — |
| 4496 Small Brown Pouch | 0 | 1 | 125 | — | 0 / 0 | 0–0 / 0.0 | — |
| 4536 Shiny Red Apple | 1 | 20 | 1 | — | 0 / 0 | 0–0 / 0.0 | Food 61 / 18 turns |
| 4540 Tough Hunk of Bread | 1 | 20 | 1 | — | 0 / 0 | 0–0 / 0.0 | Food 61 / 18 turns |
| 4766 Feral Blade | 8 | 1 | 481 | main_hand | 0 / 0 | 12–24 / 2.6 | 3:1 |
| 4865 Ruined Pelt | 0 | 5 | 5 | — | 0 / 0 | 0–0 / 0.0 | — |
| 5364 Dry Salt Lick | 0 | 5 | 27 | — | 0 / 0 | 0–0 / 0.0 | — |
| 5498 Small Lustrous Pearl | 0 | 20 | 200 | — | 0 / 0 | 0–0 / 0.0 | — |
| 5571 Small Black Pouch | 0 | 1 | 250 | — | 0 / 0 | 0–0 / 0.0 | — |
| 5572 Small Green Pouch | 0 | 1 | 250 | — | 0 / 0 | 0–0 / 0.0 | — |
| 7073 Broken Fang | 0 | 5 | 6 | — | 0 / 0 | 0–0 / 0.0 | — |
| 7074 Chipped Claw | 0 | 5 | 4 | — | 0 / 0 | 0–0 / 0.0 | — |
| 7280 Rugged Leather Pants | 6 | 1 | 162 | legs | 51 / 0 | 0–0 / 0.0 | 7:1 |
| 11119 Milly's Harvest | 0 | 20 | 0 | — | 0 / 0 | 0–0 / 0.0 | — |

Attribute source IDs: 3 agility, 4 strength, 7 stamina. Quest items are untradable.
