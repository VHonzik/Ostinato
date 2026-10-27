# Current class mechanics and abilities

The authoritative overview of implemented classes, abilities, training and effect art.
[Direction](direction.md) covers design goals; [the backlog](backlog.md) tracks work.

[Warrior](#warrior) · [Shaman](#shaman) · [Paladin](#paladin) · [Rogue](#rogue) · [Code locations](#implementation-locations)

## Reading the tables

- Tables include actives and passives, sorted by learning level, copper cost, then name.
- `-` means not applicable; `0` rage means a free active that still spends its action.
  `*` marks details explained in the description.
- Cast time, cooldown and duration use **world turns**. Cast time `1` spends one turn;
  durations describe gameplay rather than visual flashes. Cooldowns show base values.
- Range uses grid tiles with diagonals counting as one tile (square/Chebyshev distance).
  `Self` means a self cast. Enemy casts require a living nonfriendly target in range
  and sight; passive triggers use the triggering ability's range unless specified.
- Learning costs use copper (`c`): 100c = 1 silver; 10,000c = 1 gold. `0` means free.
  Level-1 starters have no additional level gate.
- Sprite `C(x,y)` is the zero-based column/row of a 16x16 cell in
  [characters.png](../assets/spritesheets/characters.png), editable in
  [characters.aseprite](../art/characters.aseprite). `R(x,y)` uses the same convention
  in [scroolospritescharacters_nobg.png](../assets/spritesheets/scroolospritescharacters_nobg.png).
  The world draws each cell at 32x32.
- Sprite placement describes actual rendering, separately from the gameplay target.
  Most ability sprites briefly replace the player/struck enemy for 1.5 real seconds.
  Whirlwind flashes landed targets, not a whole area. Consecration flashes its fixed
  ground tiles for 1.5 real seconds on each damage tick, including NPC occupants but
  always excluding the player's current tile. Leaving the ground does not move it.
  Character effects compete by the priority below.
  Effect sprites, including quest and aggro markers, replace both NPC health and
  faction sprites while visible. Markers retain faction tint; ability flashes retain
  health tint.
  An enemy's melee bump briefly reveals its actor through a Consecration flash.
  Summon art is a world actor, not an overlay. Passives add no dedicated effect sprite;
  upgraded actives retain their own art. Poison procs use a shared enemy flash.
  `-` does not exclude aura text, combat numbers or other shared UI. These are default mappings; GridView allows actor-art overrides.

### Enemy NPC effect sprite priority

Includes neutral creatures. Highest priority first; normal health/faction art appears
when no effect wins.

| Priority | Effect |
| --- | --- |
| 1 | Melee bump |
| 2 | Fel Breath wind-up |
| 3 | Fel Breath release |
| 4 | Mortal Strike |
| 5 | Judgement |
| 6 | Eviscerate |
| 7 | Lava Burst |
| 8 | Aggro marker |
| 9 | Whirlwind |
| 10 | Windfury |
| 11 | Consecration |
| 12 | Poison trigger |

### Friendly NPC effect sprite priority

Includes summons. Highest priority first.

| Priority | Effect |
| --- | --- |
| 1 | Melee bump |
| 2 | Fel Breath release |
| 3 | Consecration |
| 4 | Ready hand-in marker C(5,1) |
| 5 | Available quest marker C(5,0) |

### Player effect sprite priority

Highest priority first. Consecration always excludes the player's current tile.

| Priority | Effect |
| --- | --- |
| 1 | Melee bump |
| 2 | Fel Breath release |
| 3 | Evasion |
| 4 | Divine Shield |
| 5 | Vanish |
| 6 | Charge |
| 7 | Battle Shout |
| 8 | Lightning Shield |
| 9 | Poison coating |

Competing flashes age independently; an unexpired lower effect appears when the winner
ends. Repeating an effect refreshes its 1.5-second flash. Vanish selects the translucent
class sprite at its priority. On unoccupied ground, Fel Breath release beats Consecration.
Health/faction tint, damage numbers, countdowns and cone borders remain independent.

## Shared mechanics

New Game starts as Warrior knowing Mortal Strike and Whirlwind. Loop two offers only
Warrior at the marshal; from Loop three, choose Warrior, Shaman, Paladin or Rogue
before accepting quests. Selection locks training to that class until death.
Trainers are Llane (Warrior), Farseer Lopaa (Shaman), Brother Sammuel (Paladin) and
Jorik Kerridan (Rogue). Other starter pairs are free level-1 trainer purchases.
Later purchases require the listed current-Loop
level and money, without prerequisite purchases or spending XP. Learned actives and
passives persist across deaths and work in every class, even below their original
training level. Passives cannot be cast/assigned to the hotbar. All gear is usable
in every class without learning or level requirements.

Completing a class's training unlocks its trainer gift once each Loop, regardless of
the selected class. Gifts and their claim state persist through saves and clear on
death; permanent learning allows another gift in the next Loop.

All classes use rage, capped at 100. Ordinary main-hand swing attempts generate 7 rage
per turn of the weapon's base interval, independent of haste and hit result. Damaging
incoming hits grant 3 rage at most once per world turn. Ordinary off-hand swings and
bonus strikes generate no baseline rage. Outside combat, rage decays by 2 per turn,
or 0.5 with Anger Management; fractional rage is retained internally. Natural healing
works only outside combat: 1.5 HP per turn at level 1, 0.75 at level 2 and 0.3 from
level 3 onward, delivered as whole-HP ticks. Food and other healing keep their own rules.

Table rage costs are base costs. Battle Trance makes the next Mortal Strike,
Judgement, Lava Burst or Eviscerate free; other abilities preserve the proc.
Sudden Death allows one Execute at any target health, with its normal 15-30 rage
spending and extra-rage damage. Execute consumes Sudden Death when ready and
preserves Battle Trance. Rejected casts spend no rage or procs.
Consumable procs/charges persist until spent or death, including between encounters.
Timed buffs continue counting down outside combat.

Vanish pauses automatic swings while their timers keep advancing without banking
attacks. Moving and waiting preserve concealment. A valid deliberate melee attack
or ability ends it immediately; only that opening swing or ability receives the
additional critical chance. Non-damaging abilities consume the opening, too. Casts
keep their bonus until completion, but cancellation loses it. Misses/dodges spend
the opening normally. An area attack applies the bonus to each of its direct hits;
follow-up automatic swings, summons, periodic damage and bonus strikes gain none.

Hotbar buttons use a translucent two-pixel inside border: gold for Juggernaut's
Mortal Strike or Art of War's Judgement critical readiness, blue for a free-use proc,
and amber for a missing maintenance buff. Five held combo points also highlight
Eviscerate in gold. Combined gold/free readiness splits the border between both colors.
Free-use highlights appear only when the cast is usable, including cooldown, target,
range, sight and ability-specific requirements. Maintenance checks Battle Shout, Lightning Shield,
Windfury on the equipped weapon, and an uncoated equipped hand for poisons; either
poison satisfies a hand. Present buffs never warn merely for nearing expiration.
Tooltips explain the highlighted states without consuming procs.

Weapon damage uses the main hand and Strength-derived weapon power unless specified
otherwise. Physical attacks use hit, dodge, critical and armor rules; learned Shield
Block can partially reduce incoming physical hits while a shield is equipped.
Dodge is flat in every direction, without a level modifier or front/rear rule.
Weapon Mastery reduces enemy dodge by 2.5 percentage points, to a minimum of 0%,
for both hands, physical abilities and bonus weapon strikes (standard 5% becomes 2.5%).
Direct Holy/Fire/Nature attacks use hit/critical rules and bypass armor and Shield Block.
Precision prevents misses for weapon and direct magical attacks at every enemy level;
it does not prevent dodges. Without Precision, miss chance is 5% plus 2 percentage
points per higher enemy level, capped at 95% before other hit modifiers.
Level differences and applicable buffs modify listed base damage.
Haste changes independent hand swing timers, not action count or ability cooldowns.
Restless Blades can reduce running cooldowns.
Swing timing continues through abilities, movement and waiting, attacking the committed
enemy when in melee. With no valid commitment, the first enemy attempting an attack
against the player becomes committed, even on a miss/dodge. Melee bumps can change it.
Retargeting keeps the remaining swing delay. The white, borderless 3px swing bar sits
centered on the rage bar's top border and fills left to right using fractional main-hand
turn delay: full when ready, empty after a full-interval swing reset. It follows resource
visibility on desktop and mobile and does not advance with real time.

The committed action resolves before the turn advances. At the advanced turn boundary,
timed hero buffs, summons and ordinary debuffs expire, then Judgement,
Consecration and Deadly Poison resolve, followed by due player swings and enemy actions.
Final verdicts/poison ticks are preserved. Terminal death/victory stops further resolution.
Death clears temporary combat state, summons, coatings, ground and combo points, retaining
learning. Saves retain implemented mid-Loop effect state, including banked Maelstrom.

Primary attacks are ordinary swings and direct active attacks. Primary physical crits,
including physical active crits, can trigger Flurry and Wrecking Crew.
Finishers still qualify for these critical buffs and Vengeance, but cannot build points,
advance Bandit's Guile, or trigger Battle Trance. Bonus strikes/copies, seal damage,
poison, ground and reactive damage do not recursively enter the primary attack pipeline.
With Relentless Assault, landed Mortal Strike, Execute, Lava Burst and Judgement build
player-held points across targets/encounters, capped at five. Combat Potency adds a
main-hand auto-attack chance, sharing the one-base-point-per-turn cap. Seal Fate adds
points only on qualifying crits of those four abilities. Eviscerate alone spends
combo points; Execute and Judgement do not.

## Warrior

**Tagline: Turn pain into rage, strike decisively, and raise a shield when survival matters.**

Physical burst with Mortal Strike, adjacent cleave with Whirlwind, Charge for closing
distance and Execute for low-health targets or Sudden Death openings. Battle Trance
banks a free core attack. Enrage rewards taking hits; Death Wish trades safety for
damage as health falls. Shield Block adds passive shield defense.

| Name | Rage cost | Cast time | Cooldown | Duration | Range | Level required to learn | Cost to learn | Sprite used for effect | Sprite placement (player / target / area) | Description |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mortal Strike | 30 | 1 | 4 | - | 1 | 1 | 0 | C(0,1) | Target | Active physical attack. Deals 200% weapon damage. A learned Juggernaut charge guarantees the next landed Mortal Strike crit and is then consumed. |
| Whirlwind | 15 | 1 | - | - | 1 | 1 | 0 | C(0,2) | Targets (each landed hit) | Active. 70% weapon damage to each adjacent neutral or hostile enemy in sight (3x3 area), in stable actor order. One turn, no cooldown; weapon timing continues. Wrecking Crew adds 35% more Whirlwind damage while its buff is active. Each landed hit can crit/proc, but cannot trigger Sweeping Strikes or build combo points. Keeps your selected attack target. Stops on terminal death. |
| Enrage | - | - | - | 10 | - | 1 | 15c | - | - | Passive proc. Surviving damaging enemy hits have a 30% chance for +10% physical damage and +5 percentage points of attack critical chance for 10 turns, at any health. At most one roll per world turn. Refreshes without stacking; misses, dodges and immune hits cannot trigger it. |
| Battle Shout | 0 | 1 | 30 | 60 | Self | 1 | 30c | C(0,4) | Player | Active. Increases physical damage by 10% for 60 turns and instantly generates 10 rage. 30-turn cooldown. |
| Death Wish | - | - | - | - | - | 2 | 45c | - | - | Passive. As health falls, gain physical damage and take more damage: scales smoothly from no bonus at full health to +20% physical damage dealt and +10% damage taken at 25% health. Both bonuses stay capped below 25%. Healing immediately reduces both effects. Applies in every class once learned. |
| Anger Management | - | - | - | - | - | 2 | 60c | - | - | Passive. out-of-combat rage decay becomes 0.5 per turn. Retained across Loops. |
| Weapon Mastery | - | - | - | - | - | 2 | 90c | - | - | Passive. +10 percentage points of critical chance through the shared attack profile, including physical and direct Holy/Fire/Nature attacks. Enemies have -2.5% chance to dodge your weapon attacks, including either hand, physical abilities and bonus weapon strikes: a flat 2.5 percentage-point reduction, minimum 0% (standard 5% becomes 2.5%). Does not prevent misses. Retained learning works in every class. |
| Charge | 0 | * | 10* | - | 2-9* | 3 | 120c | C(0,3) | Player (arrival) | Active movement. Wind up for 1 turn, then travel up to 4 path tiles per turn to a reachable empty melee tile. Holds the target in place until arrival; cannot act or cancel. Arrival generates 10 rage and allows a ready ordinary swing. Base 10-turn cooldown starts on arrival; Juggernaut reduces it to 8 and readies a Mortal Strike crit. Player sprite flashes on arrival. |
| Execute | 15-30* | 1 | - | - | 1 | 3 | 210c | - | - | Active physical attack. Requires a melee target at or below 20% health and at least 15 rage. Spends current rage up to 30 for 150% weapon damage + 25 + 2 damage per rage above 15. Misses spend rage. Sudden Death allows one use at any health with the same rage spending and damage scaling. Preserves Battle Trance. No cooldown; weapon timing continues. A landed hit may build points; spends none. No dedicated effect sprite. |
| Battle Trance | - | - | - | * | - | 4 | 250c | - | - | Passive. Direct physical, Holy, Fire and Nature active crits make the next Mortal Strike, Judgement, Lava Burst or Eviscerate free until used. Other abilities preserve the proc. Finishers cannot trigger it. |
| Victory Rush | - | - | 6* | - | - | 4 | 285c | - | - | Passive. Nonfriendly enemy deaths heal 10% of maximum health, rounded down, including kills by damage effects or summons. All qualifying kills share a 6-turn internal cooldown; further kills during it do not heal. Overhealing also starts the cooldown. Uses the resolved death turn across action and periodic phases; Restless Blades cannot shorten it. Cooldown survives saves and clears on death. Summons dying and friendly actors do not qualify. Terminal victory/death stops further rewards. |
| Shield Block | - | - | - | - | - | 4 | 320c | - | - | Passive. With a shield equipped, each damaging physical hit independently has a 30% chance to prevent 70% of damage remaining after armor, Death Wish and banner protection. Remaining damage rounds up to at least 1 HP. Includes critical hits, with no per-turn cap or cooldown. Does not protect summons, block magic or roll on misses, dodges or immune hits. Partial blocks retain incoming-hit rage and eligibility for Enrage and Lightning Shield. Combat log reports prevented damage; no effect sprite. Retained learning works in every class and below its learning level. |
| Sweeping Strikes | - | - | - | - | 1 (secondary target) | 5 | 370c | - | - | Passive. Landed single-target direct physical actives copy 50% of their damage to one other hostile enemy in melee. Whirlwind cannot trigger copies. Copies cannot proc, crit or generate rage/combo points. |
| Sudden Death | - | - | - | * | - | 5 | 405c | - | - | Passive. Landed direct physical active attacks other than Execute have a 20% chance to allow one Execute at any health until used. The attack still requires at least 15 rage and spends current rage up to 30, with normal extra-rage damage. Auto-attacks and bonus damage cannot trigger it. |
| Wrecking Crew | - | - | - | 10 | - | 5 | 450c | - | - | Passive. Primary physical crits grant +25% physical damage for 10 turns. While active, Whirlwind deals an additional 35% more damage, multiplying its weapon coefficient separately from the shared physical buff. Refreshes without stacking; both bonuses end with the buff. |
| Juggernaut | - | - | - | * | - | 5 | 495c | - | - | Passive. Charge cooldown falls from 10 to 8 turns; arrival guarantees the next landed Mortal Strike crit until consumed or death. A miss/dodge does not consume it. |

### Trainer gift: War Horn

Llane's War Horn is a reusable bag item, automatically placed in an empty hotbar slot
when available; Bags also allows use and hotbar assignment.
Its free two-turn cast deals exactly 1 guaranteed
damage to each living neutral/hostile NPC whose tile is on the current screen and in
line of sight, engaging them. Chests and friendly actors are excluded. It preserves the
attack target, grants no attack procs or combo points, and ignores armor and damage
bonuses. Weapon timers and enemy actions continue during casting; cancellation gives
no effect or cooldown. Its 30-turn cooldown starts on completion and is not reduced by
Restless Blades. Saves retain its cooldown.

## Shaman

**Tagline: Bank the storm in your weapons, then release it in a burst of fire.**

Shield and weapon preparation, reactive Nature damage and a banked Fire payoff.
Physical hits build Maelstrom to shorten and strengthen Lava Burst. Feral Spirit
summons wolves whose attacks heal you.

| Name | Rage cost | Cast time | Cooldown | Duration | Range | Level required to learn | Cost to learn | Sprite used for effect | Sprite placement (player / target / area) | Description |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lava Burst | 10 | 3* | 6 | - | 6 | 1 | 0 | C(3,3), orange tint | Target (landed impact) | Active Fire attack. 48 base damage independent of weapons/Strength; hit/crit, buffs and level differences apply, armor does not. No interrupt or stun. With Maelstrom: 0-1 stacks take 3 turns, 2-4 take 2, 5 is instant (one world action); +10 percentage points of critical chance per reserved stack. Snapshots stacks/time at start; spends reserved stacks on successful completion, including a miss. No fractional casting credit is consumed or generated. Landed attacks can grant direct-spell combo/critical rewards. |
| Lightning Shield | 0 | 1 | - | 30* | Self | 1 | 0 | C(3,2) | Player (application) | Active self buff. Six charges of 15 base Nature damage for 30 turns, ending early when exhausted. Surviving damaging enemy hits discharge at most once per 3 turns, with no distance check on the attacker. Static Shock can spend charges offensively without the retaliation cooldown. Refreshing replaces the shield. Player sprite appears on application; no separate discharge sprite. |
| Flurry | - | - | - | * | - | 2 | 90c | - | - | Passive. Primary physical crits grant or refresh 3 charges of +30% attack haste until consumed or death. Ordinary main/off-hand swing attempts each consume a charge, including misses. |
| Windfury Weapon | 0 | 1 | * | 60 | Self | 2 | 135c | C(3,1) | Target (bonus hit) | Active main-hand enchant for 60 turns, tied to the equipped weapon setup. No cast cooldown; the proc has an internal cooldown. Landed primary main-hand physical swings/actives have a 25% chance for 2 bonus strikes, at most once per 3 turns. Each deals 140% weapon damage, using normal hit/armor but no crits, further procs, rage or points. No application sprite; landed bonus strikes flash the target. |
| Maelstrom Weapon | - | - | - | * | - | 2 | 270c | - | - | Passive. The first landed primary physical attack per committed world action grants 1 stack, up to 5: ordinary main/off-hand hits and direct physical actives, including finishers. No bonus/proc/summon damage. Stacks bank across encounters and saves, clear on death. Shortens Lava Burst and adds +10 percentage points of critical chance per stack; five makes it instant. Reserved stacks stay counted against the cap until successful completion; only the reserved count is spent, preserving new gains. Cancelled or invalid completions preserve stacks. New gains do not accelerate a pending cast. |
| Static Shock | - | - | - | - | - | 3 | 180c | - | - | Passive. Landed primary physical attacks, including main/off-hand swings and direct physical actives, have a 20% chance to discharge an active Lightning Shield charge, ignoring its retaliation cooldown. |
| Feral Spirit | 25 | 1 | 30 | 12* | 1 (placement)* | 4 | 390c | R(7,4), wolf | Area (summoned actors)* | Active summon. Requires 2 free or replaceable adjacent tiles. Replaces existing wolves with 2 wolves for 12 turns or until killed. Each has 50 health, attacks every 2 turns and snapshots 75% of weapon damage/power at summoning. Follows the selected enemy, otherwise returns to you; can be attacked and grants no XP/rage/points. Each wolf hit inherently heals you for 50% of actual damage dealt, rounded down, excluding overkill; terminal victory/death stops healing. Sprites are the summoned actors. |
| Toughness | - | - | - | - | - | 5 | 480c | - | - | Passive. +20% armor. |

### Class feedback and targeting

Learning Maelstrom Weapon reveals a purple bar below combo points in every class.
Its three cells have widths in a 1:3:1 ratio: stacks fill continuously from zero to
five, completing the first cell at one stack, the middle at four, and the last at
five. Like combo points, it uses 20% opacity at zero and 80% with stacks, and follows
gameplay HUD visibility. Lava Burst's tooltip also shows current stacks; there is
no duplicate Maelstrom aura. Lava Burst opens target selection unless exactly one
enemy is valid and already engaged, allowing deliberate ranged pulls even while
another enemy is engaged. Selection and cancellation spend no turn.

### Trainer gift: Ancestral totem

Farseer Lopaa's Ancestral totem summons an Earth Elemental from Bags or the hotbar.
It costs no rage, takes one turn, and consumes the item only on a successful summon.
There is no cooldown. Blocked adjacent placement or a living elemental rejects use
without spending the item or a turn. The elemental has 40 health and no expiration.
It follows you or an engaged hostile, taunts already engaged
hostiles within 4 tiles and sight of itself, and attacks for 2-4 physical damage every
2.5 turns. Its actor uses C(3,4) as its health-tinted base, with an empty faction layer.
Saves retain the summoned actor; death clears it.

## Paladin

**Tagline: Carry a lasting seal, commit your verdict, and make your ground holy.**

Seal of Command adds Holy damage to main-hand swings, Judgement commits a delayed
verdict, and Consecration damages enemies on fixed Holy ground. Art of War empowers
Judgement; Divine Shield trades outgoing damage for immunity.

| Name | Rage cost | Cast time | Cooldown | Duration | Range | Level required to learn | Cost to learn | Sprite used for effect | Sprite placement (player / target / area) | Description |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Judgement | 20 | 1 | 6 | 3 (delay)* | 2 | 1 | 0 | C(1,1) | Target (application and impact) | Active delayed Holy attack. Requires an equipped weapon setup, learned Seal of Command and an engaged/selected enemy within 2 tiles not already judged. Fixes hit/crit and damage at cast: 150% weapon damage plus 35. A landed cast delivers after 3 further turns, ignoring later range/armor; lost if the target dies first. Rewards/procs occur once on impact without retargeting. Battle Trance can make it free. Haste does not shorten cooldown. Target flashes on application and impact, with a countdown between. |
| Seal of Command | - | - | - | - | - | 1 | 0 | - | - | Learned passive. Landed ordinary main-hand swings with an equipped weapon add 25% weapon damage as Holy. No application, refresh, cost or timer. Bonus damage grants no rage or combo points and cannot recursively trigger weapon procs; it can advance Art of War once per action. Required for Judgement. |
| Blessing of Kings | - | - | - | - | - | 2 | 70c | - | - | Passive upgrade to Battle Shout. While learned Battle Shout is active, add +2 Strength, Agility and Stamina. Requires Shout learning; no separate cast or rage. Learning Kings during an existing Shout applies immediately. Bonus is derived from active Shout, clears on expiry/death and does not heal on learning, application or refresh. |
| Conviction | - | - | - | - | - | 2 | 100c | - | - | Passive. +3 percentage points of critical chance for weapon/physical and direct Holy/Fire/Nature attacks. |
| Art of War | - | - | - | * | - | 3 | 135c | - | - | Passive. Every third landed primary Holy event empowers the next Judgement to critically hit for 225% damage until used or death. Ordinary random criticals remain 200%; the empowered damage is fixed at cast. Progress does not expire; at most one event counts per world-turn action, including Seal damage. Judgement contributes on impact. A missed Judgement cast does not consume the critical proc. |
| Vengeance | - | - | - | 10 | - | 3 | 170c | - | - | Passive. Primary attack crits grant +3% damage per stack, up to 3 stacks (+9%), for 10 turns. Further primary crits refresh the duration. |
| Consecration | 5 | 1 | 12 | 6 | 1 | 3 | 200c | C(1,2) | Area (fixed 3x3, excluding player tile visually) | Active. Consecrate the fixed 3x3 area around you for 6 turns, replacing your previous ground. Each turn deals 7.5 + 6% weapon damage as Holy to visible neutral or hostile enemies inside. Damage is fixed when cast; no crits, combo points or attack procs. Ticks begin this turn before weapon swings and enemy actions. Each tick replays the 1.5-second ground flash; the player's current tile always keeps its player art. No damage reduction; one turn. |
| Divine Shield | 20 | 1 | 30* | 3* | Self | 3 | 200c | C(1,4) | Player | Active self buff. Immune to incoming damage for 3 turns; deal 30% less damage while active. Guardian's Favor changes duration to 4 turns and cooldown from 30 to 20. Weapon timing continues. |
| Heart of the Crusader | - | - | - | * | - | 4 | 235c | - | - | Passive. Judgement's landed verdict leaves its living target vulnerable until your next landed ordinary melee strike (either hand) or physical melee ability. That strike adds 25% of the striking hand's weapon damage as Holy, bypassing armor and using current damage buffs and level differences; off-hand damage uses its normal 50%/75% penalty. No additional crit roll, rage, combo points, Art of War progress or attack procs. Misses, dodges, ranged attacks, bonus strikes and summons do not consume it. Refreshes without stacking, persists until used or target death, and is saved. |
| Pursuit of Justice | - | - | - | - | - | 4 | 305c | - | - | Passive. +20% movement credit: periodically move an extra tile in the chosen direction, stopping at obstacles. |
| Guardian's Favor | - | - | - | - | - | 5 | 370c | - | - | Passive. Divine Shield cooldown is 10 turns shorter and its duration is 1 turn longer. |

### Trainer gift: Wartorn Banner

Brother Sammuel's Wartorn Banner is a single-use item costing no rage and taking one
turn from Bags or the hotbar. It plants on the first free adjacent tile in the normal
clockwise placement order; blocked placement
preserves the item and turn. The banner is a nonblocking, untargetable ground marker
with a visible range outline. For 10 turns, including its placement turn, the player and
living friendly summons within 3 tiles (square distance) take 10% less incoming damage.
Range is checked at each hit without a sight requirement. Protection combines with
existing mitigation, rounds the final damage up, and never turns a positive hit into
immunity. Leaving range removes protection immediately; entering restores it. Town NPCs
and enemies receive no protection. The HUD shows remaining time and whether the player
is in range. The banner expires before attacks on its expiry boundary. Saves retain
its planted position and expiry; death clears the planted banner.

## Rogue

**Tagline: Build momentum, vanish to reposition, then strike with a finisher.**

Build player-held combo points and spend rage on Eviscerate for damage and passive
haste. Dual-wield rewards and mixed poisons support sustained attacks;
Vanish allows repositioning and a stronger opening without dropping combat.

| Name | Rage cost | Cast time | Cooldown | Duration | Range | Level required to learn | Cost to learn | Sprite used for effect | Sprite placement (player / target / area) | Description |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Eviscerate | 15 | 1 | - | - | 1 | 1 | 0 | C(2,1) | Target | Active. Requires a melee target and at least 1 combo point. Spend all held points for (75% weapon damage + 4) per point as physical damage; five points deal 375% weapon damage + 20. Hit/crit and armor apply; misses still spend points. Learned Slice and Dice adds haste from those spent points, even on a miss. Builds no attack points. One turn, no cooldown; weapon timing continues. |
| Relentless Assault | - | - | - | * | - | 1 | 0 | - | - | Passive. Landed Mortal Strike, Execute, Lava Burst and Judgement grant 1 player-held combo point, up to 5, across classes and targets. At most 1 base point per turn, shared with Combat Potency. Other attacks, off-hand hits, procs, buffs and misses grant none. Points reset on death. |
| Slice and Dice | - | - | - | * | - | 1 | 10c | - | - | Passive finisher upgrade. Eviscerate grants +30% attack haste for 5 + 3 turns per point spent (8-20 turns), even on a miss. Refreshes without stacking. No extra rage/action; cannot be cast/assigned separately. |
| Ambidexterity | - | - | - | - | - | 2 | 60c | - | - | Passive. Raises off-hand weapon damage from 50% to 75% in any class. Off-hand swings grant no ordinary rage. |
| Evasion | 15 | 1 | 20 | 5 | Self | 2 | 90c | C(2,3) | Player | Active. +40% dodge for 5 turns, in every direction. Costs one action. |
| Combat Potency | - | - | - | - | - | 3 | 120c | - | - | Passive. Landed ordinary off-hand swings have a 20% chance to grant 5 rage. With learned Relentless Assault, landed ordinary main-hand swings have a 30% chance to grant 1 combo point, sharing its one-base-point-per-turn cap. |
| Seal Fate | - | - | - | - | - | 3 | 150c | - | - | Passive. Requires learned Relentless Assault. Landed Mortal Strike, Execute, Lava Burst and Judgement crits grant 1 additional player-held point, up to 5, even if the base point for the turn was already granted. Finishers and bonus strikes do not qualify. |
| Main Gauche | - | - | - | - | - | 3 | 190c | - | - | Passive. Landed ordinary main-hand swings have a 15% chance for one strike at 100% of the off-hand damage profile, including its normal 50%/75% damage multiplier. Requires an off-hand weapon; normal hit/armor apply, with no crits, recursive procs, rage or combo points. |
| Vanish | 0 | 1 | 20 | 4* | Self | 3 | 200c | Current class sprite at 40% opacity | Player | Active. Conceal for 4 turns or until a deliberate melee attack (including bump) or any ability. Movement/waiting preserve it and suppress your automatic swings. Engaged enemies retarget living summons with normal swing timing; without a summon they pursue the Vanish tile without attacking or losing engagement. They cannot track hidden movement. Normal collision applies. The opening swing/ability gains +50 percentage points of crit, including retained class attacks; non-damaging abilities also consume it. Invalid attempts preserve it. Casts break concealment at start; completion keeps the bonus, cancellation loses it. Independent 20-turn cooldown, matching Evasion; Restless Blades can shorten it. No separate flash sprite; the current class art becomes translucent for the effect. |
| Deadly Poison | 0 | 1 | - | * | Self | 4 | 230c | C(2,2), C(2,4) | Player (coating); target (proc) | Active coating. Choose hands as for Instant Poison; each coating lasts 60 turns, replacing only the selected hand's poison. Landed primary physical attacks have a 30% chance to apply a stack. Up to 5 shared stacks per enemy deal 1.5 base Nature damage each per turn for 12 turns. Applications refresh duration without delaying ticks; fractional damage is retained across ticks. No crits/proc chains. Ticks precede swings and enemy actions, including the final tick. Player flashes at coating time; successful stack applications flash the enemy with C(2,4). Periodic ticks do not restart the flash. |
| Instant Poison | 0 | 1 | - | 60* | Self | 4 | 230c | C(2,2), C(2,4) | Player (coating); target (proc) | Active coating. Choose main hand, off hand or both with dual wield; single-weapon setups coat main hand directly. Each hand has its own 60-turn timer; replacing its poison leaves the other hand unchanged. Landed primary physical attacks with a coated hand have a 30% chance to add 8 base Nature damage. No crits or recursive procs; bonus strikes cannot trigger it. Catalytic Venom can add a Deadly stack. Player flashes on coating application; successful procs flash the enemy with C(2,4). |
| Restless Blades | - | - | - | - | - | 4 | 270c | - | - | Passive finisher reward. After Eviscerate spends points, including on a miss, reduce every currently recorded ability cooldown by ceiling(points spent / 2) turns, never below ready now. Includes preparation and summon cooldowns as well as offensive/defensive abilities. |
| Catalytic Venom | - | - | - | - | - | 5 | 310c | - | - | Passive. While dual wielding with active Instant and Deadly Poison on opposite hands, each Instant proc also applies one Deadly stack regardless of weapon speeds. No extra roll or recursive procs. |
| Bandit's Guile | - | - | - | 10 | - | 5 | 370c | - | - | Passive. Every 4 qualifying landed direct active attacks grant +5% damage, stacking to +15%. Each qualifying hit refreshes the 10-turn state, including partially built progress. Misses and finishers do not advance it. Retained class attacks qualify. |
| Precision | - | - | - | - | - | 5 | 430c | - | - | Passive. Weapon/physical and direct Holy/Fire/Nature attacks never miss, including against higher-level enemies. Enemies may still dodge weapon attacks; Weapon Mastery reduces their dodge chance by 2.5 percentage points. |

### Vanish interactions

During Vanish, engaged enemies exclude you from targeting and pursue living summons,
using elemental taunt first, then the highest summon threat (even zero threat).
Retargeting preserves remaining swing delay and normal fractional swing timing.
With no living summon, enemies approach the tile where you vanished and hold around
it without attacking; swing timers advance inactive without banking attacks.
They retain threat and engagement even if that remembered tile is unreachable, then
resume normal targeting when Vanish ends. Idle enemies cannot spot the concealed
player, but can still notice wolves; the elemental's presence does not pull them.
Existing poison/ground damage and summons continue acting without ending Vanish.
Stalkers can start Fel Breath against summons; an already announced breath completes
and can hit anyone inside its cone. Terrain and occupied tiles still block movement.

### Trainer gift: Lucky charm

Jorik's Lucky charm works passively from Bags: a hit that would kill the living player
leaves them at 1 HP and replaces the charm in its bag slot with Broken lucky charm, which has
no effect. No cast, hotbar assignment or cooldown is involved. The charm prevents only
that hit; another hit, including later in the same turn, can kill the player. Absorbed,
missed and nonlethal hits do not break it, and it does not prevent the Development Death
trigger. Both intact and broken forms persist through saves and clear on death.

## Implementation locations

| Looking for | Start in |
| --- | --- |
| Ability definitions, tuning and training prices | [ClassSkillData](../scripts/hero/class_skill_data.gd) and [ClassToolkitData](../scripts/hero/class_toolkit_data.gd); merged by [SkillDefinition](../scripts/hero/skill_definition.gd) |
| Casting, turns and cooldowns | [GridWorld](../scripts/world/grid_world.gd) |
| Player stats, resources and learning | [HeroState](../scripts/hero/hero_state.gd) |
| Costs and attack procs | [SkillCost](../scripts/combat/skill_cost.gd), [AttackProcs](../scripts/combat/attack_procs.gd) |
| Class effects and reactive defenses | [ClassToolkitRules](../scripts/combat/class_toolkit_rules.gd), [ClassSpellEffects](../scripts/combat/class_spell_effects.gd) |
| Paladin effects, poisons and summons | [PaladinRules](../scripts/combat/paladin_rules.gd), [PoisonRules](../scripts/combat/poison_rules.gd), [SummonRules](../scripts/combat/summon_rules.gd) |
| Effect sprites and placement | [GridView](../scripts/world/grid_view.gd) |
