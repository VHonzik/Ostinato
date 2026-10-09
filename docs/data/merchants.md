# DATA-004: Individual Northshire merchants (M8-D)

Implements FR-030/038/037/021, FR-002/041 and NFR-013. Catalog audit: 2026-10-09.

## Sources and selected version

Use the same [CMaNGOS ClassicDB Vanilla 1.12.1 snapshot](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz)
as the [Northshire inventory](northshire.md). Read `npc_vendor`, `npc_vendor_template`,
`creature_template`, `item_template` and `spell_template`. The four vendors use direct
rows (VendorTemplateId 0), no conditions, and unlimited stock (maxcount 0, incrtime 0).
This is a community Vanilla reconstruction, not Blizzard source code.

[Wowhead Classic Danil](https://www.wowhead.com/classic/npc=152/brother-danil) and
[Dermot](https://www.wowhead.com/classic/npc=190/dermot-johns) confirm their merchant
roles, but the retrieved pages did not expose catalog rows. The
[Godric](https://www.wowhead.com/classic/npc=1213/godric-rothgar) and
[Janos](https://www.wowhead.com/classic/npc=78/janos-hammerknuckle) pages were inaccessible.
[WoWWiki Danil](https://wowwiki-archive.fandom.com/wiki/Brother_Danil),
[Dermot](https://wowwiki-archive.fandom.com/wiki/Dermot_Johns),
[Godric](https://wowwiki-archive.fandom.com/wiki/Godric_Rothgar) and
[Janos](https://wowwiki-archive.fandom.com/wiki/Janos_Hammerknuckle) corroborate the
Northshire merchant identities. These mixed-era pages do not override the pinned numeric rows.

[Wowhead Classic Merissa](https://www.wowhead.com/classic/npc=11940/merissa-stilwell)
shows the Welcome! quest hand-in, not a sale catalog. In the pinned database Merissa
11940 has NpcFlags 2 (questgiver), VendorTemplateId 0 and no npc_vendor rows.
The [WoWWiki Merissa page](https://wowwiki-archive.fandom.com/wiki/Merissa_Stilwell)
was inaccessible. The M8-D audit list identified a contact, not a verified fifth source
merchant: she stays ambient; no invented catalog or Collector's Edition entitlement
reward is added. The final bounded quest audit remains M8-F.

## Catalogs, prices and quantities

Each row below is one purchase bundle. Prices and sell values are whole copper,
without reputation discounts (no reputation system). UI quantities count purchase
bundles and explicitly name their size; selling selects individual carried units.
Stack limits, level/slot rules, armor, shield block and weapon values come directly
from item_template. The new data live in `MerchantItems`; existing item definitions
are reused. Bread 4540 uses the same Food spell 433 and 61-health/18-turn restoration
as the existing food, under the [M5 item timing adaptation](learning-baseline.md#data-004-items-loot-and-trade).
Purchasing equipment never checks its use level; equipping and consuming still do.

### Brother Danil (152)

| Item ID / name | Bundle | Buy copper | Sell copper/unit | Stack | Stock |
| --- | ---: | ---: | ---: | ---: | --- |
| 4540 Tough Hunk of Bread | 5 | 25 | 1 | 20 | Unlimited |
| 159 Refreshing Spring Water | 5 | 25 | 1 | 20 | Unlimited |

### Dermot Johns (190)

| Item ID / name | Bundle | Buy copper | Sell copper/unit | Stack | Stock |
| --- | ---: | ---: | ---: | ---: | --- |
| 2121 Thin Cloth Armor | 1 | 50 | 10 | 1 | Unlimited |
| 3599 Thin Cloth Belt | 1 | 24 | 4 | 1 | Unlimited |
| 2120 Thin Cloth Pants | 1 | 50 | 10 | 1 | Unlimited |
| 2117 Thin Cloth Shoes | 1 | 37 | 7 | 1 | Unlimited |
| 3600 Thin Cloth Bracers | 1 | 24 | 4 | 1 | Unlimited |
| 2119 Thin Cloth Gloves | 1 | 25 | 4 | 1 | Unlimited |
| 2127 Cracked Leather Vest | 1 | 60 | 12 | 1 | Unlimited |
| 2122 Cracked Leather Belt | 1 | 32 | 6 | 1 | Unlimited |
| 2126 Cracked Leather Pants | 1 | 60 | 11 | 1 | Unlimited |
| 2123 Cracked Leather Boots | 1 | 49 | 9 | 1 | Unlimited |
| 2124 Cracked Leather Bracers | 1 | 33 | 6 | 1 | Unlimited |
| 2125 Cracked Leather Gloves | 1 | 33 | 6 | 1 | Unlimited |

### Godric Rothgar (1213)

| Item ID / name | Bundle | Buy copper | Sell copper/unit | Stack | Stock |
| --- | ---: | ---: | ---: | ---: | --- |
| 2379 Tarnished Chain Vest | 1 | 76 | 15 | 1 | Unlimited |
| 2381 Tarnished Chain Leggings | 1 | 76 | 15 | 1 | Unlimited |
| 2380 Tarnished Chain Belt | 1 | 38 | 7 | 1 | Unlimited |
| 2383 Tarnished Chain Boots | 1 | 58 | 11 | 1 | Unlimited |
| 2384 Tarnished Chain Bracers | 1 | 38 | 7 | 1 | Unlimited |
| 2385 Tarnished Chain Gloves | 1 | 38 | 7 | 1 | Unlimited |
| 17184 Small Shield | 1 | 36 | 6 | 1 | Unlimited |
| 2129 Large Round Shield | 1 | 77 | 15 | 1 | Unlimited |

### Janos Hammerknuckle (78)

| Item ID / name | Bundle | Buy copper | Sell copper/unit | Stack | Stock |
| --- | ---: | ---: | ---: | ---: | --- |
| 2131 Shortsword | 1 | 54 | 10 | 1 | Unlimited |
| 1194 Bastard Sword | 1 | 104 | 20 | 1 | Unlimited |
| 2134 Hand Axe | 1 | 82 | 16 | 1 | Unlimited |
| 2479 Broad Axe | 1 | 108 | 21 | 1 | Unlimited |
| 2130 Club | 1 | 54 | 10 | 1 | Unlimited |
| 2480 Large Club | 1 | 72 | 14 | 1 | Unlimited |
| 2139 Dirk | 1 | 57 | 11 | 1 | Unlimited |
| 2132 Short Staff | 1 | 102 | 20 | 1 | Unlimited |

## Explicit catalog adaptations

Owner decision, 2026-10-09, recorded in FR-038: omit Danil's Rough Arrow 2512,
Light Shot 2516, Small Throwing Knife 2947 and Crude Throwing Axe 3111. Their source
bundles are 200 units for 10/10/15/15 copper respectively, all unlimited. Ranged-weapon
attacks are not introduced by this merchant package. Bags are not in this pinned
Danil catalog, and expandable bags remain excluded by FR-037. Repair is excluded by FR-019.

Retain the existing **Abbey supply trader (900003)** at (16,18) as an explicit final-content
invasion provisioner. This preserves access to the M5 mixed starter supplies and finite
mana potions inside the enclosed zone. It is an Ostinato addition, not a Classic vendor.
Each purchase gives one item: Dirk 2139 at 57c, Large Round Shield 2129 at 77c,
Dirty Leather Vest 85 at 62c, Tough Jerky 117 and Water 159 at 5c each, all unlimited;
Minor Mana Potion 2455 at 40c has exactly three units per Loop. Source item properties
and sell values remain unchanged. In particular, Danil's water comes in source bundles
of five for 25c; the supply trader sells one for 5c. No buyback or restocking on sale.

## Identity, state and checks

`MerchantData` is a stateless catalog and initial-stock helper, like existing item data.
Keeping these records inline in GridWorld/UI would duplicate catalog/price checks;
this helper lets construction, transactions, UI and save validation use the same records.
GridWorld owns `vendor_stock[spawn_id][item_id]`; `npc_id` selects a catalog, while the
stable spawn identity owns the stock. Two instances with the same catalog remain independent.
The exact actor travels through interaction, conversation, trade, quantity confirmation
and transactions. It must still belong to the current world, be alive/friendly and in
interaction range. Stale references after load/death cannot authorize a purchase or sale.

All purchases check bundle count (1–1000), catalog membership, funds, whole-stock quantity
and full capacity before committing. Selling checks the selected stack/quantity and
tradability, at any valid merchant. Trading, rejected actions and opening menus are free,
including in combat at an action boundary. Waiting, selling and scripted merchant respawn
do not refill finite stock. Death/New Game rebuild initial stocks.

Examples: Danil's two bread bundles deliver ten loaves for 50c. With only 49c, or only
nine free units in the bag, neither copper nor items change. Selling three loaves returns
3c. The supply trader's three mana potions cost 120c; a fourth is rejected until a new Loop.

**Compatibility:** demo revision **6** replaces the global item-keyed stock dictionary with
merchant-instance dictionaries. Revisions 1–5 are incompatible and remain unchanged;
no migration is provided. Loading checks exact merchant/catalog keys, integral quantities,
finite values in 0..initial stock and an unchanged -1 marker for unlimited stock. It restores
a separate world before adoption. Unit coverage includes distinct catalogs and instances,
full bags, exact funds, sold-out stock, stale/dead/distant actors, reset and saved continuation.
