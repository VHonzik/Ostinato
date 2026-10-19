# Current class mechanics and abilities

This is the authoritative human-readable reference for the **implemented** class kits,
including current training prices, tuning and effect art. [Direction](direction.md)
covers intended design; [the backlog](backlog.md) tracks unfinished work. The taglines
below summarize current mechanics; they are reference copy, not quotations from an
in-game class screen. Balance and prices remain provisional. Update this reference
and the implementation together.

## Reading the tables

- Each class has one table containing active and passive abilities, identified in the
  description. Sort order is level required to learn, copper cost, then name for ties.
- `-` means not applicable: no passive cast, no ability cooldown, no timed duration
  for an immediate hit/permanent modifier, or no dedicated effect sprite. `0` rage
  means a free active that still spends its action.
- `*` marks mechanics explained in the description: variable costs, travel, charges,
  delayed effects, passive procs, modified cooldowns/durations, or summon placement.
- Cast time, cooldown and duration use **world turns**, including source fields named
  `seconds`. Cast time `1` spends one turn. Durations describe gameplay, not the visual
  flash. Cooldowns show base values; learned upgrades are explained where marked.
  Restless Blades can also reduce every running ability cooldown.
- Range is in grid tiles; diagonals count as one tile (square/Chebyshev distance).
  `Self` means a self cast. Enemy casts require a living nonfriendly target in range
  and sight. Passive range is `-` unless it has a separate spatial limit; the
  triggering ability retains its own range rules.
- Learning costs use copper (`c`): 100c = 1 silver; 10,000c = 1 gold. `0` means free.
  Starter rows show level 1, the character's minimum level, with no additional gate.
- Sprite `C(x,y)` is the zero-based column/row of a 16x16 cell in
  [characters.png](../assets/spritesheets/characters.png), editable in
  [characters.aseprite](../art/characters.aseprite). `R(x,y)` uses the same convention
  in [scroolospritescharacters_nobg.png](../assets/spritesheets/scroolospritescharacters_nobg.png).
  Pixel rectangle is `(16x, 16y, 16, 16)`; the world draws it at 32x32.
- Sprite placement describes actual rendering, separately from the gameplay target.
  Most ability sprites briefly replace the player/struck enemy for 1.5 real seconds.
  Whirlwind flashes landed targets, not a whole area. Consecration briefly covers
  its ground tiles, including occupants; its visual does not last the damage duration.
  Summon art is a world actor, not an overlay. Passives add no dedicated effect sprite;
  upgraded actives retain their own art. `-` does not exclude aura text, combat numbers
  or other shared UI. These are default mappings; GridView allows actor-art overrides.

## Shared mechanics

New Game starts as Warrior knowing Mortal Strike and Whirlwind. From Loop two, choose
Warrior, Shaman, Paladin or Rogue at the marshal before accepting quests. Selection
locks training to that class until death. Trainers are Llane (Warrior), Farseer Lopaa
(Shaman), Brother Sammuel (Paladin) and Jorik Kerridan (Rogue). Other starter pairs
are free level-1 trainer purchases. Later purchases require the listed current-Loop
level and money, without prerequisite purchases or spending XP. Learned actives and
passives persist across deaths and work in every class, even below their original
training level. Passives cannot be cast/assigned to the hotbar. All gear is usable
in every class without learning or level requirements.

All classes use rage, capped at 100. Ordinary main-hand swing attempts generate 7 rage
per turn of the weapon's base interval, independent of haste and hit result. Damaging
incoming hits grant 3 rage at most once per world turn. Ordinary off-hand swings and
bonus strikes generate no baseline rage. Outside combat, rage decays by 2 per turn,
or 0.5 with Anger Management; fractional rage is retained internally.

Table rage costs are base costs. Battle Trance makes the next rage-costing active free.
Execute first uses Sudden Death if ready; otherwise Battle Trance applies to
rage-costing actives, including Judgement. Only the chosen free-use proc is consumed. Consumable
procs/charges persist until spent or death, including between encounters. Timed buffs
continue counting down outside combat.

Weapon damage uses the main hand and Strength-derived weapon power unless specified
otherwise. Physical attacks use hit, dodge, critical and armor rules. Direct Holy/Fire/Nature
attacks use hit/critical rules and bypass armor. Level differences and applicable buffs
still modify listed base damage. Haste changes independent hand swing timers, not action
count or ability cooldowns. Restless Blades can reduce running cooldowns.
Swing timing continues through abilities, movement and waiting, attacking the committed
enemy when in melee. Retargeting keeps the remaining swing delay.

