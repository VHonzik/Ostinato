# Development

Windows x64 is the primary platform, with a secondary Android ARM64 build.
Godot Compatibility renderer, typed GDScript.

## Setup and launch

Use PowerShell 7 from the repository root:

```powershell
pwsh -NoProfile -File tools/setup.ps1
pwsh -NoProfile -File tools/godot.ps1 --editor
# Or run the game directly:
pwsh -NoProfile -File tools/godot.ps1
```

[tools/versions.json](../tools/versions.json) is the dependency authority:
Godot `4.7.2.stable.official.ed1daf0bf`, GUT `9.7.1`, matching `4.7.2.stable`
export templates when exporting. Setup checks hashes and does not overwrite mismatched
installed dependencies. GUT is vendored with its license. Windows exports and Actions
use these same pins.

## Current build

The project targets a playable demo of the full game. The main menu displays
**Ostinato (Demo)**; the valley is the demo's playable scope.

**New Game** offers five named world seeds, then launches the valley, the sole playable
map, as a Warrior with Mortal Strike and Whirlwind. The player menu shows the chosen
world name. Speak to Marshal McBride north of spawn, ask Janos inside the
abbey for starter gear, and use quests, trading and training to prepare for the gate.
Death rebuilds the physical world; learned abilities and hotbar assignments persist.
Returning Loops begin with class selection; other classes unlock from Loop three.
Defeat every currently present stalker to complete the demo.

Use the authoritative references for current content and code entry points:

- [Class mechanics and abilities](class-mechanics.md): training, costs, combat rules,
  passives, effects and trainer gifts.
- [Quests, dialogue and NPCs](npc-dialogue.md): contacts, objectives/rewards, speech,
  encounter profiles, arrivals and Loop state.
- [Game direction](direction.md): design goals and open gameplay decisions.
- [Art workflow](../art/README.md) and [art direction](art-plan.md): sources and presentation.

### Controls

Movement, hotbar and menu bindings can be changed in Options → Keybindings.

| Action | Default input |
| --- | --- |
| Move | WASD + QEZC, arrows or numpad |
| Wait | Period / numpad 5 |
| Interact | F; bump friendly NPCs; bump a stationary neutral twice to attack |
| Inventory / spells / quests / character | I / K / J / P |
| Player menu | M |
| Lower hotbar | 1–6, R, T, G, V |
| Upper hotbar | Shift plus the same keys |
| Confirm / cancel | Enter / Escape |
| Options / fullscreen | Escape when no action/menu is open / F11 |

Held movement waits 0.5 seconds, then repeats every 0.15 seconds. Targeted abilities
use the committed enemy or a target picker according to their rules. Automatic
swings continue against the selected enemy in melee during movement, waiting and
abilities. Attack bumps animate sequentially; input waits for them to finish.
K → Development provides XP, gold, Death trigger and Kill stalker in development builds.

### Equipment and interaction

Equipment uses armor, neck, two rings and one weapon setup. Two-hand, shield-pair
and dual-wield setups each occupy one slot. All classes can use all gear. Bags sort
by quality, then name; replacement previews compare the selected equipment slot.
Empty equipment slots auto-equip received gear. An inventory hint marks higher-quality
bag items available for equipped slots.

Usable bag items offer **Assign to hotbar** while the layout is unlocked. Receiving a
healing potion assigns it immediately left of Food when that slot is empty in the same
row and no potion shortcut exists. Saves retain the player's exact assignments, including
empty slots; loading does not auto-assign items.

Closed chests block movement. Bumping opens their loot menu without collecting or
spending a turn; full bags preserve uncollected loot. Bumping a newly killed enemy
opens loot until the player moves; later corpse interaction uses F. Ordinary
loot-bearing corpses hide after 300 turns; the guard's corpse remains.

### Saves and settings

Saving requires an action boundary outside combat. Five slots use the `demo` family,
revision 2; other revisions are incompatible and left untouched. No migration is
provided. Failed writes/loads preserve existing files and the running world.

Saves live in `%APPDATA%/Godot/app_userdata/Ostinato/saves/`; global settings are in
`options.json` beside that directory. Tests use isolated save locations. See the
content references above for effect, quest and NPC persistence.

## Editing the valley

Open [valley.tscn](../scenes/valley.tscn) in Godot's 2D editor. It is the layout
source read by New Game and death/Loop reset; the existing grid simulation and
`GridView` still run and draw the game. Run the main project to play the layout.

- `Terrain/Background` paints open ground and the blocked exterior.
  `Ground` paints roads, floors and soil. Abbey/mine floor tiles also mark indoors.
