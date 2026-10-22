# Temporary simulation bench

Disposable design tools, kept in Git because they are useful to reuse. These scripts
call the current game model; the game never loads the bench. `.gdignore` keeps them
out of editor imports and normal script validation. The launcher loads them explicitly.
No separate project, dependency upgrades, or simulation framework.

`stalker-mechanics` and `stalker-patterns` suppress production Fel Breath to isolate
experimental Enrage, recovery and cone variants. Their `live` output label denotes
the experiment's control, not the full production encounter. Replays use unobserved
experimental worlds. Experimental cones reset and pause the Stalker's weapon interval
through the breath; other encounter scenarios use current game rules.
Ordinary live Stalker bots sidestep the marked Fel Breath cone before continuing
casts or attack commitments. The response spends a real movement action, respects
movement credit, prefers remaining in melee and avoids walking back into the cone.
Standing in breath belongs only in an explicitly labelled failure/stress policy.

From the repository root, after the normal [setup](../docs/development.md):

```powershell
pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Smoke
pwsh -NoProfile -File tools/simulate.ps1 -Scenario shield-block
pwsh -NoProfile -File tools/simulate.ps1 -Scenario aoe-interactions -Shard 1
pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario paladin
pwsh -NoProfile -File tools/simulate.ps1 -Scenario rogue
pwsh -NoProfile -File tools/simulate.ps1 -Scenario stalker-passives -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario stalker-full -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario stalker-full -BaselineOnly
pwsh -NoProfile -File tools/simulate.ps1 -Scenario stalker-mechanics -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario stalker-patterns -Confirm
pwsh -NoProfile -File tools/simulate.ps1 -Scenario stalker-patterns -Confirm -Policy after-breath
pwsh -NoProfile -File tools/simulate.ps1 -Scenario priorities -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario pulls -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario pull-tuning -Confirm -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario accessories
pwsh -NoProfile -File tools/simulate.ps1 -Scenario loot -Smoke
pwsh -NoProfile -File tools/simulate.ps1 -Scenario loot-rates -Smoke
```