The committed action resolves before the turn advances. At the advanced turn boundary,
timed hero buffs, summons and ordinary debuffs expire, then Judgement,
Consecration and Deadly Poison resolve, followed by due player swings and enemy actions.
Final verdicts/poison ticks are preserved. Terminal death/victory stops further resolution.
Death clears temporary combat state, summons, coatings, ground and combo points, retaining
learning. Saves retain implemented mid-Loop effect state, including banked Maelstrom.
Current saves use revision 32; earlier revisions are incompatible and left unchanged.
The catalogue has 32 passives. Folded effects are intrinsic to their parent abilities,
with the parents' learning levels/prices unchanged; there are no replacement purchases.
Eviscerate refunds rage after spending, including on a miss, and never refunds points.

Primary attacks are ordinary swings and direct active attacks. Primary physical crits,
including physical active crits, can trigger Flurry and Wrecking Crew.
Finishers still qualify for these critical buffs and Vengeance, but cannot build points,
advance Bandit's Guile, or trigger Battle Trance. Bonus strikes/copies, seal damage,
poison, ground and reactive damage do not recursively enter the primary attack pipeline.
With Relentless Assault, points belong to the player across targets/encounters, capped
at five, with at most one base point per world turn. Seal Fate can add points on qualifying
active crits. Eviscerate alone spends combo points; Execute and Judgement do not.

## Warrior

**Tagline: Turn pain into rage, then spend it on decisive physical blows.**

Physical burst, adjacent cleave, rage preparation, a travel opener and low-health
execution. Enrage rewards taking hits; Recklessness raises damage and risk as health
falls. Mortal Strike is the larger single-target spender; Whirlwind gains value against
groups. Wrecking Crew strengthens developed Whirlwind while its critical buff lasts;
Sweeping Strikes copies single-target actives only. Victory Rush keeps its full kill
heal with a shared internal cooldown, limiting healing from large pulls.

Completing all Warrior training unlocks Llane's War Horn gift dialogue once each Loop,
regardless of the currently selected class. Booming Shout is removed. War Horn is a
reusable bag item, automatically placed in an empty hotbar slot when available; Bags
also allows use and hotbar assignment. Its free two-turn cast deals exactly 1 guaranteed
damage to each living neutral/hostile NPC whose tile is on the current screen and in
line of sight, engaging them. Chests and friendly actors are excluded. It preserves the
attack target, grants no attack procs or combo points, and ignores armor and damage
bonuses. Weapon timers and enemy actions continue during casting; cancellation gives
no effect or cooldown. Its 30-turn cooldown starts on completion and is not reduced by
Restless Blades. The item and claim reset on death, so retained Warrior learning allows
a new gift next Loop. The horn, claim and cooldown persist through mid-Loop saves.