- `Terrain/Scenery` paints the original 16px art, scaled twice; `Props` paints the
  32px valley art. Both use tile custom data for movement/sight blocking. Flowers,
  bushes, small rocks, grass and signposts remain passable. Paint/erase cells in the
  TileMap editor; keep the terrain layers' transforms as supplied.
- `Actors` contains sprite placeholders for every initial contact, enemy and chest.
  Move them with 32px grid snapping. Positions are sprite centers (16px grid offset);
  the containing tile becomes the actor's starting/home tile. `wander_radius` sets
  its patrol area around that home; zero keeps it stationary.
- Keep an actor's `spawn_id` when moving it. When adding a creature by duplicating a
  placeholder, give it a unique `spawn_id` and `turn_order`; that order governs turns
  independently of tree order. `npc_id` selects existing contact/creature data. The
  Sprite2D texture/scale is an editor preview; update it when changing creature type.
  Contacts retain their identities/dialogue in `NpcDefinition`; creature stats remain
  in `NorthshireData`. Chests also carry a unique `treasure_id` and exploration hint.
- `PlayerSpawn`, ordered `StalkerEntries` markers and `Exploration` regions set their
  corresponding locations. Exploration regions expose their size in tiles. The map
  root exposes bounds and stalker deadlines. Summons and timed arrivals spawn during play.

The TileSets under [assets/tilesets](../assets/tilesets/) reference the existing sprite
sheets directly. Their `sprite`, `blocked` and `indoors` custom data feeds the grid
model; Godot physics collision shapes are not used for movement.

Start a New Game to test the complete edited layout. Saves retain enemy/chest placements,
collision and indoor state; fixed contacts except the guard follow current scene
positions on load. The northeast corner of the northern abbey room is passable despite
its wall art.

## Checks

Design experiments use the temporary [simulation bench](../bench/README.md), launched
with `pwsh -NoProfile -File tools/simulate.ps1 -Scenario warrior -Smoke`.
Its source is tracked separately in `bench/`; generated results, logs and runtime files
stay under ignored `reports/bench/`. Use the documented launcher for reusable approval.

```powershell
# Default: headless import, load/check first-party scripts, startup. No unit tests.
pwsh -NoProfile -File tools/validate.ps1

# Same quick checks, then all tests in the chosen file(s):
pwsh -NoProfile -File tools/validate.ps1 -Test test/unit/test_grid_world.gd
# Multiple files from PowerShell:
./tools/validate.ps1 -Test test/unit/test_grid_world.gd,test/unit/test_saves.gd

# Quick checks and the complete recursive GUT suite:
pwsh -NoProfile -File tools/validate.ps1 -Full
```

Use targeted tests for behavior changes; full tests for changes across many systems,
validation-tool changes, or an explicit request. Docs-only edits need a diff/link check.
Do not repeat a full run after a later prose-only edit. Add meaningful tests where they
protect behavior; remove obsolete tests when that behavior deliberately goes away.

Each process has a 120-second timeout; override with `-TimeoutSeconds 240` when needed.
Failures, unexpected diagnostics, incomplete test discovery, and pending/skipped tests
within the selected scope fail the command. A quick or targeted pass does not certify
all gameplay. UI layout, text readability, clipping, and resolution suitability are human review.
Do not automate visual acceptance; UI tests cover input and state changes. Tests and
startup checks do not establish visual quality or fun.

Output is a short scope/result summary. Logs are temporary and removed on success;
failures retain them under ignored `reports/validation/`. Use `-KeepLogs` to retain a
successful run for debugging. No written validation report is required.

Validation runs offline with a fresh Godot profile under that run's
`reports/validation/<run>/runtime/`, isolating editor settings, user data and temporary
files from your normal profile. A hash-checked [Mozilla CA bundle](../tools/certs/README.md)
supplies import and startup certificates, so validation does not need access to the
Windows certificate store. The launcher enables the `ostinato_validation` custom
feature only for its child processes; normal editor launches and exports keep their
usual settings. Sandbox permissions do not need to be relaxed for validation.

Run `pwsh -NoProfile -File tools/test_validation_tools.ps1` after changing the launcher.
Its real-engine fixtures cover profile isolation, cleanup and failure reporting;
full CI checks run them too. Fixture diagnostics stay under ignored
`reports/validation-tools/`.

## Windows exports

```powershell
pwsh -NoProfile -File tools/setup.ps1 -ExportTemplates
pwsh -NoProfile -File tools/export.ps1
# Optional local build label:
pwsh -NoProfile -File tools/export.ps1 -Version v0.1.0-rc.1
```

