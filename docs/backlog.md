# Local backlog

Unfinished work, driven by owner playtests and small fixes. Current implementation
lives in [class mechanics](class-mechanics.md) and [quests, dialogue and NPCs](npc-dialogue.md);
[direction](direction.md) holds design goals and open choices.

## Current milestone — Valley progression and boss pacing

Make the existing loop enjoyable from a weak first life through partial class
learning, rebuilt gear and a developed attempt at the gate. Follow owner feedback
one playable change at a time. The next focus below is a recommendation.

### Recommended next playable task — Route and training economy

- [ ] Identify the next pacing problem during an ordinary quest route: which training,
  gear or food purchase feels unaffordable, compulsory or pointless? Include a returning
  Loop with a partially learned class, where the next unlock competes with supplies.
- [ ] Adjust the smallest relevant part of the XP curve, training levels/prices,
  quest/vendor rewards or healing supply. Keep route choice and useful early class
  tools; judge learning pace from actual play against the goal in direction.

### Further follow-ups, selected from play

| Area | Remaining useful work |
| --- | --- |
| Combat and weapon choices | Tune where play shows a weak or dominant option: saving rage versus cleaving, two-hand/shield/dual wield, partial unlocks, mixed-class synergies, large pulls and uncommon gear. Include trainer gifts and summons when they change the result. |
| Gate pressure | Judge the whole route into the Stalker fight: attainable level/gear, preparation costs, breath dodge opportunities and reinforcement deadlines. Review the intended three-developed-class victory goal with real attempts. |
| Feedback and controls | Fix concrete problems reading or operating the current toolkit: targeting, buff/proc states, Vanish, delayed/ground effects, gift use and crowded encounters. Human play decides visibility and feel. |

Use the [bench](../bench/README.md) for a specific tuning question exposed by play.
Keep route costs, partial learning and player choices in view when interpreting
isolated fights. Save/reset correctness and deterministic loot remain regression
concerns during fixes; use the checks in [development](development.md).

## Decisions to revisit when needed

| Question | Current scope |
| --- | --- |
| Ordinary respawning | The playable valley has no within-Loop respawns. Decide deliberately if finite enemies make progression or routes unsatisfying; account for repeatable XP/gold before adding respawns. |
| Level and healing limits | Tune attainable levels, level-gap difficulty and recovery against finite quests/encounters. An explicit level cap remains a design choice. |
| Additional mechanics | Schedule further passives, Execute/Judgement combo empowerment, broader damage/healing scaling or experimental Stalker Enrage/recovery only for a concrete gameplay goal. Keep the choices in [direction](direction.md). |

## Later milestones

| Milestone | Scope |
| --- | --- |
| Presentation, story and demo | Art/story polish remains deferred until requested. Refine silhouettes, terrain joins and dialogue consistency using [art direction](art-plan.md) and the current content references; prepare a shareable demo when ready. |
| Challenges and expansion | Choose useful per-seed challenges/achievements, then consider talents or additional synergies. Hosted leaderboards and classes beyond the current roster remain outside the current milestone. |