| Scenario | Purpose |
| --- | --- |
| `restless-stalker`, `restless-pulls` | Focused Restless Blades enabled/removal pairs, 100 shared seed blocks per cell. All four kits, live prepared entry, all three weapons, unchanged coordinated intent policy. Stalker uses L5/common gear/one potion and sidesteps breath; 16-enemy L4 pulls use common and uncommon gear with no consumables. No gifts, Vanish strategy or general kiting. Every fight reconciles damage/HP; three plain-world replays per cell. Stalker smoke checks exercise all eight cone directions, movement credit and cast cancellation; measured fights require zero player exposure at breath release. |
| `aoe-interactions` | Live Consecration/Vanish/Whirlwind and Shield Block/Evasion interactions. 20 paired seed blocks per cell, common/uncommon gear, 1/8/16/32 L4 thugs plus an eight-enemy 10x-HP cooldown stress case. Warrior/Paladin/Rogue retained; all-kit control at 16 enemies. Compare immediate burst, hiding through ground ticks, and removal of Restless Blades/Seal Fate; shield trials separate Block, Evasion, both and neither. No Divine Shield, summons, gifts or potions. Three plain-world replays per cell; records cooldown reductions, cast intervals, defensive coverage and gross damage taken separately from healing. Shards 0/1/2 select weapons. |
| `shield-block` | Controlled shield-only 30% chance to remove 70% of a physical hit. Full Warrior against groups and all kits against Stalker; 400 seeds, cold/live preparation, current weapons as controls. Removes learned live Shield Block to avoid double application; the experiment's separate block RNG preserves baseline combat draws. Remaining damage rounds up. No game data changes. |
| `garrick` | First-Loop Warrior at levels 3–5, the reported Shout/Weapon Mastery/Charge/Execute purchases versus adding Enrage/Death Wish, common gear versus green shield with a Strength or Agility ring. Paired live fights compare Garrick profiles; wins and mean remaining HP including deaths are recorded. No potions, kiting, route damage or XP healing. |
| `warrior` | Full Warrior kit, three weapons, cold/prepared entry, groups and Stalker; paired potion runs for Stalker. Independent pilot seeds select the rotation. Traced damage is reconciled and replayed against plain `GridWorld`. |
| `warrior-harder` | Harder groups using policies from a previous `warrior` result. Supply `-Baseline reports/bench/warrior/<run>/result.json`. |
| `paladin` | Full Paladin, Warrior + Paladin and all four kits; single enemies, groups and Stalker, three weapons and cold/prepared entry. Independent pilots select Holy-first, physical-first or Holy-first without ground. Damage reconciles to enemy HP and sample fights replay on plain `GridWorld`. |
| `rogue` | Full Rogue, Warrior + Rogue and all four kits, using the same encounters, gear, entry states, pilot priorities and replay checks as `paladin`. Spend at 3+ points, including while passive haste is active. |
| `stalker-passives` | All 15 retained-kit combinations against Stalker, then one-passive removals in its own kit and all four kits. Records actual player healing/losses as well as boss damage. 200 baseline seeds, 100 matched removal seeds, independent 40-seed policy pilots; three weapons and cold/prepared entry. Use shards 0/1/2 sequentially. |
| `stalker-full` | Current coordinated rotation with all four kits fully learned, against Stalker only. 200 baseline seeds with and without trainer gifts; 100 paired seeds per passive removal with gifts. Three weapons, cold/live prepared entry; use shards 0/1/2 sequentially. |
| `stalker-mechanics` | Experimental 20%-HP Enrage and one four-turn recovery at 50% HP. Pilots ordinary spending, reacting and several banking policies across all four three-kit builds plus all kits, all weapons. Every build retains the initial Warrior MS/Whirlwind pair; Shaman/Paladin/Rogue has no purchased Warrior skills. Recovery always exceeds the interruption requirement. 30 pilot seeds; `-Confirm` compares ordinary and spell-only banking for live plus 150/180 and 150/240 on 100 fresh seeds (4800000+). Spell banking holds Lava/Judgement from 70% and MS from 60%, preserving their rage costs while keeping finishers/haste and affordable other spending active. Prepared common gear, no gifts. Omits cone attacks. |
| `stalker-patterns` | Isolates Enrage, then adds a locked three-tile cone with two full response turns. Four three-kit paths including Warrior starters, all weapons. Compare early/late sidesteps, saving burst or defenses for Enrage, wider dodges with ranged burst, saving Divine Shield for a cone, and ignoring it. First wind-up after four normal turns, then ten normal turns between casts; casting/channel time excluded. Cone can kill summoned wolves. Includes 150/180 recovery with/without banking; pilots also test eight/twelve-turn gaps. 20 pilot seeds, 60 fresh with `-Confirm`; same gear/preparation as mechanics. |
| `priorities` | Live requested priorities on starter Shaman, full Shaman/Paladin, all four three-kit combinations and all kits. Five priority alternatives on all kits; ordinary groups, Stalker, ranged pulls and durable-group/banked-stack stress cases. Cold/live prepared entry, 30 seeds per cell, three weapons; sample fights replay against plain `GridWorld`. |
| `pulls` | Prepared fully retained kits against 1-32 same-level regular thugs, with common/uncommon gear and usual/AoE priorities. Controls cover kobolds, banked entry, Warrior alone and removing Victory Rush. 20 seeds per cell; per-turn incoming damage/healing and plain-world replays. Shards select weapons. |
| `pull-tuning` | Prepared pulls only. Pilot alternate Wrecking Crew/Consecration tuning and shared Victory Rush trigger cooldowns, then use `-Confirm` for actual game data on fresh seeds, with defensive skills disabled, emergency use or proactive use. Includes a 64-enemy two-hand stress case. |
| `accessories` | Expected auto-attack damage and physical effective HP for common gear, upgrades and primary stats. No active rotation; `-Smoke` runs the same calculation. |
| `loot` | Seeded valley loot, obtainable loadouts, estimated auto-attack gains, and a full-route gold budget beside total training costs. |
| `loot-rates` | Compare candidate uncommon drop rates on copied loot tables. These are experimental rates, not live tuning. |

