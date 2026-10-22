# Current quests, dialogue and NPCs

The authoritative reference for implemented content in the playable valley.
Dialogue is verbatim; `{Class}`, `{class}` and `{Trainer}` mark name substitutions.

[Contacts](#friendly-contacts) · [Quests](#quests) · [Dialogue](#dialogue-and-services) · [Encounters](#encounter-npcs) · [Code locations](#implementation-locations)

## Friendly contacts

All contacts are friendly and stationary. Tiles use zero-based `(x, y)` coordinates.

| NPC | ID | Location / tile | Quests and services | Greeting |
| --- | --- | --- | --- | --- |
| Marshal McBride | 197 | Outside the abbey, north of player spawn; (30, 52) | Class selection; Wolves of the Western Woods; The Northern Camp; Into Echo Ridge | Greeting adventurer, welcome to Northshire Abbey. You look worn out from your travels. |
| Deputy Willem | 823 | West of the abbey; (24, 45) | Around the Valley | A new face is always a pleasant sight, how can I help? |
| Janos Hammerknuckle | 900003 | Inside the abbey; (28, 41) | Trade; starter gear for the selected class | Greetings, what can I get you? |
| Khelden Bremen | 198 | Inside the abbey; (32, 35) | Greeting only | Hello adventurer. |
| Milly Osworth | 9296 | Inside the abbey; (33, 45) | Milly's Vineyard | A gang of brigands, the Defias, moved into the Northshire Vineyards while I was harvesting! |
| Northshire Guard | 1642 | Road south of the southwestern gate; (12, 68) | Greeting while alive; killed by the first stalker arrival | This is the road out of the valley. Stay alert; I heard something beyond the gate. |
| Llane Beshere | 911 | Inside the abbey; (28, 45) | Warrior training; War Horn gift | Practice your warrior skills. Return when you are ready to learn new tricks. |
| Jorik Kerridan | 915 | East of the abbey; (39, 43) | Rogue training; Lucky charm gift | Hello adventurer. Jorik Kerridan, famous rogue at your service. |
| Brother Sammuel | 925 | Inside the abbey; (30, 37) | Paladin training; Wartorn Banner gift | Hello adventurer. I am Brother Sammuel, follower of the light. |
| Farseer Lopaa | 900002 | Beside the abbey entrance; (36, 46) | Shaman training; Ancestral totem gift | Hello adventurer, I am Farseer Lopaa, a storm-chaser. |

## Quests

Choose a class at the marshal before accepting quests. Every quest below is available
to every selected class, has no prerequisite quest, and returns to its giver. Item
rewards are fixed common gear; `c` means copper. XP is the base reward.

| Quest | Giver / receiver | Minimum player level | Quest level | Objectives | XP | Money | Item rewards |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Wolves of the Western Woods | Marshal McBride | 1 | 2 | Kill 8 Young Wolves and 5 Timber Wolves | 800 | 0 | Patrol Armor; Patrol Amulet |
| The Northern Camp | Marshal McBride | 1 | 2 | Kill 4 Kobold Vermin | 750 | 50c | Steady Band; Militia Daggers |
| Into Echo Ridge | Marshal McBride | 2 | 3 | Kill 2 Kobold Workers and 1 Kobold Laborer | 1,200 | 100c | Militia Warhammer |
| Around the Valley | Deputy Willem | 2 | 3 | Visit Echo Ridge Mine, the vineyard and the western wolf woods | 1,100 | 0 | Quick Band |
| Milly's Vineyard | Milly Osworth | 2 | 4 | Kill 4 Defias Thugs and Garrick Padfoot | 800 | 100c | Militia Hammer and Shield |

### Exploration areas

| Objective | Credited tiles, inclusive | Trigger |
| --- | --- | --- |
| Echo Ridge Mine | x 17–27, y 2–13 | Enter the mine region |
| Vineyard | x 46–60, y 60–76 | Enter the vineyard region |
| Western wolf woods | x 4–21, y 28–59 | Enter the woods region |

### Quest dialogue

| Quest | Offer | Accepted, objectives incomplete | Objectives complete, before hand-in |
| --- | --- | --- | --- |
| Wolves of the Western Woods | The western woods are overrun with wolves. Thin their numbers so our people can use the paths again. | Are the western paths safer? Watch for the larger timber wolves. | Good work. Our gatherers can venture west again. Take these supplies. |
| The Northern Camp | Kobolds have settled along the northern road. Clear their camp before they grow bolder. | Have you cleared the kobolds from the northern camp? | That should keep the northern road open. These supplies are yours. |
| Into Echo Ridge | The kobolds in Echo Ridge are digging deeper. Enter the mine and drive out their workers and laborers. | What news from Echo Ridge? We need those kobolds driven out. | You have bought us some breathing room. Take this weapon; you have earned it. |
| Around the Valley | I need fresh eyes on the valley. Scout Echo Ridge, the vineyard and the western wolf woods, then report back. | Have you seen all three places? I need the whole picture. | Kobolds, thieves and wolves. Trouble on every side—but now we know where we stand. Thank you. |
| Milly's Vineyard | Garrick and his thugs have taken my vineyard. Drive them out before there is nothing left to save. | Is Garrick gone? His thugs will stay while he leads them. | My vineyard is mine again! Thank you. Please take this hammer and shield. |

### Quest rules and presentation

| State / action | Current behavior |
| --- | --- |
| Acceptance | Requires the minimum current-Loop player level and the nearby living giver. Accepting sets objective counts to zero and immediately checks the player's current exploration region. |
| Kill credit | Only accepted, unhanded quests advance. Earlier kills do not count; counts stop at each objective's requirement. |
| Exploration credit | Only accepted quests advance. Visiting before acceptance does not bank credit; accepting while inside a required region credits that region. |
| Available quest | A yellow `!` precedes its title. The detail screen separates the offer from indented objectives and rewards with a divider. Gear appears above Accept as quality-colored names; hover or keyboard focus shows details. Accept / Cancel choices appear at the giver. Reward choices are selected at hand-in. |
| Accepted quest | A gray `?` marks incomplete objectives; a yellow `?` marks a ready hand-in. The detail screen shows the matching quest speech. The quest log can display the ready speech away from the giver too. |
| Hand-in | Requires all objectives and the nearby living receiver. Complete grants all listed items, money and XP once. Insufficient bag space leaves the quest and rewards unclaimed. |
| Abandon | Requires confirmation; removes quest progress and associated quest items. An eligible quest can be accepted again. Accepting any quest locks class selection for that Loop even if it is abandoned. |
| Tracker and markers | Accepted quests and objective counts appear in the upper-right tracker; completed objectives and ready quests are marked completed. Handed-in or abandoned quests leave it. Friendly NPCs alternate their faction art with `!` for an available quest or ready hand-in; needed enemies have a yellow marker in the engaged-enemy frame. |
| XP scaling | Full base XP through 5 levels above quest level; 80%, 60%, 40%, 20% at 6, 7, 8, 9 levels above; 10% at 10 or more. Round up. |
| Saves and death | Saves retain accepted quests, objective counts and hand-ins. Death clears them and rebuilds the quest route. |

## Dialogue and services

### Conversation rules

| Condition | Text / behavior |
| --- | --- |
| Interaction | Bump a friendly contact or use F within one tile, including diagonals. The contact must be alive and the player ready for an action. Conversations, choices and service menus spend no world turn. |
| Class not chosen in a returning Loop | The marshal offers class selection. Every other contact opens only: “Hello stranger, you should go say hi to Marshal in front of the abbey.” |
| Ordinary greeting | Uses the contact's greeting above. It does not vary with quest progress, learned skills, Loop count or the gate threat. |
| Contact has choices | Opens a conversation with eligible quests, service choices and Leave (Esc). |
| Contact has no choices | Logs its greeting and closes the menu. This includes Khelden and the living guard, and quest contacts without eligible or active quests. |
| Returning from a service | Refreshes choices without recording another talk interaction. |
| Empty quest log | “No active quests. Speak to Marshal McBride outside the abbey.” This is interface guidance. |
| Enemies | No conversation or authored spoken dialogue. Encounter announcements are system log text. |
| Friendly summons | Use the shared “Hello adventurer.” greeting when interacted with; no unique dialogue or services. |

### Marshal: class selection

| Loop / condition | Player choice / interface text | Result |
| --- | --- | --- |
| New Game | Warrior is selected | Starts knowing Mortal Strike and Whirlwind; quests and services are available. |
| Loop 1, before receiving starter gear | Janos Hammerknuckle inside the abbey can give you spare arms and armor for free. | Appears alongside the marshal's greeting and choices. |
| Loop 2, before choosing | I am warrior | Selects Warrior and unlocks quests/services. |
| Loop 3, before choosing | I am warrior; I am .... shaman; I am .... paladin; I am .... rogue | Selects the chosen class and unlocks quests/services. |
| Loop 4 onward, before choosing | I am warrior; I am shaman; I am paladin; I am rogue | Selects the chosen class and unlocks quests/services. |
| Class-choice focus | Previous class is focused | Selection is available outside combat before any quest acceptance. |
| Returning Loop after choosing or accepting a quest | Advancing {Class} this Loop. Class choice is locked until death. | The marshal offers eligible quests. |
| Returning Loop, choice blocked by combat before choosing | Return outside combat to choose your class before accepting a quest. | Class choices are unavailable until eligible. |

### Marshal: selection replies

`{Class}` is Warrior, Shaman, Paladin or Rogue; `{class}` is lowercase. `{Trainer}`
is the matching trainer in the contact table. Warrior counts as chosen at New Game.

| Condition | Marshal reply |
| --- | --- |
| First selection of Shaman, Paladin or Rogue | You don't look like {Class}... Anyway, go speak with {Trainer}, they will get you started. And check with Janos Hammerknuckle, they might have some old equipment lying around. |
| Class selected before | Speak with Janos Hammerknuckle, he always has supplies lying around. And {Trainer} is our own {class} if you need some guidance. |

### Service choices

| NPC / service | Choice or response | Availability / result |
| --- | --- | --- |
| Janos: spare gear | Do you have any spare gear for {class}? | Once per Loop after class selection. Exchanges starter-marked gear for the chosen class's outfit, preserving acquired gear. Fails without claiming the grant if inventory space is insufficient. |
| Janos: gear response | I can find some left overs if you are not picky. | Appears after a successful gear grant. |
| Janos: shop | Trade | Opens buy/sell controls with stock and prices; no further authored speech. |
| All four trainers | Train | Opens that trainer's class catalog. Only the selected class can be learned; starters are free, later skills require current-Loop level and money. Learning persists across death and works in every class. |
| Trainer for another class | Select {Class} before learning here. Retained skills remain usable. | Status text in that trainer's menu. |
| Trainer: completed class training | I have nothing to teach you anymore you have to venture forth. Here is a small something for your journey... | The farewell is both a choice and the logged response to claiming the trainer's gift. Requires every active and passive in that trainer's catalog, a class chosen this Loop, and being outside combat. Available once per trainer per Loop in any selected class; full bags preserve the offer. |

| Trainer | Farewell gift | Effect reference |
| --- | --- | --- |
| Llane Beshere | War Horn | [Warrior gift](class-mechanics.md#trainer-gift-war-horn) |
| Farseer Lopaa | Ancestral totem | [Shaman gift](class-mechanics.md#trainer-gift-ancestral-totem) |
| Brother Sammuel | Wartorn Banner | [Paladin gift](class-mechanics.md#trainer-gift-wartorn-banner) |
| Jorik Kerridan | Lucky charm | [Rogue gift](class-mechanics.md#trainer-gift-lucky-charm) |

### Loop opening log

Each line below ends with: “Speak to Marshal McBride north of you, outside the abbey.”
These are player narration, separate from NPC speech.

| Loop | Opening text before the shared hint |
| --- | --- |
| 1 | You arrive in Northshire, weary from the road. |
| 2 | You remember dying. What happened? Was it a nightmare? |
| 3 | You definitely died this time. Why are you back here? |
| 4 | What is that monster at the gate? Where are the guards? |
| 5 | No one else seems to remember anything, but maybe they can help me? |
| 6 onward | I must become stronger. |

## Encounter NPCs

Counts describe each fresh Loop. Damage and swing intervals are base melee profiles,
before hit, armor and level modifiers; intervals use world turns. `-` means no NPC ID.

| NPC | ID | Count | Location / initial behavior | Level | HP | Armor | Melee damage | Swing interval |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Young Wolf | 299 | 11 | Western woods; neutral, wanders | 1 | 40 | 20 | 4–5 | 2 |
| Timber Wolf | 69 | 8 | Western woods; neutral, wanders | 2 | 50 | 35 | 4–5 | 2 |
| Kobold Vermin | 6 | 8 | Northern outdoor camp; neutral, wanders | 1 | 40 | 20 | 3–4 | 2 |
| Kobold Worker | 257 | 4 | Echo Ridge Mine; hostile, stationary when idle | 3 | 60 | 65 | 4–6 | 2 |
| Kobold Laborer | 80 | 2 | Echo Ridge Mine; hostile, stationary when idle | 3 | 60 | 65 | 4–6 | 2 |
| Defias Thug | 38 | 4 | Vineyard; hostile, wanders | 4 | 70 | 85 | 5–7 | 2.4 |
| Garrick Padfoot | 103 | 1 | Far eastern vineyard; hostile, stationary when idle; (78, 66) | 5 | 220 | 105 | 10–13 | 2.6 |
| Demon stalker | - | Up to 5 timed arrivals | Gate road; hostile, stationary when idle | 8 | 600 | 240 | 14–18 | 2.5 |

### Encounter behavior and story events

| Rule / event | Current behavior / log text |
| --- | --- |
| Neutral encounters | Wolves and outdoor Kobold Vermin remain neutral until attacked. Bumping the same stationary neutral twice attacks; deliberate attacks and War Horn can engage neutral NPCs. |
| Hostile aggro | Mine kobolds and bandits acquire visible targets within 4 tiles; stalkers use 5 tiles. Concealment and summons follow the [class rules](class-mechanics.md). |
| Engage marker | A hostile spotting the player more than one tile away shows `!` once for 1.5 seconds, matching ability flashes. Adjacent detection, player-initiated attacks and ongoing engagement do not trigger it. Engagement preserves the NPC's faction color. |
| Wandering | Outdoor wolves, camp kobolds and Defias Thugs wander within two tiles of their home position, with staggered starts and random pauses of 3–10 turns. Pending pauses survive saves. |
| Pursuit | Engaged enemies pursue and attack in melee. Five consecutive turns with no terrain route to the target start a return home; reaching home restores full health. During Vanish they pursue living summons; with none, they hold around the remembered Vanish origin without attacking or losing engagement. See [Vanish interactions](class-mechanics.md#vanish-interactions). |
| Population | No ordinary NPC respawns within a Loop. Death rebuilds contacts and enemies. Empty corpses disappear; other ordinary corpses hide after 300 turns even with loot. The story guard's corpse remains. Summons leave no visible corpse. |
| Stalker deadlines | World turns 25, 800, 980, 1,140 and 1,280, measured from the start of the Loop. Blocked entry retries without moving deadlines. |
| Stalker entry tiles | First available tile in order: (12, 69), (11, 69), (13, 69), (12, 70), (13, 70). |
| First stalker arrival | Kills the story guard and logs: “A demon stalker enters the gate, kills the guard, and begins to feast!” |
| Reinforcement arrival | Logs: “A demon stalker reinforcement enters the gate ({number} of 5)!” The number is the arrival count, 2–5. |
| Fel Breath | After 4 normal engaged turns, locks a 1–3–3 cone starting at the target's tile; gives 2 response turns and then releases. Terrain/sight limit the area. Deals 60 base Fire damage with level scaling to the player and friendly summons; bypasses armor, block, dodge and critical rolls. Waits 10 normal turns between casts. Announcement and response turns replace movement/melee; committed breath still releases through stun or Vanish. |
| Breath warning | Demon stalker draws breath! Fel Breath in 2 turns. Leave the marked cone. |
| Breath release | Demon stalker unleashes Fel Breath! |
| Victory | Defeat every currently present stalker to win immediately. Future arrivals do not block victory; no gate-crossing action is required. |

### Summoned NPCs

| Ally | Source | Role / dialogue | Mechanics reference |
| --- | --- | --- | --- |
| Earth Elemental | Ancestral totem | Friendly mobile summon; redirects engaged enemies; shared greeting, no services | [Ancestral totem](class-mechanics.md#trainer-gift-ancestral-totem) |
| Spirit Wolf | Feral Spirit | Two friendly temporary summons; attacks heal the player; shared greeting, no services | [Shaman abilities](class-mechanics.md#shaman) |

## Loop and save state

The five New Game worlds cover uncommon two-hand, sword/shield and dual-wield drops.
`solemnly-moonwell (HARD)` has one uncommon item and no uncommon weapons across enemies
and chests. The HARD suffix is display-only.

| Content | Saved mid-Loop | On death |
| --- | --- | --- |
| World seed | Numeric seed; the player menu resolves the five fixed New Game choices to their names, and displays unlisted seeds numerically | Keeps the chosen seed; enemy and chest loot repeats by spawn identity |
| Quest route | Accepted quests, counts, hand-ins and quest-acceptance lock | Clears; quests can be taken in the fresh world |
| Class selection | Selected class, selection lock and classes previously chosen | Requires a fresh selection; remembers the previous class for focus and chosen classes for referral wording |
| NPC population | Living/dead actors, combat state, loot and wandering deadlines; fixed contacts except the guard follow valley scene positions on load | Rebuilds contacts and enemies from the scene |
| Gate scene | Arrival count, deadlines, guard state and stalkers, including pending breath | Restarts schedule and restores guard |
| Service grants | Granted items, Janos's starter-gear claim and each trainer's gift claim | Clears claims and items; learned abilities remain |

Android also keeps a separate recovery save at completed action boundaries outside
combat, including the fresh world after death. Continue restores that safe snapshot,
including the quest/NPC state above; it does not resume unfinished combat or casts.
Backgrounding freezes the running attempt until Resume. Completing the demo clears
recovery. The five manual slots and their save revision remain independent.

## Implementation locations

| Looking for | Start in |
| --- | --- |
| Contact names, greetings, services and referrals | [NpcDefinition](../scripts/world/npc_definition.gd) |
| NPC placements, population counts and exploration regions | [Valley scene](../scenes/valley.tscn); instantiated by [ValleyMap](../scripts/world/valley_map.gd) |
| Quest objectives, rewards and speech | [QuestData](../scripts/quests/quest_data.gd); eligibility and progress in [QuestRules](../scripts/quests/quest_rules.gd) |
| Conversation choices and screens | [NpcConversation](../scripts/world/npc_conversation.gd), [MenuPanel](../scripts/menu_panel.gd) |
| Creature stats and behavior | [NorthshireData](../scripts/world/northshire_data.gd), [NpcRules](../scripts/world/npc_rules.gd); breath in [StalkerBreath](../scripts/world/stalker_breath.gd) |
| Loop narration and class selection | [GameSession](../scripts/game_session.gd); arrivals and service grants in [GridWorld](../scripts/world/grid_world.gd) |
| Saved quest and NPC state | [SaveCodec](../scripts/save_codec.gd) |
