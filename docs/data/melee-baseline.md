# DATA-002 — Milestone 3 melee and solo kill XP

Selected 2026-09-20 for FR-009/014/016/020–027/048/049/050. This is the
milestone map's initial melee subset, using Vanilla 1.12 references. It does not
claim complete Classic combat, equipment, regeneration, spells, or loot coverage.

## Sources and selections

[Wowhead's Blizzard combat comparison](https://www.wowhead.com/classic/news/not-a-bug-combat-table-values-in-classic-wow-291996)
reports testing against Blizzard's 1.12 reference, with skill-dependent avoidance.
[WoWWiki Attack table](https://wowwiki-archive.fandom.com/wiki/Attack_table) and
[Armor](https://wowwiki-archive.fandom.com/wiki/Armor) could not be retrieved in this
review. Their current contents were not used.

The numeric implementation reference is the community Vanilla reconstruction
[CMaNGOS Classic Unit.cpp, revision 8ec338a](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Unit.cpp).
Let `d = defender defense - attacker weapon skill`, both `5 × level` (FR-019).
Selected percentages and damage rules from its named combat methods:

| Rule | Selection |
| --- | --- |
| Miss | 5 + 0.04d; versus higher NPC: 5 + 0.1 min(d,10) + 0.6 max(d−10,0). |
| Dodge | Defender dodge + 0.04d; higher NPC uses 0.1d. Player rear dodge is zero; NPC rear dodge remains. |
| Critical | Attacker critical − 0.04d against player, − 0.2d against NPC. Double damage. |
| Glancing | Player against NPC above level 10: min(player level,30) + 2d. Mage multiplier ranges from clamp(0.6−0.05d,0.01,0.6) to clamp(0.9−0.03d,0.2,0.99), with lower bounded by upper. |
| Crushing | NPC skill advantage ≥15: 2 × advantage −15 percent; 1.5 damage. |
| Armor | Reduction min(75%, armor/(armor+400+85 × attacker level)). |

One cumulative roll orders miss, dodge, glancing, critical, crushing, then ordinary
hit; clamp individual probabilities to 0–100%. Integer weapon damage is sampled
inclusively, armor reduces it (minimum 1), then the outcome multiplier is truncated.

[Mage calculations in Player.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Player.cpp)
and [StatSystem.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/StatSystem.cpp)
supply attack power `strength − 10`, armor `2 × agility`, and agility per critical
percentage point interpolated from 12.9 at level 1 to 20 at level 60. Dodge adds
3.25 percentage points to that agility contribution. AP adds `AP/14 × weapon seconds`
to both weapon endpoints. Above 60, retain the final agility conversion while the
existing FR-016 primary-stat extension continues. No race bonus is applied.

[Wowhead Bent Staff, item 35](https://www.wowhead.com/classic/item=35/bent-staff)
provides 3–5 physical damage and 2.90 seconds. This is a temporary combat profile,
not an inventory item or a claim that full starter equipment is implemented.

[ClassicDB 22b51464](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz)
`creature_template` entries 299 and 69 provide the fixture values below. Their identities
are also listed by Wowhead: [Young Wolf](https://www.wowhead.com/classic/npc=299/young-wolf)
and [Timber Wolf](https://www.wowhead.com/classic/npc=69/timber-wolf).

| Profile | Level | Health | Armor | Raw damage | AP | Swing seconds |
| --- | --- | --- | --- | --- | --- | --- |
| Young / meadow wolf | 1 | 42 | 15 | 2–2 | 1 | 2 |
| Timber wolf | 2 | 55 | 16 | 2–2 | 1 | 2 |

NPC baseline dodge/critical are 5%. Creature data are used directly as a bounded
fixture profile; no creature-stat generator is implied. Timber wolves are hostile
here to demonstrate acquisition; Young/meadow wolves are neutral. Positions, names
of friendly keepers, aggro radius 5, and base movement speed are fixture choices.

## Solo kill XP

[WoWWiki Mob XP](https://wowwiki-archive.fandom.com/wiki/Formulas:Mob_XP) supplies
Azeroth base XP `45 + 5 × player level`, +5% per higher level capped at four, and
lower-level multiplier `1 − level difference / zero difference`. Gray kills give zero.
Use its pre-expansion level-60 gray boundary 47, not the expansion boundary 51.
Other gray boundaries follow its example's bands 1–5, 6–39, and 40–59. Its zero-difference
bands through 60 are recorded directly in `MeleeRules.kill_experience`.

Choose nearest-integer XP, ties upward, matching the wiki's example. The pinned
[CMaNGOS Formulas.h](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Tools/Formulas.h)
corroborates the base and difference bands but uses `nearbyint` and gray 51 at 60;
those two details are not adopted. No rested, group, exploration, elite, pet, or
quest modifiers are implemented here. Fixture wolves are ordinary solo kills,
credited exactly once at death; a per-actor eligibility flag suppresses XP for
non-rewarding fixtures. Beyond 60, continue the final gray offset (level −13).

## Adaptations and implementation boundary

This milestone deliberately omits parry, block, daze, dual wield, spell mitigation,
resistances, buffs, procs, regeneration, and loot rewards. Add these from sourced
records with their dependent features; do not interpret omissions as final rules.
Glancing multiplier sampling is continuous within the recorded bounds. Damage
rounding and random streams are fixed for reproducibility within this build.

FR-014 converts seconds to elapsed turns using a separate `SwingTimer`. A ready
initial swing costs one player turn; an NPC entering adjacency swings in that phase.
Active fractional delay is retained, and faster weapons can swing multiple times.
Inactive time caps readiness at one swing. Committed player attacks automatically
advance until a swing resolves, keeping every NPC phase. `MovementGame` leaves a
0.18-second presentation gap before each additional boundary for **Esc** or the
**Cancel attack** button; this gap changes no simulation duration. Cancellation retains
spent turns, and completion never starts another attack. Reset discards the pending
request and presentation delay. Movement/cast credit cannot pay for melee.

Facing follows committed movement/attack. Relative directions quantize to eight
sectors with clockwise half-sector ties; the three opposite sectors are behind.
NPC action order is the append-only actor array. Navigation uses breadth-first
search for a shortest terrain route, checking static reachability independently of
living occupancy. Among equal-length routes, expansion prefers squared distance to
the player (or home), then N/NE/E/SE/S/SW/W/NW for stable ties. Only an occupied next
step triggers an occupancy-aware route search; a farther occupied step or melee tile
does not cause early spreading. After five static failures, return home and heal on arrival;
if home is statically unreachable, idle legally. Corpses stop acting and blocking,
remain selectable (including under occupants), and disappear after 300 turns.
The fixture exposes an empty-loot message; it grants no items or duplicate XP.

Selection sorts by Chebyshev distance then stable actor index. Directional input
prefers a candidate ahead with the smallest forward + twice lateral displacement;
otherwise it wraps from the opposite edge, breaking ties by that same candidate
order. It consumes no randomness. A single interaction candidate skips selection.
Neutral NPCs always require an explicit **Attack <name>?** confirmation; hostiles can
be attacked directly. Greetings and empty-corpse results go to chat without another
window. Combat prompts disable Tab focus and use labeled shortcuts or mouse clicks.
Committing harm engages before the first boundary; previews/cancellation remain free.
These interaction and pursuit decisions follow the owner's
[PR #3 QA feedback](https://github.com/VHonzik/Ostinato/pull/3#issuecomment-5750943924)
and the revised FR-010/014/021/023. No targeted spells are introduced,
so full spell targeting and completion revalidation remain with milestone 4.

Death consumes its accepted action boundary and discards remaining NPC work. The
overlay blocks gameplay until fixture Reset. This is the expressly temporary
milestone-3 behavior, not FR-002 Loop persistence. Resource values remain visible;
melee spends no mana. Learned real spells remain informational previews.

`MeleeProfile` gives existing hero/NPC records the same small typed calculation
input, avoiding duplicated formulas or an actor inheritance hierarchy. `MeleeRules`
keeps sourced arithmetic separate from turns; `SwingTimer` shares the fractional
rule. The alternative is duplicating both rules in player/NPC branches. `CombatPanel`
handles the current modal interaction without coupling navigation tests to rendering.

## Independent numeric examples

- Level-1 mage: AP 10, armor 40, critical ≈1.55039%, dodge ≈4.80039%.
- Staff endpoints after AP: floor(3+10/14×2.9)=5 and floor(5+10/14×2.9)=7.
  Against armor 15: ordinary damage 4–6; critical 8–12.
- Same-level miss roll 4.99% misses; 5% dodges; 50% is a normal hit.
- Fresh active 1.5-second delay swings after 2 then 1 turns; 0.5 permits two per turn.
- Player/NPC levels 1/1 award 50 XP; 1/2 award 53; 2/1 award 44;
  6/1 award 0; 6/2 award 15; 60/47 award 0; 60/48 award 101.

GUT covers these examples, eligibility, deaths, interaction, static/crowded pursuit,
sight, every rear direction, deterministic outcomes, and modal input boundaries.