For `stalker-patterns`, `-Policy after-breath` runs a focused additional strategy on
Enrage/cone and the full encounter: keep wolves until the first breath resolves,
prioritize them just after a breath, and avoid wasting defenses during safe cast
windows. It uses the same fresh seeds with `-Confirm`; combine the two result files
in the mechanics analyzer for paired comparisons. This strategy sidesteps immediately;
the focused run adds the matching immediate-sidestep control for the full encounter.
Pattern policies avoid overlapping active Divine Shield and Evasion. Use matched
controls from the same setup for comparisons.

`-Smoke` reduces combat/loot samples for a wiring check, not a design conclusion.
For the focused Restless Blades pair, run `-Scenario restless-stalker` and
`-Scenario restless-pulls` sequentially. Summarize their result files with
`python -B bench/analyze_restless.py <stalker/result.json> <pulls/result.json> --casts`.
Weapon strata are averaged within each shared seed before paired intervals; the
analyzer adjusts the win/damage-per-turn comparisons together with Holm's method.
These are effects under a fixed full-kit bot, not optimal play or an unlock-route estimate.
Stalker results also include timestamped casts, damage/healing events, player/boss HP
and active defensive states. Use these to distinguish earlier damage from avoiding
a later enemy attack. Breath release/exposure and dodge counts verify the response.
The observer replays on plain `GridWorld` without changing combat outcomes or random draws.
Summarize AoE interaction cells with
`python -B bench/analyze_aoe_interactions.py <result.json> ...`.
The default selects 16 regular enemies and Warrior/Paladin/Rogue learning;
`--count 8 --scale 10` selects durable cooldown stress, `--build All` the full-kit
control, and `--suite defense` the shield comparisons. Cast gaps include only
fights that reached another cast; read them with cast counts, wins and fight length.
Run `-Scenario aoe-interactions -Policy cooldowns -Shard 1` for focused one/three-enemy
durable controls: longer fights with live player HP, to compare repeat cooldown use
against single-target combat. These use the same policies and 20 samples per cell.
Stalker mechanics uses live actions with experiment-local boss changes. The full
four-turn channel suppresses boss movement and melee while player weapon timers advance.
It counts all actual damage after the triggering boundary through the final response's
summons. Success prevents healing at the deadline; it does not end the pause early.
Thresholds never rearm after healing. Player and boss HP accounting includes recovery;
control and candidate samples replay on the unobserved experiment.
Use `python -B bench/analyze_stalker_mechanics.py <result.json> ...` to summarize,
adding `--cells` for build/weapon detail. Shared seeds are paired strata, not extra
independent samples. `--three-only --by-build` separates the three-kit target from
the all-kit control. `--paired` prints nominal seed-block bootstrap intervals for
win differences, without adjustment for exploratory comparisons. The mechanics-only
scenario omits cone costs; both scenarios omit route and reinforcement pressure.
Garrick's `-Confirm` runs only the live profile on fresh seeds after candidate tuning;
its normal run compares the live profile with modest trial profiles.
Omit it for the normal sample counts held in each script. Warrior `-Shard 0/1/2`
selects two-hand/shield/dual wield; omit it to run all three. A harder run needs a
baseline covering its selected weapons. Use a non-smoke baseline for design decisions.
Paladin also accepts `-Shard 0/1/2` for two-hand/shield/dual wield; omit it for all three.
Rogue accepts the same shards. Cold entries apply Instant Poison; prepared dual-wield
entries start with faster-weapon Instant and slower-weapon Deadly. Eviscerate spends
at three or more points and applies learned Slice and Dice passively.
Warrior, Paladin, Rogue and `stalker-passives` construct their prepared entries with
90 rage and fresh buffs. `priorities`, `stalker-full`, `pulls` and `pull-tuning` use
live preparation from zero rage. Read each scenario's setup before comparing results.
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

Human playtests decide feel, readability and balance.

## Stalker passive comparisons

`stalker-passives` uses the current level-8, 600-HP Stalker, level-5 hero, common gear,
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

