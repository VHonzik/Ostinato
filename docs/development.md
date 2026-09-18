# Development

The project currently runs a title scene on Windows with Godot's Compatibility renderer.
Gameplay follows the [functional](requirements/functional.md) and
[non-functional](requirements/non-functional.md) requirements. The Git remote is
[VHonzik/Ostinato](https://github.com/VHonzik/Ostinato); CI and exports are not configured yet.

## Tools

Exact versions, download URLs, and hashes are in [tools/versions.json](../tools/versions.json).

| Tool | Version or prerequisite |
| --- | --- |
| Godot | 4.7.2 stable, standard Windows x64 GDScript build |
| Exact engine output | `4.7.2.stable.official.ed1daf0bf` |
| Export templates | 4.7.2 stable; install when exports are needed |
| GUT | 9.7.1, vendored in `addons/gut/` with its MIT license |
| PlantUML | 1.2026.8, cached in `bin/`; uses Smetana, no Graphviz needed |
| PowerShell | 7+ |
| Java | 17+ on PATH |

Use the pinned [Godot release](https://godotengine.org/download/archive/4.7.2-stable/) and
[GUT release](https://github.com/bitwes/Gut/releases/tag/v9.7.1).
Upgrade dependencies deliberately in a separate change, keeping this guide, the pins,
and CI aligned.

## Setup and launch

Run from the project root in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/godot.ps1 --version
pwsh -NoProfile -File tools/godot.ps1 --editor
```

Setup downloads missing pinned Godot, GUT, and PlantUML dependencies and checks their hashes.
It can be rerun; mismatched Godot/PlantUML files are errors and existing GUT is checked for
its declared version without being overwritten. Downloads need network access. Export
templates are unnecessary for editor use and validation.

Run the configured main scene without the editor:

```powershell
pwsh -NoProfile -File tools/godot.ps1
```

The wrapper locates the project and pinned console launcher and forwards Godot arguments.
In the editor, F5 runs the main scene and F6 the open scene. The current title scene needs
no fixtures or save data.

## Project layout

- `scenes/main.tscn`: startup scene.
- `test/unit/`: GUT tests; all project test suites belong under `test/`.
- `tools/`: setup, launch, validation, dependency pins, and GUT report hook.
- `docs/architecture/`: PlantUML sources for implemented systems.
- `addons/gut/`: pinned third-party dependency.
- `reports/`: generated local logs, test results, and diagrams; ignored by Git and Godot.

Follow [coding-style.md](coding-style.md). [.editorconfig](../.editorconfig) and
[.gitattributes](../.gitattributes) define formatting and LF normalization.
[.gitignore](../.gitignore) excludes downloaded tools, caches, reports, and builds.
Keep GDScript UID files and asset `.import` sidecars to preserve resource identities.

## Validation

Use the same entry point locally and in CI:

```powershell
pwsh -NoProfile -File tools/validate.ps1
```

It verifies tool pins and test configuration, imports resources headlessly, checks every
first-party GDScript, runs startup for 120 iterations, runs the complete recursive GUT suite
with error tracking, and renders every PlantUML source as SVG and PNG. Discovery is checked
against detailed JSON and JUnit results so unrun or missing tests cannot pass.

Unexpected diagnostics, nonzero exits, timeouts, resource leaks, missing reports, zero
tests, or failed/pending/skipped/risky tests fail validation. Focused test filters are rejected.
Negative tests must assert specific expected errors; do not disable error tracking or broadly
suppress diagnostics. See [AGENTS.md](../AGENTS.md) for test-integrity rules.

Each child process has a 120-second wall-clock limit. Increase it explicitly when needed:

```powershell
pwsh -NoProfile -File tools/validate.ps1 -TimeoutSeconds 240
```

Results are generated in `reports/validation/<run-id>/`. Inspect the latest summary and
its logs, including on failure:

```powershell
$reportDirectory = (Get-Content reports/latest-validation.txt -Raw).Trim()
Get-Content (Join-Path $reportDirectory 'summary.json')
```

The shared process helper provides timeouts and logs for each tool. The GUT report hook
adds discovery/status/error details absent from JUnit so the runner can verify completeness.
Startup checks cover only the scene they exercise; add meaningful tests as gameplay appears.

Render diagrams independently with `pwsh -NoProfile -File tools/render_diagrams.ps1`.
Inspect changed diagrams for readability.

## Pull requests

Use the [PR template](../.github/pull_request_template.md) for a short change summary,
automated results, and feature QA steps. Include extra scene/setup/reset details only when
needed to try the change. Human reviewers decide QA scope, any QA records, acceptance, and
merging. Keep handoff information in the PR; local work without a PR needs only a brief
completion message. Bootstrap and maintenance work need no feature acceptance paperwork.
