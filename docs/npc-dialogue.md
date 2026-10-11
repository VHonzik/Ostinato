# Current NPC dialogue

Story-editing snapshot of the current build, 11 October 2026. Dialogue below is
copied verbatim; it describes implemented text, not proposed story changes.

## Playable dialogue

All ten friendly contacts are included. Greetings do not vary with Loop count,
quest progress, learned abilities, or the gate threat. Interacting requires a
living, friendly contact within reach. Contacts with quests or services open a
conversation menu; those without available choices send their greeting to the log
and close the menu.

| NPC | When / where the line appears | Current dialogue | New dialogue |
| --- | --- | --- | --- |
| Marshal McBride | Greeting on interaction. | The woods lie west; kobolds camp north, below Echo Ridge. Pick a route and report back. | Greeting adventurer, welcome to Northsire Abbey. You look worn out from your travels. |
| Marshal McBride | Choose “Ask about warrior training”. | The Legion has reached Northshire. Do I know you? These clothes may help. | (Change the option to "It's been a long journey, is there a warrior master?") Speak with Llane Beshere inside the abbey. Also check with Janos inside, he might give you some arms and armor. |
| Marshal McBride | Same training conversation, below the preceding line in the current warrior-only build. | Speak with Llane Beshere inside the abbey. | (Remove this conversation) |
| Marshal McBride | From second loop pick "Uhm... I seek paladin teaching" | (New convo) |  Speak with Brother Sammuel inside the abbey.  Also check with Janos inside, he might give you some arms and armor. |
| Deputy Willem | Greeting on interaction. | There are old supply caches in the mine, on the eastern ridge and south of the vines. | A new face is always pleasant sight, how can I help? |
| Abbey supply trader | Greeting before choosing “Trade”. Uses the shared fallback greeting. | The abbey's south door is open. The paths lead north to the mine and east to the vines. | Hello adventurer. |
| Khelden Bremen | Greeting on interaction. Uses the shared fallback greeting; currently has no training service or playable quests. | The abbey's south door is open. The paths lead north to the mine and east to the vines. | Hello adventurer. |
| Milly Osworth | Greeting on interaction. | Bandits are among my vines. Garrick is camped at the far eastern end. | A gang of brigands, the Defias, moved into the Northshire Vineyards while I was harvesting!  |
| Northshire Guard | Greeting on interaction while alive. | This is the road out of the valley. Stay alert; I heard something beyond the gate. | (Keep) |
| Llane Beshere | Greeting before choosing “Train”. The line remains the same after learning Anger Management or Charge. | Practice Slam and Battle Shout. Return when you are ready to learn Anger Management. | Practice you warrior skills. Return when you are ready to learn new tricks. |
| Jorik Kerridan | Greeting on interaction. Uses the shared fallback greeting; currently has no training service or playable quests. | The abbey's south door is open. The paths lead north to the mine and east to the vines. |  Hello adventurer. Jorik Kerridan, famous rogue at your service. |
| Brother Sammuel | Greeting on interaction. Uses the shared fallback greeting; currently has no training service or playable quests. | The abbey's south door is open. The paths lead north to the mine and east to the vines. |  Hello adventurer. I am Brother Sammuel, follower of the light. |
| Shaman trainer | Greeting on interaction. Uses the shared fallback greeting; identity remains a placeholder and training is unavailable through this contact. | The abbey's south door is open. The paths lead north to the mine and east to the vines. | Hello adventurer, I am Farseer Lopaa, a storm-chaser. (Rename the NPC to Farseer Lopaa) |
| Vendor | Greetings on interaction. | (Nothing now) | Greetings, what can I get you? (Rename the NPC to Janos Hammerknuckle) |
| Janos Hammerknuckle | Choose "Do you have any spare gear for warrior?". | (Nothing now) | I can find some left overs if you are not picky. (Awards and changes player gear to warrior specific.) |
| Janos Hammerknuckle | Choose "Do you have any spare gear for paladin?". | (Nothing now) | I can find some left overs if you are not picky. (Awards and changes player gear to warrior specific.) |

Greetings and contact identities: [valley_route.gd](../scripts/world/valley_route.gd).
Training conversation and menu routing: [menu_panel.gd](../scripts/menu_panel.gd).
Interaction routing: [combat_panel.gd](../scripts/combat/combat_panel.gd) and
[grid_world.gd](../scripts/world/grid_world.gd).

## Quest and service context

There are no authored quest offer, progress, completion, or farewell speeches.
Quest conversations display the fixed greeting above, then quest titles and
generated objective/reward information. The available story hooks are:

- Marshal McBride: “The Western Path”, its follow-up “Timber Wolves of the Western
  Woods”, “The Northern Camp”, and “Into Echo Ridge”. The follow-up requires handing
  in the western patrol; the mine quest also requires reaching its minimum level.
- Deputy Willem: “Around the Valley”.
- Milly Osworth: “Milly's Vineyard”, available after reaching its minimum level.

Quest buttons use “Available: ”, “In progress: ”, or “Ready: ”. Finished objectives
show “Objectives complete — ready for hand-in.” Hand-ins produce a generated log
message, not a response from the NPC. These states change the choices, not the
greeting. Quest definitions and availability live in
[quest_data.gd](../scripts/quests/quest_data.gd) and
[quest_rules.gd](../scripts/quests/quest_rules.gd).

Llane's training menu displays progression points, skill entries, and requirement
messages; it has no additional character speech. The trader's shop displays
buy/sell controls and stock information, with no additional character speech.

The empty quest log also contains this story-related UI hint:
“No active quests. Speak to Deputy Willem beside the abbey.”
It is interface text, not Willem's dialogue.

## Dialogue retained in code but unavailable in normal current play

| Speaker / scope | Retained dialogue | Why it does not appear in the current playable route |
| --- | --- | --- |
| Marshal McBride | Marshal: Welcome back, %s. These clothes should fit. Visit your trainer. | Logged after a successful class change; `%s` is the chosen class. The class-change menu needs more than one playable class, but only Warrior is exposed. The underlying eligibility also requires a later Loop, an initial-level character, and no prior class selection or quest acceptance in that attempt. |
| Any friendly NPC in the non-Northshire fixture | Welcome. The Legion is invading. The cities are besieged, and the gate is unsafe. Some here still think this is only a bandit raid. | Generic fallback in `GridWorld.interact`; the playable valley sets `northshire` to true and uses the greetings above. The log prefixes this line with the actor's name. |

Sources: [game_session.gd](../scripts/game_session.gd),
[class_skill_data.gd](../scripts/hero/class_skill_data.gd), and
[grid_world.gd](../scripts/world/grid_world.gd).

Other trainer-menu branches retain “Training for this class is not available yet.”
and “Select %s before learning here. Retained skills remain usable.” These are
service status messages, not additional character dialogue, and are not reached
through the current valley's non-warrior contacts.

## Context for the story pass

No player dialogue choices or Loop-dependent NPC responses are implemented.
“Ask about warrior training”, “Train”, and “Trade” are service choices. Hostile and
neutral encounters, including Garrick and the stalkers, have no dialogue.

The marshal's training line explicitly knows the Legion has arrived, while the
guard only reports hearing something outside the gate. “Do I know you?” is fixed
text even in the first Loop. The retained class-change line says “Welcome back”.
These are existing lines to reconsider against the intended limited invasion
knowledge and NPCs' lack of Loop awareness in [direction.md](direction.md).