Setup downloads the pinned template archive, checks its SHA-256, and installs only
the Windows x64 release template under ignored `bin/export_templates/`. The installed
template is checked against its own pin on every setup/export. No global template
installation, editor binary in Git, or C# SDK is needed. Existing mismatched files
cause failure; investigate them before deliberately removing or replacing them.

[export.ps1](../tools/export.ps1) stages `assets/`, `scenes/`, `scripts/` and project
configuration in a fresh ignored `builds/windows/<run>/project/`. It imports and exports
with the committed [Windows preset](../export_presets.cfg), then runs the actual release
executable headlessly. The smoke check verifies version metadata, release mode, absence
of development abilities, main-menu startup, New Game and save/load. Its roaming/local
user directories are isolated under `reports/exports/<run>/runtime/`.

Each successful attempt prints its ZIP path and writes a neighboring `.zip.sha256`
file. Extract the ZIP and run `Ostinato.exe` inside its folder; keep `Ostinato.pck` and
`licenses/` with it. Godot need not be installed. The package contains runtime resources,
including the valley JSON atlas, and Godot/third-party notices. Tests, GUT, benchmarks,
tooling and editable art sources are excluded. Unsigned Windows x64 is the current target.

The menu shows the embedded version and short commit. Unlabelled local builds use
`dev-<commit>` with `-dirty` when there are uncommitted changes; `build_info.json` also
records the full commit, dirty state and engine version. Editor launches keep their
development version display. Staging never modifies source project settings or requires
`.git` in the package. Build logs remain under ignored `reports/exports/`; failed runs
have their own directories and cannot return an earlier ZIP. To allow a slower machine,
pass `-TimeoutSeconds 600`; the default is 240 seconds per process.

## Android exports and touch preview

Android runtime code and scenes live under [mobile/](../mobile/). The default entry
scene and Windows package retain desktop controls; Windows staging and its packaged
smoke check exclude mobile content. Both interfaces use the same game rules and save
codec. The Android exporter selects the mobile entry scene only in its staged copy.

Install the JDK and Android SDK packages matching the Android pins in
[tools/versions.json](../tools/versions.json). The standard prebuilt APK workflow uses
SDK platform-tools and build-tools; it does not compile Java/native engine code or
require Gradle, NDK or CMake. The scripts discover Java from `JAVA_HOME` or `java`,
and the SDK from `ANDROID_HOME` or `%LOCALAPPDATA%/Android/Sdk`. Supply `-JavaSdkPath`
and `-AndroidSdkPath` when necessary.

```powershell
pwsh -NoProfile -File tools/setup_android.ps1
pwsh -NoProfile -File tools/export_android.ps1
# Increment the Android version code when preparing a later update:
pwsh -NoProfile -File tools/export_android.ps1 -Version demo-android-2 -VersionCode 2
# Preview the touch interface using a mouse; this is not a device playtest:
pwsh -NoProfile -File tools/godot.ps1 res://mobile/main.tscn
```

Setup downloads the pinned template archive when absent, verifies it, and installs its
pinned Android templates independently of any installed Windows template.
It checks SDK/JDK versions and creates a local testing signing identity under ignored
`bin/android_signing/`. Keep that directory backed up to sign compatible updates; setup
does not replace incomplete or existing keys. Export uses an isolated editor copy and
settings under `bin/android_editor/`, leaving the normal editor configuration alone.
Passwords remain in ignored local credentials and process environment, outside presets
and build logs.

Exports go to a fresh `builds/android/<run>/` directory. The launcher prints the APK and
ZIP paths after verifying the signature, ARM64 architecture, package identity,
SDK levels, landscape-only orientation and release manifest. The ZIP contains the signed
APK, its checksum, build metadata and licenses; a neighboring `.zip.sha256` verifies the
archive. An APK build does not certify startup or touch behavior on Android.
Install the APK on an ARM64 phone
(Android 7 or newer), or use `adb install -r <apk>` from the SDK's platform-tools directory.
Google Play/AAB publishing, cloud saves and cross-device save transfer are outside this
local workflow. Tagged releases also build the Android ZIP in Actions.

The mobile interface uses eight arrows around Wait, the existing two hotbar rows,
and Menu/Interact. Hold an arrow to repeat; Wait is tap-only. Ability taps consume the
movement hold. Inspect abilities in Menu → Spells, then Use or Assign; assignment also
supports usable bag items. Menu → Log shows recent messages. Android Back cancels or
returns through the current UI. Backgrounding freezes the attempt until Resume.