| Name | Rage cost | Cast time | Cooldown | Duration | Range | Level required to learn | Cost to learn | Sprite used for effect | Sprite placement (player / target / area) | Description |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mortal Strike | 30 | 1 | 4 | - | 1 | 1 | 0 | C(0,1) | Target | Active physical attack. Deals 200% weapon damage. A learned Juggernaut charge guarantees the next landed Mortal Strike crit and is then consumed. |
| Whirlwind | 15 | 1 | - | - | 1 | 1 | 0 | C(0,2) | Targets (each landed hit) | Active. 70% weapon damage to each adjacent neutral or hostile enemy in sight (3x3 area), in stable actor order. One turn, no cooldown; weapon timing continues. Wrecking Crew adds 35% more Whirlwind damage while its buff is active. Each landed hit can crit/proc, but cannot trigger Sweeping Strikes; Relentless Assault grants at most one base point per turn. Keeps your selected attack target. Stops on terminal death. |
| Enrage | - | - | - | 10 | - | 1 | 15c | - | - | Passive proc. Surviving damaging enemy hits have a 30% chance for +10% physical damage and +5 percentage points of attack critical chance for 10 turns, at any health. At most one roll per world turn. Refreshes without stacking; misses, dodges and immune hits cannot trigger it. |
| Battle Shout | 0 | 1 | 30 | 60 | Self | 1 | 30c | C(0,4) | Player | Active. Increases physical damage by 10% for 60 turns and instantly generates 10 rage. 30-turn cooldown. |
| Recklessness | - | - | - | - | - | 2 | 45c | - | - | Passive. As health falls, gain physical damage and take more damage: scales smoothly from no bonus at full health to +20% physical damage dealt and +10% damage taken at 25% health. Both bonuses stay capped below 25%. Healing immediately reduces both effects. Applies in every class once learned. |
| Anger Management | - | - | - | - | - | 2 | 60c | - | - | Passive. out-of-combat rage decay becomes 0.5 per turn. Retained across Loops. |
| Cruelty | - | - | - | - | - | 2 | 90c | - | - | Passive. +10 percentage points of critical chance through the shared attack profile, including physical and direct Holy/Fire/Nature attacks. |
| Charge | 0 | * | 10* | - | 2-9* | 3 | 120c | C(0,3) | Player (arrival) | Active movement. Wind up for 1 turn, then travel up to 4 path tiles per turn to a reachable empty melee tile. Holds the target in place until arrival; cannot act or cancel. Arrival generates 10 rage and allows a ready ordinary swing. Base 10-turn cooldown starts on arrival; Juggernaut reduces it to 8 and readies a Mortal Strike crit. Player sprite flashes on arrival. |
| Execute | 15-30* | 1 | - | - | 1 | 3 | 210c | - | - | Active physical attack. Requires a melee target at or below 20% health and at least 15 rage. Spends current rage up to 30 for 150% weapon damage + 25 + 2 damage per rage above 15. Misses spend rage. Sudden Death allows a free use at any health with no extra-rage damage; Battle Trance makes it free but keeps the health gate. No cooldown; weapon timing continues. A landed hit may build points; spends none. No dedicated effect sprite. |
| Battle Trance | - | - | - | * | - | 4 | 250c | - | - | Passive. Direct physical, Holy and Nature active crits make the next rage-costing active free until used. Finishers cannot trigger it. |
| Victory Rush | - | - | 6* | - | - | 4 | 285c | - | - | Passive. Nonfriendly enemy deaths heal 10% of maximum health, rounded down, including kills by damage effects or summons. All qualifying kills share a 6-turn internal cooldown; further kills during it do not heal. Overhealing also starts the cooldown. Uses the resolved death turn across action and periodic phases; Restless Blades cannot shorten it. Cooldown survives saves and clears on death. Summons dying and friendly actors do not qualify. Terminal victory/death stops further rewards. |
| Sweeping Strikes | - | - | - | - | 1 (secondary target) | 5 | 370c | - | - | Passive. Landed single-target direct physical actives copy 50% of their damage to one other hostile enemy in melee. Whirlwind cannot trigger copies. Copies cannot proc, crit or generate rage/combo points. |
| Sudden Death | - | - | - | * | - | 5 | 405c | - | - | Passive. Landed direct physical active attacks other than Execute have a 20% chance to allow one free Execute at any health until used. Auto-attacks and bonus damage cannot trigger it. The proc Execute spends no extra rage. |
| Wrecking Crew | - | - | - | 10 | - | 5 | 450c | - | - | Passive. Primary physical crits grant +25% physical damage for 10 turns. While active, Whirlwind deals an additional 35% more damage, multiplying its weapon coefficient separately from the shared physical buff. Refreshes without stacking; both bonuses end with the buff. |
| Juggernaut | - | - | - | * | - | 5 | 495c | - | - | Passive. Charge cooldown falls from 10 to 8 turns; arrival guarantees the next landed Mortal Strike crit until consumed or death. A miss/dodge does not consume it. |

## Shaman

**Tagline: Bank the storm in your weapons, then release it in a burst of fire.**

Free shield/weapon preparation, reactive Nature damage and a banked Fire payoff.
Lava Burst deals flat damage independent of weapons or Strength, shortened and given
extra critical chance by Maelstrom Weapon. The Ancestral totem item supplies a lasting
elemental that redirects engaged enemies; temporary wolves inherently add damage
and healing. Earth Shock, its interrupt/stun upgrade and Elemental Assault
are removed. Flurry remains early training; Maelstrom is available at level 2.

