# DATA-001 / DATA-002 / DATA-003 — Milestone 4

Selected 2026-09-21 for FR-001–005, FR-012, the mage/druid starting subset of
FR-018/036, FR-033's first arrival, and FR-039–043. This extends
[hero-baseline.md](hero-baseline.md) and [melee-baseline.md](melee-baseline.md).
The scope is the milestone map's minimum starting-skill trainer, not the higher-rank
training and item services assigned to milestone 5.

## Version and numeric provenance

Use Vanilla 1.12.1, without racials, expansions, seasonal runes, forms, or talents.
The existing community reconstruction
[ClassicDB revision 22b51464](https://github.com/cmangos/classic-db/blob/22b51464f1625f6ef6275771de1f5466c6f5d19e/Full_DB/ClassicDB_1_12_1_z2815.sql.gz)
provides the selected `item_template`, `spell_template`,
`playercreateinfo_spell`, and `creature_template` rows. This is community source
data, not a claim to an official Blizzard database.

The existing [CMaNGOS Unit.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Unit.cpp)
supplies mage spirit regeneration and the spell hit calculation;
[Player.cpp](https://github.com/cmangos/mangos-classic/blob/8ec338a1704e7dcb1c0213eb7ed58f9231ade40f/src/game/Entities/Player.cpp)
supplies critical chance and resource tick handling. Only numeric rules are selected;
the implementation is independently written GDScript.

Wowhead Classic was read for [Fireball 133](https://www.wowhead.com/classic/spell=133/fireball),
[Frost Armor 168](https://www.wowhead.com/classic/spell=168/frost-armor),
[Wrath 5176](https://www.wowhead.com/classic/spell=5176/wrath),
[Healing Touch 5185](https://www.wowhead.com/classic/spell=5185/healing-touch),
and [Mark of the Wild 1126](https://www.wowhead.com/classic/spell=1126/mark-of-the-wild).
Its level-60 tooltip view includes innate rank scaling; use the database's level-1
base/dice fields below rather than copying those displayed endpoints.

[WoWWiki Spirit](https://wowwiki-archive.fandom.com/wiki/Spirit) could not be read
(access failure). Indexed [WoWWiki Spell hit](https://wowwiki-archive.fandom.com/wiki/Spell_hit)
corroborates the 96% same-level and 83% +3-level probabilities, but mixes expansions
and advertises a later 100% cap. Select the Vanilla 99% cap from CMaNGOS instead.
The mana-regeneration talk-page excerpt was insufficient to establish numeric rules;
the pinned source supplies them.

## Starting outfit and skills

The human mage receives Apprentice's Robe 56 (3 armor), Pants 1395 (2), Boots 55
(0), Shirt 6096 (0), and Bent Staff 35 (3–5 damage, 2.9 seconds). Wowhead's
[Classic robe](https://www.wowhead.com/classic/item=56/apprentices-robe) and
[shirt](https://www.wowhead.com/classic/item=6096/apprentices-shirt) corroborate the
identities. For the raceless druid outfit select the Night Elf variant: Novice's
Robe 6123 (3), Pants 6124 (2), and Bent Staff 35. A direct Wowhead druid-robe
request failed; the numeric item rows were read from ClassicDB.

Both outfits leave primary attributes and resource maxima unchanged. The starting
mage is 20/20/20/23/22, HP 51, mana 165, armor 45 including its 5 equipment armor.
The mage growth and combat conversions continue after selecting druid.

Starter provenance belongs to each item instance. Class exchange removes remaining
granted outfit pieces from equipment and inventory, preserves acquired items, and
places replacement pieces for occupied acquired slots in free inventory slots.
Insufficient space rejects the entire exchange. The 40 slots and outfit display
are present now; looting, equipping, consuming, and trading arrive with M5's item data.

Mage begins knowing Fireball and Frost Armor. The druid trainer teaches Wrath,
Healing Touch, and level-1 Mark of the Wild free, without quests, following FR-005/036.
Class selection teaches nothing. `playercreateinfo_spell` identifies Wrath and
Healing Touch as druid starting actives; Mark is a level-1 trainer ability.
Dodge/defense and all proficiencies are inherent under FR-019. Languages, opening,
honor, PvP, racials, and internal utility records do not create extra spell-book
buttons. There are no additional starting trainer passives in this subset.

| Rank 1 | Mana | Seconds | Target / range | Level-1 effect |
| --- | ---: | ---: | --- | --- |
| Fireball 133 | 30 | 1.5 | Neutral/hostile, 7 tiles | 14–22 fire damage, then 1 every 2 turns twice |
| Frost Armor 168 | 60 | Instant, ordinary GCD | Self | +30 armor for 1800 turns; chills melee attackers |
| Wrath 5176 | 20 | 1.5 | Neutral/hostile, 6 tiles | 12–14 nature damage |
| Healing Touch 5185 | 25 | 1.5 | Self/friendly, 8 tiles | 37–51 healing |
| Mark of the Wild 1126 | 20 | Instant, ordinary GCD | Self/friendly, 6 tiles | +25 armor for 1800 turns |

All have learning level 1, no individual cooldown, no consumable prerequisite, and
the adapted one-turn GCD. Maximum ranges follow floor(yards/5), including Fireball's
35 yards. Damage/healing base endpoints gain floor((min(level,5)−1) × rate), where
the source `EffectRealPointsPerLevel1` rates are 0.6, 0.4, and 0.8 for Fireball,
Wrath, and Healing Touch respectively. Rank-1 scaling stops at source MaxLevel 5;
leveling does not grant a new rank.

Spell hit percentage is 96 minus target level difference through +2; above +2 it
is 94 minus 11 per further level, bounded to 1–99. Critical chance uses the mage
baseline, 3.7 + intellect/(14.77 + 0.65 × min(level,60)); direct healing/damage
critical results multiply by 1.5 and truncate. Spells bypass physical armor.
Current creatures have zero school resistance; later equipment/stat data will add
the remaining mitigation and spell-power coverage in M5. No channels or individual
spell cooldowns are invented for these five spells.

Frost Armor's source Chilled 6136 lasts five seconds, slows movement 30%, and
increases the attack interval 25%. Successful damaging melee contact applies it.
NPC movement accumulates 0.7 tiles per phase while chilled; remainder survives
expiry. Interval changes preserve swing progress. Recasting an armor spell refreshes
its own duration without stacking; Frost Armor and Mark stack with one another.
Fireball periodic damage refreshes its own target instance rather than stacking.
The first tick follows two elapsed turns after completion, never the completion
boundary itself. Death removes that target's remaining periodic effect.

## Time and terminal boundaries

FR-012's shared casting balance is independent of melee/movement. A 1.5-second cast
costs two turns from zero, then one turn at 0.5 credit; ordinary instants retain
credit and consume one turn. Target preselection always requires confirmation,
including a single enemy or self-heal. Harmful commitment engages a neutral
before progress. At completion recheck life, relationship, range, sight, and mana.
Failure or cancellation spends elapsed time, charges no mana, and grants no credit.
A successful resisted spell still spends its cast and mana.

The first cast boundary runs immediately; subsequent boundaries use the existing
0.18-second presentation gap and permit Escape cancellation. Menus suspend that
presentation continuation. Death drops the remainder of the actor/effect/event
phase. The scene replaces the entire `GridWorld` through `GameSession`; old
references never acquire access to the new attempt.

Mage health regeneration is floor((spirit × 0.11 + 1) × 2) every two simulation
turns outside combat. Mana recovers floor(spirit/4 + 12.5) on that same two-turn
clock when at least five turns have elapsed since the last successful mana cost.
At spirit 22 this is 6 HP and 18 mana per eligible tick. Casting without spending
mana does not restart the five-second rule. Class changes retain this mage baseline.
No regeneration, expiry, arrival, or random choice runs from real-time idle frames.

## First stalker fixture

FR-033's first arrival occurs at turn 15, at (54,14), after the shared phase.
A blocked tile leaves it pending and retries each turn; announcement occurs once
when the actor enters. It cannot act until the next shared phase. The fixture is
extended eastward to 56×28, putting the gate farther than 15 base-speed moves from
spawn (20,14). The guard at (53,14) dies in the arrival story event and keeps its
corpse throughout the Loop. The stalker idles at the gate until normal aggro.

Use an ordinary level-20 creature profile from ClassicDB's
[Wildthorn Stalker 3819](https://www.wowhead.com/classic/npc=3819/wildthorn-stalker):
494 HP, 888 armor, raw melee 31–38, AP 16, two-second swing. Presentation as a demon,
location, guard death, and omission of the source spider's special abilities are
explicit invasion-fixture adaptations. Later reinforcements and demo completion
remain milestone 8; this first arrival does not claim them.

## Save and implementation decisions

`GameSession` separates progression history from the replaceable attempt. Keeping
persistent ranks in a scene reset callback would make reset/load ownership harder
to inspect and test. `SaveCodec` enumerates fields and validates a separate world;
`SaveStore` handles files and five slots. Combining these with the UI would couple
file failure tests to rendering. These are ordinary helpers, without autoloads,
an event bus, or a generalized persistence framework.

The `demo` revision-1 JSON stores seed, Loop, the currently implemented world,
hero, outfits, ranks, buffs, actor ordering, corpses, timers/credits, first-arrival
progress, chat, hotbar state, and both RNG states. Seed/RNG int64 values are decimal
strings to avoid JSON's double-precision loss. Types and domain values are checked
before replacing any live state. No older supported schema exists, so no speculative
migration is added. Future state additions must migrate or declare revision 1
unsupported under NFR-012.

Saving writes a sibling temporary file, flushes and reads it back, validates the
entire state, then replaces the destination through Godot's native rename operation.
Failures report an error and preserve the previous destination. Tests exercise
occupied slots, rejected combat/pending saves, blocked writes, damaged bytes,
unsupported revisions, copies, and deterministic continuation through an arrival.
Malformed saves are renamed with a UTC timestamp and random suffix; preserved files
survive reuse of their slot. Global bindings/fullscreen/palette live separately.

UI validation uses the minimum 640×360 logical view. Five-slot and keybinding
screens scroll and follow keyboard focus. These automated geometry/render checks
do not claim human acceptance, final accessibility, or reference-hardware performance.
