# Game direction

The October 2026 pivot replaces the old requirements and Vanilla content-completion plan.
This is intended direction, not a claim about what the current build implements.
The original [pivot and retrospective](big-pivot.md) explain why; current work lives in
[the backlog](backlog.md). Earlier requirements and research remain in Git history.

## Keep

A keyboard-first grid roguelike with player-driven time, tactical movement and combat,
and repeated deaths that restart the world while preserving learning. Keep the sense
of a familiar human starting zone, roughly levels 1–10, threatened by an invasion.
A stalker remains the demo's final obstacle. WoW supplies flavor and ideas, not binding
formulas, class lists, quest inventories, or balance targets.

## Change

- Start as warrior. The class roster becomes warrior, rogue, shaman, and paladin;
  remove mage, druid, warlock, and priest in runnable gameplay changes.
- Make rage the primary resource. Rogue contributes combo points, poisons, and Slice
  and Dice; shaman contributes mechanics such as Windfury, Flurry, and shields;
  paladin contributes seals, powerful buffs, and possibly judgements. These are
  directions for a curated toolkit, not a promise to reproduce every WoW ability.
- Make melee the core interaction and experiment with how ordinary attacks advance.
  Do not settle the input/timing model without a playable prototype and discussion.
- Give each class a persistent progression track of active and passive abilities.
  Using class abilities advances it; reaching a checkpoint still requires a trainer
  visit. Unlock classes through the initial conversation, with more story. Bring
  signature abilities forward so retained learning creates useful combinations early.
- Reduce NPC numbers and remove within-Loop NPC respawns. Build a deliberate world
  with recognizable characters rather than a complete Northshire database replica.
- Let new Loops reveal dialogue and the player's realization of the Loop. NPCs do not
  know about the Loop, and their knowledge of the invasion is much more limited.
- Rework XP and encounter pacing around an approximately ten-minute first Loop ending
  at the stalker. This is a playtest target, not a forced death or real-time deadline.
  Rework misses/resists and reinforcements so later victory is plausible and enjoyable.
- Double resolution while preserving roughly the apparent sprite size and amount of
  visible world. Design the world and required sprite list before the owner creates
  a replacement spritesheet. Give art and readability real development time.
- Reduce combat-log prominence, enlarge hotbar capacity, and provide a dedicated menu
  for other player screens. Exact geometry and slot count await a layout experiment.

## Still to decide, when the relevant task starts

- What does a melee input commit to, and how does the player stop or change targets?
- How do rage, combo points, and retained cross-class abilities work together? What
  advances each track, what survives death, and what prevents empty ability spamming?
- What role remains for gear, inventory, gold, loot, quests, and traders? Their removal
  is not yet decided; do not mistake dissatisfaction with them for a settled redesign.
- What are the exact art dimensions, minimum window size, and hotbar controls?
- What should the first and later stalker encounters feel like, including reinforcements?

Keep answers brief here when they become durable direction. Keep tuning values and
implemented rules in code/data, not duplicated tables in documentation.
