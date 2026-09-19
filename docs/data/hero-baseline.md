# DATA-001 / DATA-002 — Milestone 2 hero baseline

Selected 2026-09-19 for FR-015/016/017/046/048/050. This record supplies the
starting attributes, resources, mage growth, starting spell identities, and XP portion
needed by milestone 2. Combat formulas, resource spending/regeneration, complete starter
equipment, and real spell effects remain dependencies of later milestones.

## Version and sources

Use Vanilla 1.12.1, without racial effects. The numeric source is
[CMaNGOS ClassicDB, revision 22b51464](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz):
human race 1 / mage class 8 in `player_levelstats`, mage class 8 in
`player_classlevelstats`, and levels 1–59 in `player_xp_for_level`.
This is a community Vanilla reconstruction, not an official Blizzard dataset.
The complete selected numeric rows are inspectable in
[hero_data.gd](../../scripts/hero/hero_data.gd).

[WoWWiki Mage races](https://wowwiki-archive.fandom.com/wiki/Mage_races) was available
through indexed text; direct access failed. Its human row has attributes
20/20/20/23/22, 52 health and 165 mana, but mixes expansions.
[WoWWiki Human](https://wowwiki-archive.fandom.com/wiki/Human_%28playable%29)
instead lists 23 spirit and warns of outdated expansion context.
[Wowhead's Classic mage guide](https://www.wowhead.com/classic/guide/classes/mage/dps-overview-pve)
identifies Human Spirit as a 5% racial bonus. Selected base spirit is 22;
the racial-inclusive floor of 22 × 1.05 is 23. Do not divide the already unmodified
database growth rows by 1.05. No racial spells or modifiers are granted.

Resource calculations and level-up refill follow the source implementation:
[StatSystem.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/StatSystem.cpp)
(`GetHealthBonusFromStamina`, `GetManaBonusFromIntellect`) and
[Player.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Player.cpp)
(`GiveLevel`). The first 20 stamina/intellect each add one health/mana;
later points add 10 health / 15 mana. Level-up restores both to their new maxima.
Use the explicitly versioned database's base health 31 (total 51), not the
mixed-era wiki's total 52. Mage level-2 base mana is 170; do not substitute the
older archived SQL's 110. This resolves source differences without averaging them.

## Numeric fixtures and extension

| Level | Strength / agility / stamina / intellect / spirit | Base health / mana | Total health / mana | XP to next |
| --- | --- | --- | --- | --- |
| 1 | 20 / 20 / 20 / 23 / 22 | 31 / 100 | 51 / 165 | 400 |
| 2 | 20 / 20 / 20 / 24 / 24 | 37 / 170 | 57 / 250 | 900 |
| 3 | 20 / 20 / 21 / 25 / 25 | 42 / 181 | 72 / 276 | 1,400 |
| 10 | 21 / 22 / 23 / 34 / 34 | 127 / 256 | 177 / 486 | 7,600 |
| 60 | 30 / 35 / 45 / 125 / 126 | 1360 / 1273 | 1630 / 2868 | 209,800 (extension) |

[WoWWiki XP to level, Pre-2.3 table](https://wowwiki-archive.fandom.com/wiki/Formulas:XP_To_Level#Pre-2.3_Table)
matches all selected level 1–59 thresholds: 4,084,700 XP total to reach level 60.
Exclude its expansion progression beginning at 60 and the later reduced thresholds.
At level 60 and beyond, reuse 209,800 XP and repeat the final 59→60 increments:
attributes +0/+0/+1/+2/+3; base health +42; base mana +21. Thus level 61 has
1682 health and 2919 mana. This is FR-016's Ostinato extension, not Vanilla data.

399 XP leaves level 1; another 1 reaches level 2 with zero excess.
450 XP leaves level 2 with 50/900 XP. A single 1,350 XP award reaches level 3
with 50/1,400 XP. Zero/negative development awards do nothing.

## Initial ranks and development fixture

The database's `playercreateinfo_spell` and Wowhead Classic identify starting
[Fireball rank 1 (133)](https://www.wowhead.com/classic/spell=133/fireball) and
[Frost Armor rank 1 (168)](https://www.wowhead.com/classic/spell=168/frost-armor).
They are learned, readable previews in the Mage tab. Activating one reports its
deferred execution without time or resource cost. This milestone does not substitute
dummy damage/buffs for their eventual sourced effects. Full loadout, proficiency/passive
coverage, targeted combat, and casting timing belong to their later dependencies.

The Development tab contains three explicitly temporary, untargeted skills, each rank 1,
learning level 1, zero mana, no individual cooldown, and exactly one turn:
Practice reports success; Gain 450 XP uses ordinary progression; Death trigger reports
invocation while preserving health and gameplay until milestone 3. These values are
development-fixture choices authorized by the milestone map and FR-050, not WoW spells.
The player effect completes before one shared NPC phase; movement credit is unchanged.
Unlearned ranks reject without time. Learning enforces level and duplicate identity;
using a learned development rank does not recheck level or selected class.
Release builds omit development ranks and their tab; there are no direct debug keybindings.

The character panel currently shows the five primary attributes, level/XP, and resources.
Secondary combat stats await the milestone-3 formula subset rather than displaying invented
values. Health/mana remain visible; no mechanic in this milestone depletes them.
Fixture Reset starts a fresh level-1 hero and clears chat alongside the movement fixture;
it is not New Game, death, persistent learning, or a Loop.

## Implementation choice

`HeroState` owns progression and learned ranks; `HeroData` holds the selected numeric rows;
`SkillRank` is a typed record for the five visible skills. Keeping these in the scene
would tie progression tests to rendering and bury sourced data among UI callbacks.
`GridWorld` applies a cast and then its existing shared phase. `HeroPanel` handles only
display and selection. No global manager, event bus, or general spell engine is introduced.
Chat retains the most recent 100 messages in a scrollable view.
