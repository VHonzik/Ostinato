# Temporary simulation bench

Disposable design tools, kept in Git because they are useful to reuse. These scripts
call the current game model; the game never loads the bench. `.gdignore` keeps them
out of editor imports and normal script validation. The launcher loads them explicitly.
No separate project, dependency upgrades, or simulation framework.

From the repository root, after the normal [setup](../docs/development.md):

```powershell
pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Smoke
pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario paladin
pwsh -NoProfile -File tools/simulate.ps1 -Scenario rogue
pwsh -NoProfile -File tools/simulate.ps1 -Scenario stalker-passives -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario priorities -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario accessories
pwsh -NoProfile -File tools/simulate.ps1 -Scenario loot -Smoke
pwsh -NoProfile -File tools/simulate.ps1 -Scenario loot-rates -Smoke
```

| Scenario | Purpose |
| --- | --- |
| `warrior` | Full Warrior kit, three weapons, cold/prepared entry, groups and Stalker; paired potion runs for Stalker. Independent pilot seeds select the rotation. Traced damage is reconciled and replayed against plain `GridWorld`. |
| `warrior-harder` | Harder groups using policies from a previous `warrior` result. Supply `-Baseline reports/bench/warrior/<run>/result.json`. |
| `paladin` | Full Paladin, Warrior + Paladin and all four kits; single enemies, groups and Stalker, three weapons and cold/prepared entry. Independent pilots select Holy-first, physical-first or Holy-first without ground. Damage reconciles to enemy HP and sample fights replay on plain `GridWorld`. |
| `rogue` | Full Rogue, Warrior + Rogue and all four kits, using the same encounters, gear, entry states, pilot priorities and replay checks as `paladin`. Spend at 3+ points, including while passive haste is active. |
| `stalker-passives` | All 15 retained-kit combinations against Stalker, then one-passive removals in its own kit and all four kits. Records actual player healing/losses as well as boss damage. 200 baseline seeds, 100 matched removal seeds, independent 40-seed policy pilots; three weapons and cold/prepared entry. Use shards 0/1/2 sequentially. |
| `priorities` | Live requested priorities on starter Shaman, full Shaman/Paladin, all four three-kit combinations and all kits. Five priority alternatives on all kits; ordinary groups, Stalker, ranged pulls and durable-group/banked-stack stress cases. Cold/live prepared entry, 30 seeds per cell, three weapons; sample fights replay against plain `GridWorld`. |
| `accessories` | Expected auto-attack damage and physical effective HP for common gear, upgrades and primary stats. No active rotation; `-Smoke` runs the same calculation. |
| `loot` | Seeded valley loot, obtainable loadouts, estimated auto-attack gains, and a full-route gold budget beside total training costs. |
| `loot-rates` | Compare candidate uncommon drop rates on copied loot tables. These are experimental rates, not live tuning. |

`-Smoke` reduces combat/loot samples for a wiring check, not a design conclusion.
Omit it for the normal sample counts held in each script. Warrior `-Shard 0/1/2`
selects two-hand/shield/dual wield; omit it to run all three. A harder run needs a
baseline covering its selected weapons. Use a non-smoke baseline for design decisions.
Paladin also accepts `-Shard 0/1/2` for two-hand/shield/dual wield; omit it for all three.
Rogue accepts the same shards. Cold entries apply Instant Poison; prepared dual-wield
entries start with faster-weapon Instant and slower-weapon Deadly. Rogue supports
the earlier active Slice and Dice kit for paired before/after runs; older builds only
refresh that active when its haste expires.
`-TimeoutSeconds` controls each child process, up to 600 seconds; shard combat runs
if necessary. Run launchers sequentially because they share the project import cache.

Each invocation creates `reports/bench/<scenario>/<timestamp>-<id>/`:

- `result.json`: scenario data, including setup/policies where applicable.
- `run.json`: actual Git revision, dirty flag, pinned engine, options and completion
  status. A dirty flag means the commit alone cannot reproduce the working tree.
- `*.stdout.log`, `*.stderr.log`, `engine.log`, `scripts.txt`: debugging output.
- `baseline.json`: copied input for a harder run; its hash is in `run.json`.
- `runtime/`: process-local AppData and temporary files; no player saves are loaded.

All run files remain ignored, including failures. Every run gets a new directory;
there is no automatic resume or overwrite of historical results. Inspect a failed
run's logs before retrying. Nonzero exits, Godot errors, resource leaks, missing JSON
and incomplete Warrior matrices fail the launcher. A successful process is a completed
experiment, not a gameplay acceptance test.

