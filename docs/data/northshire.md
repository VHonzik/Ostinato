# DATA-004: Northshire and quests (milestone 6)

Implements FR-029–032, FR-034/035/047, with FR-002/021/027/028/041
integration. This is milestone content, not final-demo or human QA acceptance.

## Sources and version

Vanilla 1.12.1 values come from the existing
[pinned ClassicDB snapshot](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz):
quest_template, creature_questrelation, creature_involvedrelation, creature,
creature_template, item_template, and creature_loot_template.
This community reconstruction is not Blizzard source code.

Wowhead Classic was consulted for [Kobold Camp Cleanup](https://www.wowhead.com/classic/quest=7),
[Investigate Echo Ridge](https://www.wowhead.com/classic/quest=15),
[Wolves Across the Border](https://www.wowhead.com/classic/quest=33),
[Brotherhood of Thieves](https://www.wowhead.com/classic/quest=18),
[Bounty on Garrick Padfoot](https://www.wowhead.com/classic/quest=6),
[Milly Osworth](https://www.wowhead.com/classic/quest=3903), and
[Milly's Harvest](https://www.wowhead.com/classic/quest=3904).
Use Classic counts, not reduced Retail/Wrath counts or seasonal quests.
WoW Wiki's [Quest difficulty](https://wowwiki-archive.fandom.com/wiki/Quest_difficulty)
was attempted but inaccessible; its contents were not read.

The pinned [CMaNGOS QuestDef.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Quests/QuestDef.cpp)
supplies quest XP; [Formulas.h](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Tools/Formulas.h)
supplies GetQuestGreenRange. These are version-qualified implementation references.

## Implemented quest inventory

IDs map to QuestData.QUESTS, except source 33 retains the existing "wolves" key.
QuestData and NorthshireItems preserve source letters and every reward choice.
Dialogue and objective labels are original paraphrase.

| ID | Quest | Minimum / level | Prerequisite | Objective | Base XP / copper |
| --- | --- | --- | --- | --- | --- |
| 783 | A Threat Within | 1 / 1 | none | Talk to Marshal 197 | 40 / 0 |
| 7 | Kobold Camp Cleanup | 1 / 2 | 783 | 10 Vermin 6 | 170 / 25 |
| 15 | Investigate Echo Ridge | 1 / 3 | 7 | 10 Workers 257 | 250 / 40 |
| 21 | Skirmish at Echo Ridge | 1 / 5 | 15 | 12 Laborers 80 | 450 / 0, item choice |
| 5261 | Eagan Peltskinner | 1 / 2 | 783 | Talk to Eagan 196 | 85 / 0 |
| 33 | Wolves Across the Border | 1 / 2 | 5261 | 8 meat 750 | 170 / 0, item choice |
| 18 | Brotherhood of Thieves | 2 / 4 | 783 | 12 bandanas 752 | 360 / 0, item choice |
| 6 | Bounty on Garrick Padfoot | 2 / 5 | 18 | Head 182 | 340 / 0, item choice |
| 3903 | Milly Osworth | 2 / 4 | 33 | Talk to Milly 9296 | 35 / 0 |
| 3904 | Milly's Harvest | 2 / 4 | 3903 | 8 harvest 11119 | 180 / 0 |
| 3905 | Grape Manifest | 2 / 4 | 3904 | Deliver 11125, talk to Neals 952 | 360 / 0, item choice |
| 3104 | Glyphic Letter | 1 / 1 | 7, mage | Deliver 9571, talk to Khelden 198 | 40 / 0 |
| 3101 | Consecrated Letter | 1 / 1 | 7, paladin | Deliver 9570 to Sammuel 925 | 40 / 0 |
| 3103 | Hallowed Letter | 1 / 1 | 7, priest | Deliver 9548 to Anetta 375 | 40 / 0 |
| 3105 | Tainted Letter | 1 / 1 | 7, warlock | Deliver 9576 to Drusilla 459 | 40 / 0 |
| shaman_referral | A Shaman at the Abbey | 1 / 1 | 7, shaman | Talk to added trainer | 40 / 0 |
| druid_referral | A Druid at the Abbey | 1 / 1 | 7, druid | Talk to added trainer | 40 / 0 |
| gate_survey | Watch the Northshire Gate | 1 / 2 | 783 | Overlook and Willem | 85 / 0 |

The pinned row selects Wolves as Milly's prerequisite. Wowhead historical comments
also mention Brotherhood; the selected database row is used instead of treating that
comment as an additional prerequisite.

Druid referral is an Ostinato counterpart to the source class referral. Gate survey is
an original invasion quest so location and multiple-objective completion are playable.
The overlook is (43–45, 11–17), outside the idle stalker's initial aggro range.
Its 85 XP is an explicit initial game value, matching a small referral reward.
Crossing any objective tile counts, including an intermediate fractional-movement step.

Quest operations are free and available in combat at action boundaries. Acceptance
grants source letters only if they fit and permanently closes that Loop's class choice.
Opening a conversation does not accept quests. Loot objectives reflect carried quantities.
Hand-in removes required/surplus quest-only items and checks the entire reward before
committing items, currency and XP once. Abandonment removes quest-only items from bags
and assigned loot without unassigning/rerolling sources; reacceptance resets counters.

## Difficulty and XP

Red is +5 or more, orange +3/+4, yellow -2 through +2. Below that, green extends
inclusively to player level minus the following range; one level lower is gray.

| Player level | Green range |
| --- | ---: |
| 1–9 | 4 |
| 10–19 | 5 |
| 20–29 | 6 |
| 30–39 | 7 |
| 40–44 | 8 |
| 45–49 | 9 |
| 50–54 | 10 |
| 55–59 | 11 |
| 60+ | 12 |

Player 10 sees quest 5 green and 4 gray; player 60 sees 48 green and 47 gray.
The 60+ continuation uses the pinned function's final range.

For these quests, base XP is RewMoneyMaxLevel / 0.6. Full XP through a player/quest
difference of 5; differences 6/7/8/9 give 80/60/40/20%; 10+ gives 10%.
Round upward once after scaling. A 170-XP quest gives 136/102/68/34/17 at those boundaries.
An 85-XP gray quest gives 9, never zero. Difficulty does not gate availability.
The game retains XP after level 60 under FR-016's uncapped progression, rather than
converting XP to maximum-level money. Only RewOrReqMoney grants copper.

## Valley and fixed content

The 56×44 valley has impassable edges. Source geography is compressed/rotated: abbey
central, wolves west, kobolds/mine north, vineyard east across a river bridge, shack
southeast, gate far east. Spawn is (20,14), marshal (18,12), gate (54,14).
The earliest base-speed gate route exceeds the first stalker's turn-15 arrival.
Abbey, stable/training room and shack have doors and single-floor interiors.
Neals is on the abbey ground floor; no tower/stair requirement remains.

NorthshireZone.NPCS records fixed IDs, counterparts and tiles. Implemented contacts:
197 Marshal, 823 Willem, 196 Eagan, 198 Khelden, 9296 Milly, 952 Neals.
Also present: 1212 Bishop Farthing, 375 Anetta, 925 Sammuel, 459 Drusilla, 915 Jorik,
911 Llane, 152 Danil, 190 Dermot, 1213 Godric, 78 Janos, 11940 Merissa,
6373 Dane, 951 Paxton, 11260 peasant, 5403 stallion, and 1642 Northshire guard.
Added counterparts: druid trainer 900001, shaman visitor 900002, supply trader 900003.
M7 adds active priest/paladin/warlock/shaman training; all six supported classes now train.
Warrior/rogue trainers are ambient contacts only.

The guard begins alive and is killed by the existing first-stalker story event.
That corpse remains throughout the Loop. Other scripted friendly deaths return at
home after 30 turns, retrying blocked homes. Ordinary attacks cannot kill friendlies.
Marshal/guards know of the invasion; Milly/peasants blame bandits; clergy report refugees.

## Enemy presentation

FR-020 uses distinct existing-sheet silhouettes for every included enemy type, selected
by source NPC ID rather than current relationship. Zero-based 16-pixel cells in
scroolospritescharacters_nobg.png are: Young Wolf 299 → (9,0), Timber Wolf 69 → (0,4),
Kobold Vermin 6 → (0,5), Worker 257 → (1,5), Laborer 80 → (3,5), Defias Thug 38 → (1,2),
Garrick 103 → (3,2). The invasion stalker uses (3,4), identified by its story flag.
These are presentation counterparts, not claims that the source sheet depicts WoW art.
Relationship colors, selection outlines, facing and health indicators remain independent
of these base sprites. Replacements and restored saves derive the same art from actor data.

## Seeded populations and loot

| Area | Source types | Slots | Tiles |
| --- | --- | ---: | --- |
| wolves | 69 Timber Wolf, 299 Young Wolf | 10 | x3–13, y20–34 |
| vermin | 6 Kobold Vermin | 8 | x5–12, y2–8 |
| workers | 257 Kobold Worker | 8 | x29–37, y2–8 |
| mine | 80 Kobold Laborer | 10 | x39–49, y2–8 |
| vineyard | 38 Defias Thug | 10 | x34–48, y25–38 |
| garrick | 103 Garrick Padfoot | 1 | x49–52, y32–36 |

NorthshireData uses each source's lower-level health/armor/damage/power/swing profile,
a fixed spawn tuning choice. Source wolf IDs/names are used (the old fixture reversed
the labels). Wolves/kobolds are neutral; Defias/Garrick hostile. Wandering respects areas.

Each slot starts at ordinal zero. Death schedules ordinal+1 at death turn+30.
Type and placement derive from seed/area/slot/ordinal independently of combat RNG.
Blocked placement retries without advancing ordinal. At most 95 ordinary actors can
be alive; five positions remain reserved for stalkers. Arrivals append to the actor
order and first act next turn. Corresponding loot uses the existing private spawn-ID
stream, unaffected by combat rolls or collection order.

There are 12 harvest crates (object 161557 counterpart), one harvest each when eligible
at first opening. Crates and the abbey supply chest never replenish in a Loop.
The supply chest retains M5's documented development supply table for equipment access.
Humanoid copper uses source min/max; bandanas roll 80%, Garrick's head 100%;
wolf loot retains its M5 rows, including 80% meat. Eligibility is captured at death/
first opening, even after objective completion, and rechecked on collection.
Ineligible opening never adds quest loot retroactively.

## Scheduled invasion arrivals (M8-B)

FR-031/033 explicitly define this invasion adaptation: Loop turns 15, 215, 395, 555
and 695, with at most five stalkers. All five retain the sourced level-20 ordinary
creature profile selected in [DATA-002's first-stalker record](loop-baseline.md#first-stalker-fixture)
(494 health, 888 armor, 31–38 raw melee, 16 attack power, two-second swing).
No combat formula or new Classic source selection is introduced by this package.

Legal gate placements are tried in fixed order: (54,14), (54,13), (54,15), (53,13),
(53,15). All are inside the valley and outside the gate-survey aggro boundary.
Even the nearest is 33 tiles from spawn in an unobstructed Chebyshev path, so the
turn-15 first arrival still precedes the earliest ordinary base-speed visit.
Each entered actor idles at its entry/home until normal aggro. Only identity zero
kills the guard and announces feasting; identities one through four announce reinforcements.

The world checks terrain, player and living actor occupancy, including summons.
All blocked means pending; overdue identities enter in order at the next free boundary,
possibly several together, without shifting any deadline. Stable IDs are `gate/stalker/0`
through `/4`, independent of entry delay and tile. Save revision 5 preserves the deadlines,
entered count, actor order and turn; pending state follows from these saved values.
Reset restores the initial schedule. Victory discards its remaining execution.
The ordinary population cap is 95 world NPCs; pets and totems do not consume that budget.

## Exclusions and remaining final inventory

The bounded content inventory covers the enclosed valley, abbey/mine/vineyard and gate.
The tables and source-ID data above describe M6; these explicit gaps remain for M8:

- Exclude outbound 54 Report to Goldshire and 2158 Rest and Relaxation and their outside
  receivers. Falkhaan 6774's outside-gate travel role is omitted.
- Exclude 3100 Simple Letter and 3102 Encrypted Letter (warrior/rogue), later class quests,
  and source Imp unlock quest under FR-018. Profession lessons, weapon grinding,
  spirit resurrection and repair services do not apply to the Loop game.
- M7 completed referrals 3101/3103/3105 for paladin/priest/warlock, an adapted shaman
  referral, active trainers and included summon exceptions; see [DATA-003](renaissance.md).
- M8-D completed the [merchant audit and services](merchants.md): Danil, Dermot, Godric
  and Janos have individual source catalogs; Merissa has no source vendor catalog.
  The supply trader is explicitly retained as an invasion provisioner.
- M8 final content audit: remaining ordinary/reference/world-drop and chest tables; ambient rabbits,
  deer/fawns, mine spiders and remaining guard/peasant copies; terrain/art refinement.
  M8-D records the retained supply trader separately from the source merchants.
- Outside-valley Defias Cutpurses 94 and unrelated generic Stormwind guards 1423 are
  excluded. Stalkers are the invasion addition, not a source Northshire population.

## Persistence and implementation shape

M6 demo revision **3** added quests/counters/handed-in state, population slots/ordinals/
deadlines, source NPC IDs, and the Northshire marker. Revisions 1 and 2 are incompatible
and preserved unchanged; no migration is claimed. M7 now uses revision **4**.
M8-D now uses revision **6** for per-merchant stock; revisions 1–5 are incompatible.
Restore validates a separate world.
Loop reset returns to seeded ordinal zero and clears quests, preserving learned ranks.

QuestRules keeps eligibility and atomic rewards out of UI handlers and the turn scheduler;
inline UI mutations would duplicate rollback logic. NorthshireZone replaces the normal
session map while retaining MovementFixture for focused tests. Both are stateless
helpers; GridWorld owns state. No event bus, scripting framework, or global manager is added.