Earth Elemental is removed from training. After learning all remaining Shaman actives
and passives, Farseer Lopaa offers Ancestral totem through the shared trainer farewell
dialogue once per Loop, in any selected class. Use it from Bags or its hotbar shortcut:
it costs no rage, takes one turn, and consumes the item only on a successful summon.
There is no cooldown. Blocked adjacent placement or a living elemental rejects use
without spending the item or a turn. The elemental keeps the former ability's behavior:
40 health, no expiration, follows you or an engaged hostile, taunts already engaged
hostiles within 4 tiles and sight of itself, and attacks for 2-4 physical damage every
2.5 turns. Its actor uses [earth_elemental.svg](../assets/sprites/dev/earth_elemental.svg).
Saves retain the unspent item, gift claim, and summoned actor independently of learned
skills. Death clears the item, summon and claim; retained learning allows a new gift.

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

## Paladin

**Tagline: Carry a lasting seal, commit your verdict, and make your ground holy.**

Holy damage on main-hand swings, a committed delayed verdict and fixed damaging ground.
Art of War empowers later Judgements with a stronger guaranteed critical. Passive Seal needs no
maintenance. Blessing of Kings adds primary stats to Battle Shout; Divine Shield
trades outgoing damage for immunity.

Completing all Paladin training unlocks Brother Sammuel's Wartorn Banner gift through
the shared trainer farewell dialogue, once each Loop in any selected class. This
single-use item costs no rage and takes one turn from Bags or the hotbar. It plants on
the first free adjacent tile in the normal clockwise placement order; blocked placement
preserves the item and turn. The banner is a nonblocking, untargetable ground marker
with a visible range outline. For 10 turns, including its placement turn, the player and
living friendly summons within 3 tiles (square distance) take 10% less incoming damage.
Range is checked at each hit without a sight requirement. Protection combines with
existing mitigation, rounds the final damage up, and never turns a positive hit into
immunity. Leaving range removes protection immediately; entering restores it. Town NPCs
and enemies receive no protection. The HUD shows remaining time and whether the player
is in range. The banner expires before attacks on its expiry boundary. Saves retain
the unspent item, planted position, expiry and claim; death clears all and permits a
new gift with retained learning. It does not change any learned Paladin ability.

| Name | Rage cost | Cast time | Cooldown | Duration | Range | Level required to learn | Cost to learn | Sprite used for effect | Sprite placement (player / target / area) | Description |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Judgement | 20 | 1 | 6 | 3 (delay)* | 2 | 1 | 0 | C(1,1) | Target (application and impact) | Active delayed Holy attack. Requires an equipped weapon setup, learned Seal of Command and an engaged/selected enemy within 2 tiles not already judged. Fixes hit/crit and damage at cast: 150% weapon damage plus 35. A landed cast delivers after 3 further turns, ignoring later range/armor; lost if the target dies first. Rewards/procs occur once on impact without retargeting. Battle Trance can make it free. Haste does not shorten cooldown. Target flashes on application and impact, with a countdown between. |
| Seal of Command | - | - | - | - | - | 1 | 0 | - | - | Learned passive. Landed ordinary main-hand swings with an equipped weapon add 25% weapon damage as Holy. No application, refresh, cost or timer. Bonus damage grants no rage or combo points and cannot recursively trigger weapon procs; it can advance Art of War once per action. Required for Judgement. |
| Blessing of Kings | - | - | - | - | - | 2 | 70c | - | - | Passive upgrade to Battle Shout. While learned Battle Shout is active, add +2 Strength, Agility and Stamina. Requires Shout learning; no separate cast or rage. Learning Kings during an existing Shout applies immediately. Bonus is derived from active Shout, clears on expiry/death and does not heal on learning, application or refresh. |
| Conviction | - | - | - | - | - | 2 | 100c | - | - | Passive. +3 percentage points of critical chance for weapon/physical and direct Holy/Fire/Nature attacks. |
| Art of War | - | - | - | * | - | 3 | 135c | - | - | Passive. Every third landed primary Holy event empowers the next Judgement to critically hit for 225% damage until used or death. Ordinary random criticals remain 200%; the empowered damage is fixed at cast. Progress does not expire; at most one event counts per world-turn action, including Seal damage. Judgement contributes on impact. A missed Judgement cast does not consume the critical proc. |
| Vengeance | - | - | - | 10 | - | 3 | 170c | - | - | Passive. Primary attack crits grant +3% damage per stack, up to 3 stacks (+9%), for 10 turns. Further primary crits refresh the duration. |
| Consecration | 5 | 1 | 12 | 6 | 1 | 3 | 200c | C(1,2) | Area (fixed 3x3) | Active. Consecrate the fixed 3x3 area around you for 6 turns, replacing your previous ground. Each turn deals 7.5 + 6% weapon damage as Holy to visible neutral or hostile enemies inside. Damage is fixed when cast; no crits, combo points or attack procs. Ticks begin this turn before weapon swings and enemy actions. No damage reduction; one turn. |
| Divine Shield | 20 | 1 | 30* | 3* | Self | 3 | 200c | C(1,4) | Player | Active self buff. Immune to incoming damage for 3 turns; deal 30% less damage while active. Guardian's Favor changes duration to 4 turns and cooldown from 30 to 20. Weapon timing continues. |
| Heart of the Crusader | - | - | - | 10 | - | 4 | 235c | - | - | Passive. Landed Judgement gives +3% critical chance against that enemy for 10 turns. |
| Pursuit of Justice | - | - | - | - | - | 4 | 305c | - | - | Passive. +20% movement credit: periodically move an extra tile in the chosen direction, stopping at obstacles. |
| Guardian's Favor | - | - | - | - | - | 5 | 370c | - | - | Passive. Divine Shield cooldown is 10 turns shorter and its duration is 1 turn longer. |

