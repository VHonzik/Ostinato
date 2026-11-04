# Current items

The authoritative reference for all 69 defined items. Numeric values and behavior live in
game data/code; this document describes their current meaning and acquisition.
[Quests and NPCs](npc-dialogue.md) covers rewards and services;
[class mechanics](class-mechanics.md) owns ability and trainer-gift effect details.

## Reading the tables

- Item level is metadata, not an equip requirement. Every class can equip all gear at any
  player level. Outfit means the armor slot; rings fill either of the two ring slots.
- Weapon setups occupy one equipment slot: two hands, a weapon/shield pair, or a
  dual-wield pair. Damage ranges are base weapon damage before character bonuses.
  Swing intervals, durations and cooldowns use world turns.
- Crit and haste bonuses are percentage points. Strength, agility and stamina are
  attribute bonuses; see [shared class mechanics](class-mechanics.md#shared-mechanics).
- Prices are per item in copper (buy / sell). A defined buy value does not imply a
  vendor currently offers the item. Unavailable entries remain defined for fixtures
  or have no acquisition source in the playable valley.
- Equipment stacks to 1, is tradable, and is not unique. Special-item rules are listed
  separately. Starter-granted equipment carries provenance: Fresh Start replaces only
  starter-marked items and preserves normally acquired copies.
- Equipment, supplies, gifts and their claim state belong to the current Loop. Saves
  retain them; death rebuilds supplies and clears acquired items and quest claims.

## Equipment

| ID | Item | Quality | Item level | Slot / setup | Armor | Weapon damage / interval | Bonuses | Buy / sell | Acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2653 | Battered Armor | Poor | 1 | Outfit | 15 | - | - | 10c / 1c | Unavailable in playable valley; no current acquisition source |
| 2379 | Battleworn Armor | Poor | 1 | Outfit | 20 | - | - | 10c / 1c | Fresh Start: Warrior/Paladin |
| 2361 | Battleworn Hammer and Shield | Poor | 1 | Weapon + shield | 15 | 1–3 / 2.4 | - | 10c / 2c | Fresh Start: Warrior/Paladin |
| 35 | Bent Staff | Poor | 1 | Two hands | - | 3–5 / 2.9 | - | 10c / 2c | Starting equipment; Poor enemy gear pool |
| 2649 | Flimsy Chain Armor | Poor | 1 | Outfit | 15 | - | - | 10c / 1c | Poor enemy gear pool |
| 1374 | Frayed Clothes | Poor | 1 | Outfit | 8 | - | - | 10c / 1c | Unavailable in playable valley; no current acquisition source |
| 1378 | Frayed Robe | Poor | 1 | Outfit | 8 | - | - | 10c / 1c | Unavailable in playable valley; no current acquisition source |
| 2057 | Pitted Sword and Shield | Poor | 1 | Weapon + shield | 20 | 2–4 / 2.4 | - | 10c / 2c | Poor enemy gear pool |
| 1367 | Ragged Leather Armor | Poor | 1 | Outfit | 12 | - | - | 10c / 1c | Poor enemy gear pool |
| 2055 | Small Wooden Hammer | Poor | 1 | Two hands | - | 3–5 / 2.9 | - | 10c / 2c | Unavailable in playable valley; no current acquisition source |
| 44 | Travel Clothes | Poor | 1 | Outfit | 8 | - | - | 10c / 1c | Starting equipment; Fresh Start: Shaman/Rogue |
| 2092 | Worn Daggers | Poor | 1 | Dual wield | - | 1–2 / 1.6; off hand 1–2 / 1.6 | - | 10c / 2c | Fresh Start: Rogue; Poor enemy gear pool |
| 36 | Worn Mace and Shield | Poor | 1 | Weapon + shield | 15 | 1–3 / 2.4 | - | 10c / 2c | Fresh Start: Shaman |
| 2139 | Balanced Daggers | Common | 1 | Dual wield | - | 2–4 / 1.6; off hand 2–4 / 1.6 | +1% crit; +3% haste | 200c / 20c | Seeded Janos offer pool; Common chest gear pool |
| 1194 | Bastard Sword | Common | 1 | Two hands | - | 5–8 / 3 | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture merchant |
| 3070 | Ensign Cloak | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 4560 | Fine Scimitar | Common | 1 | Weapon + shield | 40 | 3–5 / 2.4 | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; development-fixture chest |
| 2129 | Guard Sword and Shield | Common | 1 | Weapon + shield | 40 | 3–5 / 2.4 | +1% crit; +3% haste | 200c / 20c | Seeded Janos offer pool; Common chest gear pool |
| 2690 | Latched Belt | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 60 | Layered Tunic | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 2224 | Militia Daggers | Common | 1 | Dual wield | - | 3–5 / 2.4; off hand 3–5 / 1.6 | +1% crit; +3% haste | 200c / 20c | The Northern Camp |
| 5580 | Militia Hammer and Shield | Common | 1 | Weapon + shield | 40 | 5–7 / 2.4 | +1% crit; +3% haste | 200c / 20c | Milly’s Vineyard |
| 1159 | Militia Quarterstaff | Common | 1 | Two hands | - | 6–9 / 2.8 | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 1161 | Militia Shortsword | Common | 1 | Weapon + shield | 40 | 3–5 / 2.4 | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 5579 | Militia Warhammer | Common | 1 | Two hands | - | 6–9 / 2.9 | +1% crit; +3% haste | 200c / 20c | Into Echo Ridge |
| 2186 | Outfitter Belt | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 2691 | Outfitter Boots | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 11192 | Outfitter Gloves | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 70001 | Patrol Amulet | Common | 1 | neck | - | - | +1 stamina; +2% haste | 200c / 20c | Wolves of the Western Woods; Seeded Janos offer pool; Common chest gear pool |
| 85 | Patrol Armor | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Wolves of the Western Woods; Seeded Janos offer pool; Common chest gear pool |
| 70003 | Quick Band | Common | 1 | ring | - | - | +1 agility; +2% haste | 200c / 20c | Around the Valley; Seeded Janos offer pool; Common chest gear pool |
| 2121 | Reinforced Cloth Armor | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture merchant |
| 2132 | Short Staff | Common | 1 | Two hands | - | 5–8 / 3.2 | +1% crit; +3% haste | 200c / 20c | Seeded Janos offer pool; Common chest gear pool |
| 2131 | Shortsword | Common | 1 | Weapon + shield | 70 | 3–5 / 2.4 | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture merchant |
| 4302 | Small Green Dagger | Common | 1 | Dual wield | - | 3–5 / 2.4; off hand 3–5 / 1.6 | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; no current acquisition source |
| 80 | Soft Fur-lined Shoes | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 70002 | Steady Band | Common | 1 | ring | - | - | +1 strength; +1% crit | 200c / 20c | The Northern Camp; Seeded Janos offer pool; Common chest gear pool |
| 6076 | Tapered Pants | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 11475 | Wine-stained Cloak | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 6070 | Wolfskin Bracers | Common | 1 | Outfit | 90 | - | +1% crit; +3% haste | 200c / 20c | Unavailable in playable valley; fixture quest reward |
| 70011 | Amber Amulet | Uncommon | 1 | neck | - | - | +2 stamina; +3% haste | 200c / 20c | Uncommon enemy/chest gear pool |
| 70023 | Briar Daggers | Uncommon | 1 | Dual wield | - | 3–6 / 1.6; off hand 3–6 / 1.6 | +2 strength; +1% crit; +4% haste | 200c / 30c | Uncommon enemy/chest gear pool |
| 4766 | Feral Blade | Uncommon | 1 | Dual wield | - | 3–5 / 2.4; off hand 3–5 / 1.6 | +2 strength; +1 stamina; +1% crit; +5% haste | 300c / 30c | Unavailable in playable valley; no current acquisition source |
| 70013 | Leafstone Ring | Uncommon | 1 | ring | - | - | +2 agility; +3% haste | 200c / 20c | Uncommon enemy/chest gear pool |
| 70021 | Oakheart Staff | Uncommon | 1 | Two hands | - | 7–11 / 2.9 | +2 strength; +1% crit; +4% haste | 200c / 30c | Uncommon enemy/chest gear pool |
| 7280 | Rugged Leather Armor | Uncommon | 1 | Outfit | 130 | - | +2 strength; +1 stamina; +1% crit; +5% haste | 300c / 30c | Uncommon enemy/chest gear pool |
| 2572 | Runed Linen Armor | Uncommon | 5 | Outfit | 130 | - | +2 strength; +1 stamina; +1% crit; +5% haste | 300c / 30c | Uncommon enemy/chest gear pool |
| 70022 | Sentinel Sword and Shield | Uncommon | 1 | Weapon + shield | 70 | 6–9 / 2.4 | +2 strength; +1% crit; +4% haste | 200c / 30c | Uncommon enemy/chest gear pool |
| 3471 | Tempered Chain Armor | Uncommon | 1 | Outfit | 130 | - | +2 strength; +1 stamina; +1% crit; +5% haste | 300c / 30c | Unavailable in playable valley; no current acquisition source |
| 70012 | Wolfstone Ring | Uncommon | 1 | ring | - | - | +2 strength; +2% crit | 200c / 20c | Uncommon enemy/chest gear pool |

## Consumables

| ID | Item | Quality | Item level | Stack | Buy / sell | Use | Acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 117 | Tough Jerky | Common | 1 | 20 | 5c / 1c | Restores 61 HP over 18 turns while stationary and out of combat. Taking a movement/combat action stops eating. One item and one world turn per use. Tradable; not unique. | Starting supplies (5); camp/mine kobolds, Defias and Garrick; chests; Janos |
| 118 | Minor Healing Potion | Common | 1 | 5 | 20c / 5c | Restores 30–40 HP immediately; shared potion cooldown 120 turns. Usable in combat. One item and one world turn per use. Tradable; not unique. | Janos (3 per Loop) |

## Special items

| ID | Item | Quality | Item level | Stack | Buy / sell | Rules / effect reference | Acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 71005 | Wartorn Banner | Common | 1 | 1 | 0c / 0c | Nontradable; unique. [Effect](class-mechanics.md#trainer-gift-wartorn-banner). | Brother Sammuel’s completed-training gift |
| 71004 | Ancestral totem | Common | 1 | 1 | 0c / 0c | Nontradable; unique. [Effect](class-mechanics.md#trainer-gift-ancestral-totem). | Farseer Lopaa’s completed-training gift |
| 71002 | Lucky charm | Common | 1 | 1 | 0c / 0c | Nontradable; unique. [Effect](class-mechanics.md#trainer-gift-lucky-charm). | Jorik’s completed-training gift |
| 71003 | Broken lucky charm | Poor | 1 | 1 | 0c / 0c | Nontradable; not unique. No effect. | Lucky charm after preventing a lethal hit |
| 71001 | War Horn | Common | 1 | 1 | 0c / 0c | Nontradable; unique. [Effect](class-mechanics.md#trainer-gift-war-horn). | Llane’s completed-training gift |

## Miscellaneous and quest items

| ID | Item | Quality | Item level | Stack | Buy / sell | Rules / effect | Acquisition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 7073 | Broken Fang | Poor | 0 | 5 | 25c / 6c | Tradable; not unique. Trade goods; no use effect. | Young Wolves and Timber Wolves |
| 7074 | Chipped Claw | Poor | 0 | 5 | 16c / 4c | Tradable; not unique. Trade goods; no use effect. | Young Wolves and Timber Wolves |
| 755 | Melted Candle | Poor | 0 | 5 | 4c / 6c | Tradable; not unique. Trade goods; no use effect. | Camp/mine kobolds, Defias and Garrick |
| 4865 | Ruined Pelt | Poor | 0 | 5 | 20c / 5c | Tradable; not unique. Trade goods; no use effect. | Young Wolves and Timber Wolves |
| 9570 | Consecrated Letter | Common | 0 | 1 | 0c / 0c | Nontradable; not unique. Quest item for `3101`; no use effect. | Unavailable in playable valley; fixture quest item |
| 182 | Garrick's Head | Common | 0 | 1 | 0c / 0c | Nontradable; unique. Quest item for `6`; no use effect. | Unavailable in playable valley; fixture quest item |
| 11125 | Grape Manifest | Common | 0 | 1 | 0c / 0c | Nontradable; unique. Quest item for `3905`; no use effect. | Unavailable in playable valley; fixture quest item |
| 2589 | Linen Cloth | Common | 0 | 20 | 55c / 13c | Tradable; not unique. Trade goods; no use effect. | Unavailable in playable valley; no current acquisition source |
| 11119 | Milly's Harvest | Common | 0 | 20 | 0c / 0c | Nontradable; not unique. Quest item for `3904`; no use effect. | Unavailable in playable valley; fixture quest item |
| 752 | Red Burlap Bandana | Common | 0 | 20 | 0c / 0c | Nontradable; not unique. Quest item for `18`; no use effect. | Unavailable in playable valley; fixture quest item |
| 805 | Small Red Pouch | Common | 0 | 1 | 1000c / 250c | Tradable; not unique. Trade goods only; inventory capacity is fixed at 40 slots. | Unavailable in playable valley; no current acquisition source |
| 750 | Tough Wolf Meat | Common | 0 | 20 | 0c / 0c | Nontradable; not unique. Quest item for `wolves`; no use effect. | Unavailable in playable valley; fixture quest item |

## Acquisition rules

### Janos

Each world seed and Janos’s stable spawn identity select exactly one weapon, Tough Jerky,
Minor Healing Potion, and two distinct nonweapon extras from the equipment offer pool
above. The selected gear costs 200c and is unlimited; jerky costs 5c and is unlimited;
potions cost 20c with three per Loop. The same seed repeats the selection after death.
Shop visits do not reroll or replenish stock; saves retain remaining quantities.

### Enemy and chest pools

Ordinary valley enemies roll poor equipment at 10% and uncommon equipment independently
at 5%, with equal selection within each named pool above. Valley chests guarantee one
equipment item: 60% common, 40% uncommon, equally selected within that pool. Chests also
have a 50% chance of one or two jerky. Enemy-specific supplies and trade goods use the
[source tables](../scripts/items/northshire_loot.gd). Quest-bound drops require an accepted
matching quest; the fixture quest items above are unavailable on the playable route.
Loot repeats by world seed and source spawn identity, independently of vendor selection.

## Implementation locations

[ItemData](../scripts/items/item_data.gd) resolves the five definition catalogs and
item instances. [MerchantData](../scripts/items/merchant_data.gd) owns offer pools, prices
and seeded stock. [StarterGear](../scripts/hero/starter_gear.gd) defines class outfits;
[QuestRules](../scripts/quests/quest_rules.gd) awards them through Fresh Start.
