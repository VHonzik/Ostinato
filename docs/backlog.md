# Local backlog

Unfinished work, driven by owner playtests and small fixes. Current implementation
lives in [class mechanics](class-mechanics.md) and [quests, dialogue and NPCs](npc-dialogue.md);
[direction](direction.md) holds design goals and open choices.

These milestones work toward a playable demo of the full game, focused on the valley.

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

## Tooling follow-up — Hosted checks and first release

Use the local export and Actions workflows described in
[development](development.md#windows-exports). Remaining work requires GitHub rollout
and human playtesting:

- [ ] When committing/pushing is requested, exercise branch/PR/main checks and manual
  quick/full/targeted/build runs on GitHub. Confirm failures block publishing and
  malformed or off-main tags cannot publish releases.
- [ ] Extract a manual ZIP outside the checkout and play on Windows without Godot
  installed: verify version display, New Game, movement/combat, save/load and absence
  of development controls. Human review decides presentation and feel.
- [ ] When the owner requests the first release tag, verify the prerelease path and
  downloadable ZIP/checksum before using the normal release path. Local checks do
  not establish hosted Actions correctness or human acceptance.

## Android follow-up — First phone playtest

First target: Samsung Galaxy Z Flip6, unfolded inner screen in landscape. Review its
wide layout and both landscape orientations on the device; cover-screen play is deferred.

- [ ] Install the signed local APK using the [Android workflow](development.md#android-exports-and-touch-preview).
  Play a valley route with both hotbar rows populated. Review arrow reach, accidental
  turns, target selection, menu scrolling and text on the owner's phone. Accept the
  marshal's quests, tap Leave and check that movement is available again.
  Review the larger resource bars above the hotbar and auras below player info during
  combat, including retained combo points and Maelstrom Weapon stacks.
- [ ] Exercise app switching during an encounter, process termination followed by
  Continue, folding/locking and reopening the phone, and death into a new Loop.
  Review the safe-save recovery limitation in play.
- [ ] Make the smallest layout/control adjustment exposed by that playtest before
  expanding device coverage or considering Google Play distribution.

## Later milestones

| Milestone | Scope |
| --- | --- |
| Presentation, story and demo | Art/story polish remains deferred until requested. Refine silhouettes, terrain joins and dialogue consistency using [art direction](art-plan.md) and the current content references; prepare a shareable demo when ready. |
| Challenges and expansion | Choose useful per-seed challenges/achievements, then consider talents or additional synergies. Hosted leaderboards and classes beyond the current roster remain outside the current milestone. |
