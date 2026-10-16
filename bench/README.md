# Temporary simulation bench

Disposable design tools, kept in Git because they are useful to reuse. These scripts
call the current game model; the game never loads the bench. `.gdignore` keeps them
out of editor imports and normal script validation. The launcher loads them explicitly.
No separate project, dependency upgrades, or simulation framework.

From the repository root, after the normal [setup](../docs/development.md):

```powershell
pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Smoke
pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Shard 0
pwsh -NoProfile -File tools/simulate.ps1 -Scenario accessories
pwsh -NoProfile -File tools/simulate.ps1 -Scenario loot -Smoke
pwsh -NoProfile -File tools/simulate.ps1 -Scenario loot-rates -Smoke
```

| Scenario | Purpose |
| --- | --- |
| `warrior` | Full Warrior kit, three weapons, cold/prepared entry, groups and Stalker; paired potion runs for Stalker. Independent pilot seeds select the rotation. Traced damage is reconciled and replayed against plain `GridWorld`. |
| `warrior-harder` | Harder groups using policies from a previous `warrior` result. Supply `-Baseline reports/bench/warrior/<run>/result.json`. |
| `accessories` | Expected auto-attack damage and physical effective HP for common gear, upgrades and primary stats. No active rotation; `-Smoke` runs the same calculation. |
| `loot` | Seeded valley loot, obtainable loadouts and estimated auto-attack gains. |
| `loot-rates` | Compare candidate uncommon drop rates on copied loot tables. These are experimental rates, not live tuning. |

`-Smoke` reduces combat/loot samples for a wiring check, not a design conclusion.
Omit it for the normal sample counts held in each script. Warrior `-Shard 0/1/2`
selects two-hand/shield/dual wield; omit it to run all three. A harder run needs a
baseline covering its selected weapons. Use a non-smoke baseline for design decisions.
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
The committed [October balance snapshot](../balance/2026-10-14/results.md) is historical;
its source copies describe that run, not the current bench. Human playtests still decide
feel, readability and balance.