## Rogue

**Tagline: Build momentum across targets, then cash it in with a finisher.**

Player-held combo points, Eviscerate with an intrinsic rage refund, passive finisher
haste, dual-wield rewards and poisons. Finishers never refund combo points. Instant Poison supplies immediate damage; Deadly builds stacks. Catalytic Venom
rewards mixed coatings on unequal-speed weapons. Retained class attacks can also build
momentum.

Completing all Rogue training unlocks Jorik's Lucky charm gift through the same farewell
dialogue as Llane's War Horn, once each Loop and regardless of the selected class.
It works passively from Bags: a hit that would kill the living player instead leaves
them at 1 HP and replaces the charm in its bag slot with Broken lucky charm, which has
no effect. No cast, hotbar assignment or cooldown is involved. The charm prevents only
that hit; another hit, including later in the same turn, can kill the player. Absorbed,
missed and nonlethal hits do not break it, and it does not prevent the Development Death
trigger. Saves retain the intact/broken item and claimed gift. Both item forms and the
claim clear on death, allowing another gift with retained Rogue learning next Loop.

| Name | Rage cost | Cast time | Cooldown | Duration | Range | Level required to learn | Cost to learn | Sprite used for effect | Sprite placement (player / target / area) | Description |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Eviscerate | 15 | 1 | - | - | 1 | 1 | 0 | C(2,1) | Target | Active. Requires a melee target and at least 1 combo point. Spend all held points for 50% weapon damage plus 4 per point as physical damage. Hit/crit and armor apply; misses still spend points. Learned Slice and Dice adds haste from those spent points, even on a miss. After spending, has a 20% chance per point spent to refund 15 rage, guaranteed at 5 points, including on a miss. Refunds happen once; no combo points are refunded. Builds no attack points. One turn, no cooldown; weapon timing continues. |
| Relentless Assault | - | - | - | * | - | 1 | 0 | - | - | Passive. landed direct active attacks and ordinary main-hand hits grant 1 player-held combo point, up to 5, across classes and targets. At most 1 Relentless Assault point per turn. Off-hand hits, procs, buffs and misses grant none. Points reset on death. |
| Slice and Dice | - | - | - | * | - | 1 | 10c | - | - | Passive finisher upgrade. Eviscerate grants +30% attack haste for 5 + 3 turns per point spent (8-20 turns), even on a miss. Refreshes without stacking. No extra rage/action; cannot be cast/assigned separately. Ordinary ability cooldowns are unchanged. |
| Ambidexterity | - | - | - | - | - | 2 | 60c | - | - | Passive. Raises off-hand weapon damage from 50% to 75% in any class. Dual-wield pairs are always usable; off-hand swings grant no ordinary rage. |
| Evasion | 15 | 1 | 20 | 5 | Self | 2 | 90c | C(2,3) | Player | Active. +40% dodge for 5 turns, including attacks from behind. Costs one action. |
| Combat Potency | - | - | - | - | - | 3 | 120c | - | - | Passive. Landed ordinary off-hand swings have a 20% chance to grant 5 rage. |
| Seal Fate | - | - | - | - | - | 3 | 150c | - | - | Passive. Requires learned Relentless Assault. Qualifying landed direct active crits grant 1 additional player-held point, up to 5, even if the base point for the turn was already granted. Finishers and bonus strikes do not qualify. |
| Main Gauche | - | - | - | - | - | 3 | 190c | - | - | Passive. Landed ordinary main-hand swings have a 15% chance for one strike at 100% of the off-hand damage profile, including its normal 50%/75% damage multiplier. Requires an off-hand weapon; normal hit/armor apply, with no crits, recursive procs, rage or combo points. |
| Deadly Poison | 0 | 1 | - | * | Self | 4 | 230c | C(2,2) | Player (application) | Active coating. Choose hands as for Instant Poison; each coating lasts 60 turns, replacing only the selected hand's poison. Landed primary physical attacks have a 30% chance to apply a stack. Up to 5 shared stacks per enemy deal 1.5 base Nature damage each per turn for 12 turns. Applications refresh duration without delaying ticks; fractional damage is retained across ticks. No crits/proc chains. Ticks precede swings and enemy actions, including the final tick. Player sprite appears at coating time only. |
| Instant Poison | 0 | 1 | - | 60* | Self | 4 | 230c | C(2,2) | Player (application) | Active coating. Choose main hand, off hand or both with dual wield; single-weapon setups coat main hand directly. Each hand has its own 60-turn timer; replacing its poison leaves the other hand unchanged. Landed primary physical attacks with a coated hand have a 30% chance to add 8 base Nature damage. No crits or recursive procs; bonus strikes cannot trigger it. Catalytic Venom can add a Deadly stack. Player sprite appears on application only. |
| Restless Blades | - | - | - | - | - | 4 | 270c | - | - | Passive finisher reward. After Eviscerate spends points, including on a miss, reduce every currently recorded ability cooldown by ceiling(points spent / 2) turns, never below ready now. Includes preparation and summon cooldowns as well as offensive/defensive abilities. |
| Catalytic Venom | - | - | - | - | - | 5 | 310c | - | - | Passive. While dual wielding, Instant Poison on your faster base-speed weapon also applies one stack of the slower weapon's Deadly Poison. Both coatings must be active. Equal-speed weapons do not catalyze. No extra roll or recursive procs. |
| Bandit's Guile | - | - | - | 10 | - | 5 | 370c | - | - | Passive. Every 4 qualifying landed direct active attacks grant +5% damage, stacking to +15%. Each qualifying hit refreshes the 10-turn state, including partially built progress. Misses and finishers do not advance it. Retained class attacks qualify. |
| Precision | - | - | - | - | - | 5 | 430c | - | - | Passive. +5 percentage points of hit chance for weapon/physical and direct Holy/Fire/Nature attacks. |