Mobile recovery uses `user://recovery/recovery.json`, separate from the five manual
slots. Continue returns to the last completed safe save outside combat, which may
precede an interrupted encounter. See [Loop and save state](npc-dialogue.md#loop-and-save-state).
Files live in Android's app-private storage; uninstalling removes them. Test route
movement, target selection, spell/item assignment, trading, a death/Loop, and
background/resume on a real phone. Human playtesting decides control fit and readability.

## GitHub Actions

Both workflows use GitHub-hosted `windows-2025` x64 runners and PowerShell 7. Actions
are pinned to full commit hashes. Editor/template caches use the runner OS and the hash
of `tools/versions.json`; setup verifies restored binaries, and cache misses download
the same pinned dependencies. Downloaded archives and generated `.godot` imports
are not cached. Update dependency pins and action revisions deliberately.

| Trigger | Checks workflow behavior |
| --- | --- |
| Push to a feature branch | Quick import, script-loading and startup checks. |
| Pull request targeting `main` | Full validation and build-tool tests. |
| Push to `main` | Full validation and build-tool tests. |
| Manual run | Choose quick/full/targeted scope; optionally export a Windows release ZIP. |

In Actions → Checks → Run workflow, choose a branch and scope. `targeted` requires
comma-separated discovered test paths, for example
`test/unit/test_build_version.gd,test/unit/test_saves.gd`. Each path is validated by
the local validator. The workflow must first exist on the default branch for the manual
button to appear; write access is required. The CLI equivalent is:

```powershell
gh workflow run checks.yml --ref feature/my-change -f scope=full -f build=true
```

Download requested ZIPs from the run's Artifacts section. Artifacts and failure logs
expire after seven days. New check runs cancel obsolete runs for the same event and
branch/PR. An open PR can have both its quick push run and its full PR run. A manual
ZIP uses the chosen validation scope; it does not create a GitHub Release. Checks and
build jobs have read-only repository permissions.

The local tooling tests can also be run independently:

```powershell
pwsh -NoProfile -File tools/test_build_tools.ps1
```

These use isolated fixtures for tag parsing/ancestry, fresh and warm dependency setup,
corrupt downloads, installed mismatches and failed exports. They need the pinned editor
but no network or installed export template, and create no repository commits or tags.

### Repository setup and everyday operation

Land the workflow files through the repository's normal branch/PR process and keep
`main` as the default development branch. In Settings → Actions → General, enable
Actions and allow the GitHub-created `actions/checkout`, `actions/cache`,
`actions/upload-artifact` and `actions/download-artifact` actions. No custom runner,
variables, Environment or Pages setup is required. Android releases need the two signing
secrets described below. The default token setting can remain restricted/read-only:
the publish job explicitly requests
`contents: write`. Repository/organization policies must permit these workflows and
the requested job permissions. For private repositories, check Actions usage/budget
and fork-workflow availability. See GitHub's [Actions settings guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).

After a first check run, configure a `main` branch rule if merges should require a PR
and the passing `validate` job from Checks. Workflows alone do not prohibit merging a
failed PR. For maintainer-controlled releases, add a `v*` tag ruleset restricting
creation to the intended maintainers and protecting existing tags from updates or
deletion. Without tag restrictions, anyone who can push tags upstream can initiate
publishing for a qualifying commit. Rule availability depends on the repository's
plan/visibility; see [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
and [tag rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).

Contributors work on a branch, run local checks appropriate to the change, push the
branch, and open a PR targeting `main`. A push in this repository runs quick checks;
a push to a fork runs there only when its Actions are enabled. The upstream PR runs
the full checks, including on subsequent commits. Fix failed checks by pushing another
commit to the same branch. No release tag or manual version edit is needed for an
ordinary contribution.

Maintainers review the PR and its full result, approve any pending fork-workflow run
after reviewing its changes, and merge through the PR. GitHub then validates the new
`main` commit again. Fork approval policy is configured in Actions settings; read-only
checks need no fork secrets or write tokens. See [approving fork runs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/approve-runs-from-forks).

For a playable test build, a maintainer or contributor with upstream write access can
run Checks manually on a repository branch with `scope=full` and `build=true`. Download
the artifact and playtest the included ZIP. The manual selector does not select a
branch living only in another user's fork; that contributor can use local export/their
own fork, or a maintainer can arrange a reviewed upstream branch. Tests do not replace
the review of gameplay and presentation.

### Android release signing

Configure these repository Actions secrets from the existing ignored
`bin/android_signing/` identity before pushing a release tag:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 encoding of the bytes of `ostinato.keystore`. |
| `ANDROID_KEYSTORE_CREDENTIALS` | Complete contents of `credentials.json`, including `alias` and `password`. |

Keep using the same key for local and hosted APKs so Android can install updates over
the smoke-tested build. Back up the original key and credentials. The workflow restores
them only on the hosted runner; they are excluded from caches, artifacts and diagnostics.
Missing secrets fail the release rather than creating a replacement identity. Ordinary
Checks runs and their optional Windows ZIP need no signing secrets.

[setup_android_ci.ps1](../tools/setup_android_ci.ps1) downloads isolated JDK and SDK
archives with the URLs and SHA-256 pins in `tools/versions.json`, verifies them, and
checks the installed versions using the same toolchain rules as local export. Android
version names use the release tag; version codes use the Release workflow's increasing
`github.run_number` (reruns keep the same code). Keep any local update version codes
aligned with that sequence, and preserve the workflow's run numbering for later releases.

### Publishing a release

Keep `main` as development. Push a deliberately chosen tag for a commit already in
`main` history: `v0.1.0` creates a normal release; `v0.1.0-rc.1` creates a prerelease.
Only `vMAJOR.MINOR.PATCH` and `vMAJOR.MINOR.PATCH-rc.N` are accepted, with no leading
zeros and RC numbering starting at 1. Other `v*` tags fail validation; other tags do
not trigger the workflow. Tags can identify older commits in `main` history.

The maintainer first selects a successful `main` commit and playtests a full manual
build of that commit. Fetch current history, create an annotated version tag on the
chosen commit, and push that tag explicitly. Pushing the tag is the publish action:
there is no further manual release approval in this workflow. Do not create a release
on GitHub first; the workflow creates it after the checks. Start with an RC tag to
verify the complete hosted path. For a stable release, push the stable version tag on
the chosen commit; it runs validation and export again. No release branch or manual
version-file change is needed.

The release workflow fetches history and tags, requires a clean checkout at the tagged
commit, runs full validation and tooling tests, rechecks the checkout, and exports that
commit for Windows and Android. A separate publish job downloads both ZIP/checksum
pairs, verifies both hashes and that the remote tag still resolves to the same commit,
then creates a release with generated notes and all four files. Both exports must
succeed before publishing.
Only this job receives `contents: write` through `GITHUB_TOKEN`; no personal access
token or repository checkout is used for publishing.
RC releases are marked prerelease and not Latest. Publishing is serialized per tag.

For `v0.1.0`, the attached archives are `Ostinato-v0.1.0-windows-x64.zip` and
`Ostinato-v0.1.0-android-arm64.zip`, each with a matching `.zip.sha256` file.
A tag must contain the workflow files for this automation to run.
GitHub-hosted execution and publishing need verification on the actual repository;
local validation alone does not verify them.

For a failed run, inspect its step logs and diagnostic artifact, fix the cause, and
rerun the failed job(s) or the full workflow as appropriate. An existing release,
including a draft left by a failed upload, stops publishing. Review and deliberately
remove an unfinished draft before retrying; the workflow never overwrites published
assets or creates a missing tag. Fix a published build with a new version tag.

Before sharing, extract a manual ZIP outside the checkout and play on Windows: check
version display, New Game, movement/combat, save/load and absence of Development tools.
Headless checks establish behavior; humans judge appearance, readability and feel.
For Android, extract its ZIP and install the APK over the existing app on the phone;
check version display, retained saves, New Game and touch controls. Hosted export checks
the APK signature and manifest; it does not run an Android device smoke test.

## Where things live

- `scenes/`: main viewport, playable scene and editable valley layout.
- `scripts/world/`, `combat/`, `hero/`, `items/`, `quests/`: simulation, UI, and game data.
- `scripts/game_session.gd`, `save_codec.gd`, `save_store.gd`: Loops and persistence.
- `test/unit/`: behavioral GUT tests; `tools/`: setup, launch, and checks.
- `art/`: [editable Aseprite sources and sprite workflow](../art/README.md).
  Runtime sheets live in `assets/spritesheets/`; temporary SVGs in `assets/sprites/dev/`.
- `docs/direction.md`: durable intent; `docs/backlog.md`: local work, separate from design.

Follow [coding-style.md](coding-style.md); preserve `.gd.uid` and asset `.import` files.
Keep numerical data in code. Refactor only when it helps the current task.

Work stays local unless requested otherwise. Summarize changes and useful playtest
steps in chat; create no handoff file. Humans choose what to test and commit.