Use this exact `pwsh -NoProfile -File tools/simulate.ps1 ...` invocation as a standalone
command. The narrow reusable approval prefix is
`["pwsh", "-NoProfile", "-File", "tools/simulate.ps1"]`; it covers scenario arguments.
Godot can need Windows certificate-store access outside the sandbox. If prompted,
remember approval for this launcher. Approval is local to the agent installation;
cloning the repo does not carry it. See [official command rules](https://developers.openai.com/codex/rules).

For a new experiment, add a script in `bench/`, a scenario entry in the launcher, and
write through `bench_io.gd`. Keep seeds, sample sizes, entry conditions and bot policy
explicit in code/results. Prefer live actions; explain any shortcuts and verify that
instrumentation does not change outcomes. Run a smoke case and the normal project
validation after code changes. Do not turn historical policies into gameplay contracts.

Older one-off experiments remain in ignored `reports/` and may use removed APIs.
The obsolete October 14 balance snapshot and frozen scripts have been removed;
use this bench with the current game model. Human playtests still decide feel,
readability and balance.

## Stalker passive comparisons

The new scenario uses the current level-8, 600-HP Stalker, level-5 hero, common gear,
one Minor Healing Potion and a six-tile approach. Known Charge opens normally.
Prepared entries set 90 rage before resolving maintenance buffs; Battle Shout adds 10
when known. They start without points/procs/summons.
Mixed DW coatings stay the same when removing Catalytic Venom. Cold entries apply Instant.
Live actions handle the fight; the first three seeds of every cell replay on plain
`GridWorld`. Effective boss damage excludes overkill; effective healing excludes overheal.
Player HP loss and post-mitigation incoming damage including fatal overkill are both saved.
HP conservation and source accounting are asserted on every measured/pilot fight.

Skip Anger Management (between encounters), Victory Rush (terminal single kill),
Sweeping Strikes (no second enemy), Pursuit of Justice (route value), and Relentless
Assault (core finisher dependency). Off-hand-only passives use DW trials only.
Some native-kit passives have no triggering attack, such as Rogue Seal Fate/Bandit's
Guile with only a finisher; retained all-kit trials exercise those interactions.
The same pilot-selected bot policy is used for each baseline/removal pair. This measures
the effect of removal under that policy, without separately optimizing a replacement.

After all three normal shards, summarize using Python's standard library:

```powershell
python bench/analyze_stalker_passives.py <shard0/result.json> <shard1/result.json> <shard2/result.json> --output reports/bench/stalker-passives/analysis
```

CSV files include all baseline cells and both per-cell and pooled passive effects.
`passive_summary.csv` puts native-kit damage and all-kit damage/healing/HP-loss
effects with intervals and adjusted p-values on one row per tested passive.
Pooled results weight weapon/entry strata equally and pair outcomes by seed, averaging
within each seed before estimating uncertainty to avoid treating reused seeds as
independent trials. Approximate 95% Student-t intervals are unadjusted; Holm-adjusted
p-values correct across all passive/context tests for six main outcomes (boss damage,
healing, player damage taken, turns, wins and damage per turn). Raw incoming damage,
class-only healing and final HP are exploratory.
Baseline win rates use Wilson-style bounds with seed blocks as the sample count,
using the binomial variance envelope for pooled fractional block outcomes.
Deltas use full kit minus removed passive. Effects are conditional and cannot be summed;
lower incoming totals can also mean an earlier death, so read wins, damage and turns together.

## Coordinated rotation comparisons

`priority_sim.gd` uses production combat rules. `priority_world.gd` only observes
active decisions, combo points, Maelstrom stacks and rage. Every measured fight
reconciles enemy damage and player HP/healing; the first ten seeds per cell replay
against plain `GridWorld`, including final combat RNG state. There is no policy
selection on measured seeds or claim that these bots are optimal.

Normal runs contain 420 cells, 12,600 fights and 4,200 replays. Shards 0/1/2 select
one weapon each; run sequentially. Smoke uses two seeds per cell. Starter Shaman knows
only its free pair; other named kits are fully learned, with initial Warrior learning
cleared. This covers missing passive dependencies without modeling a purchase route.

Ordinary enemies start adjacent. Stalker permits Charge from six tiles; Pull starts
six tiles away with Charge unavailable. Prepared entries cast available poisons,
Windfury, Lightning Shield and Battle Shout last, starting from zero rage. Real turns,
rage decay, buff aging and regeneration apply; health is not refilled. Fight turns
exclude preparation turns, which are recorded separately. Cold entries have no buffs.
Points, stacks and ready procs start empty except BankedPull, which explicitly seeds
five Maelstrom stacks. Durable3 triples thug HP as a synthetic stress case. These two
stress cases run only on the complete kit. Gift items are excluded; one minor healing
potion is allowed against Stalker.

The intent policy follows the owner's offensive ordering, with emergency defenses
and potion use first. Alternate complete-kit policies move Mortal Strike first,
spend Lava at four stacks, prioritize empowered Judgement over Lava, or prioritize
a five-point finisher when Slice and Dice is absent. Target longevity uses a simple
weapon-damage estimate; movement and missing preparation are fallback actions.
These isolated encounters do not model routes, clone reinforcements, level-up healing
or uncommon equipment. Human QA still decides feel and balance.

Summarize one run or nonoverlapping weapon shards with Python's standard library:

```powershell
python bench/analyze_priorities.py <result.json> ...
```