## Implementation sources and upkeep

The runtime implementation is the executable source of truth. This is the single
maintained documentation reference for current class mechanics; correct it alongside
implementation changes rather than treating a stale row as a design constraint.

- [ClassSkillData](../scripts/hero/class_skill_data.gd) defines starters/Warrior data;
  [ClassToolkitData](../scripts/hero/class_toolkit_data.gd) supplies the extended catalog;
  [SkillDefinition](../scripts/hero/skill_definition.gd) merges them and supplies defaults.
- [GridWorld](../scripts/world/grid_world.gd) owns casting, training, turns and cooldown
  scheduling; [HeroState](../scripts/hero/hero_state.gd) owns stats, haste, rage and learning.
- [SkillCost](../scripts/combat/skill_cost.gd),
  [SkillBehaviors](../scripts/combat/skill_behaviors.gd),
  [ClassToolkitRules](../scripts/combat/class_toolkit_rules.gd),
  [AttackEvent](../scripts/combat/attack_event.gd) and
  [AttackProcs](../scripts/combat/attack_procs.gd) define costs, effects and attack events.
- [PaladinRules](../scripts/combat/paladin_rules.gd),
  [PoisonRules](../scripts/combat/poison_rules.gd),
  [SummonRules](../scripts/combat/summon_rules.gd) and
  [ClassSpellEffects](../scripts/combat/class_spell_effects.gd) define delayed, periodic,
  reactive and summon behavior.
- [GridView](../scripts/world/grid_view.gd) defines effect cells and actual placement;
  [the art guide](../art/README.md) explains runtime sheets and actor-art overrides.

For ability additions, removals, renames, tuning or behavior changes, update the affected
rows, interactions, shared rules and class summary/tagline in the same change. Preserve
one table per class, both active/passive entries, columns, `-`/`*` notation and ascending
level/price/name order. Art changes include cell coordinates, missing sprites, trigger
timing and player/target/area placement. Keep future decisions in direction/backlog.