For current full-unlock passive trials, use `stalker-full`. It inherits the production
`priorities` intent bot and live preparation below. `stalker-passives` uses pilot-selected
Paladin-style priorities and constructed 90-rage entry. Gift runs carry all four
already-earned trainer rewards: use the totem then banner after entering melee, carry
the charm, and leave the single-target-irrelevant horn unused. Removals keep the gifts
to avoid confounding a lost passive with lost gift eligibility. The no-gift baseline
separates reward items from current skill power. Gift timing is fixed, not optimized.

The same five passive exclusions and off-hand restrictions apply as above. Removing
Seal also disables dependent Judgement; removing Maelstrom suppresses the bot's
full-stack Lava choice; removing Art of War removes its stronger empowered-crit
opportunity. Interpret these as dependency-family effects. Every fight checks effective
HP/healing accounting, including the narrow charm-break event. First three seeds per
cell replay on plain `GridWorld`. No game rules are overridden.

Use `-BaselineOnly` to skip passive removals and run all 12 baseline cells (2,400
fights without `-Smoke`). Summarize all three current shards with:

```powershell
python -B bench/analyze_stalker_passives.py <shard0/result.json> <shard1/result.json> <shard2/result.json> --all-only --output reports/bench/stalker-full/analysis
```

The analyzer also accepts one unsharded `-BaselineOnly` result with `--all-only`;
it writes baseline summaries and omits empty passive-removal tables.

Intervals and the global Holm correction use the same seed-blocked method above,
with only the all-kit context in the family. Native-kit columns are blank in the
compact summary because this scenario deliberately does not run native kits.

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

## Same-level pulls

`pulls` uses real level-4 thugs against a level-4 hero with all four kits retained;
the worker control uses level 3 on both sides. There is no level-5 regular enemy
profile in the current data. Enemies occupy concentric rings in an open arena:
eight can be adjacent, and larger packs queue behind them. All begin engaged with
fresh swing timers. The bot focuses wounded adjacent targets and never kites.

Complete common and uncommon loadouts each use one Strength ring and one Agility
ring. Uncommon is an equipment ceiling, not a guaranteed route. Preparation uses
live zero-rage actions; no points/stacks/procs are assigned except in the explicitly
banked momentum control. No trainer gifts, potions, XP or level-up healing.
The AoE policy moves Whirlwind and uncovered Consecration ahead of single-target
actions at three adjacent targets, retaining emergency defenses. Policies are fixed,
not optimized. The no-Victory-Rush control measures one passive's contribution under
that policy, not an alternative build optimized after removing it.

Each fight checks enemy damage and player HP conservation; three seeds per cell
replay against plain `GridWorld`, including combat RNG. Sample timelines record real
world turns, including turns advanced by attack bumps. Thirty-two enemies is a tested
bound, not a theoretical maximum; gathering costs, terrain and player decisions can
change the practical result. Raw results stay in ignored `reports/bench/pulls/`.

Summarize a run or nonoverlapping weapon shards with:

```powershell
python -B bench/analyze_pulls.py <result.json> ...
```

Incoming damage is post-mitigation and includes fatal overkill; effective healing
excludes overheal. Read throughput alongside wins: early deaths shorten fights.

### Pull tuning and confirmation

`pull-tuning` uses ten pilot seeds per cell with candidate values on experiment-local
learned skill instances; game data is not changed by the launcher. `-Confirm` uses
forty fresh seeds per cell and the actual current game data. Both modes use the same
prepared setup and accounting as `pulls`; no cold starts are considered. Shards select
weapons, and launchers must run sequentially. Smoke uses two seeds per cell.

Candidates change only Wrecking Crew's extra Whirlwind damage while its buff is active,
Consecration's flat damage and Victory Rush's shared internal cooldown. Whirlwind never
triggers Sweeping Strikes. Confirmation compares disabled Divine Shield/Evasion,
the original emergency policy, and proactive Evasion with low-health Divine Shield
without overlap. The two-hand shard also tests 64 enemies with the proactive policy.
Other offensive choices and healing sources remain available in every policy.

Use `analyze_pulls.py` for either mode. Results identify the candidate and defensive
policy, report effective healing and damage, and retain sample decision/turn traces.
Pilot choices are exploratory; confirmation measures fixed policies rather than
optimal play or a universal safe pack size. Trainer gifts and consumables are excluded.
