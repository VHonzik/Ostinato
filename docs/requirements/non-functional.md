# Non-functional requirements

Status: **Implementation baseline**, 2026-09-18. Owner review incorporated; these are quality
targets and constraints, not measured results or human acceptance of the current project.

## Scope and use

Read together with [functional requirements](functional.md) and the pinned environment in
[development.md](../development.md). Stable `NFR-xxx` identifiers describe future verification.
No other requirement files are incorporated. The initial reference hardware and fixtures
below make performance work reproducible without requiring the final map to be designed now.

## Platform, rendering, and display

### NFR-001 — Initial platform and engine constraints

The demo shall support Windows 10 and Windows 11 desktop, x64, using Godot's Compatibility
renderer and GDScript as the main language. Engine, export templates, and GUT shall use the
exact pins in [development.md](../development.md) and [tools/versions.json](../../tools/versions.json).

Acceptance:

- Startup and core controls work on Windows 10 22H2 and Windows 11 24H2; record exact OS
  build and graphics driver for each compatibility run.
- Exported builds use matching export templates when exports are introduced.
- Renderer is Compatibility; dependency/tool upgrades are deliberate separate changes.
- The reference configuration below is the supported performance baseline, not a measured
  claim about the lowest hardware capable of running the game.

Other operating systems, mobile devices, and browser delivery are outside the demo.

### NFR-002 — Pixel-art rendering and aspect ratio

The game shall use pixel art with a **640 × 360 base art resolution**, viewport stretching,
uniform integer pixel scaling, and default clear color `Color(0.055, 0.07, 0.09, 1)`.
Aspect-ratio changes shall expand the visible world around the centered player rather than
distort art or force a permanently fixed 16:9 world view.

Acceptance:

- At 640 × 360 content pixels, the logical view is 640 × 360. At 1280 × 720 it is shown at
  2×; at 1920 × 1080 it is 3×.
- Choose the largest integer scale that fits the base art rectangle. Expand the logical
  viewport to cover remaining whole logical pixels in each axis. For example, 1280 × 800
  at 2× shows 640 × 400 logical pixels, revealing more world vertically.
- Any remainder smaller than one scaled pixel is filled with the clear color, distributed
  at opposite edges. Resize never changes simulation positions, range, or aggro.
- UI anchors and centered dialogs follow the actual viewport aspect ratio. Essential
  controls remain usable within the supported content rectangle.
- Existing sprite sheets are used where suitable; initial tile/sprite art is tentatively
  16 × 16 pixels. Pixel dimensions do not determine the 5-yard gameplay conversion in FR-025.

The bootstrap currently uses 960 × 540 and canvas-items stretching; it does not yet implement
this target. Final visual acceptance is performed on gameplay UI, not inferred from startup.

### NFR-003 — Minimum window and readable interface

The minimum supported window content size shall be **640 × 360 pixels**. Text and essential
controls shall remain readable and usable there and in resized/fullscreen presentation.

Acceptance:

- Use a review fixture containing a long conversation, multi-objective quest, spell/rank
  tooltip, full 40-slot inventory, all health/mana values, combat log, and five occupied save
  slots with timestamps and Loop counts.
- Start with a legible font at 12 logical pixels or larger for body text; human review may
  adjust typography. No font-size value alone establishes readability.
- Required controls remain accessible; scrolling or pagination handles overflow.
- Review at 640 × 360, 1280 × 720, 1280 × 800, and 1920 × 1080, including fullscreen toggling.
  The player can read and operate the fixture without clipped labels or inaccessible focus.

## Performance

### Reference configuration and benchmark fixtures

Use this fixed representative **2021 midrange gaming-laptop configuration**:

| Component | Reference |
| --- | --- |
| Model family | Lenovo Legion 5 15ACH6H |
| CPU | AMD Ryzen 5 5600H, 6 cores / 12 threads |
| GPU | NVIDIA GeForce RTX 3060 Laptop, 6 GB, 130 W configuration |
| Memory | 16 GB dual-channel DDR4-3200 |
| Storage | 512 GB PCIe 3.0 NVMe SSD with at least 20% free space |
| OS | Windows 11 24H2 x64 for performance; Windows 10 22H2 x64 also tested for compatibility |
| Display/power | 1920 × 1080, 60 Hz, fullscreen; AC power, performance mode, discrete GPU selected |
| Runtime | Release/export build when available; otherwise pinned standalone engine outside the editor, with build mode recorded; VSync on |

This is a practical representative chosen from the manufacturer's published configurations,
not a calculated market average. The [2021 Lenovo announcement](https://news.lenovo.com/pressroom/press-releases/lenovo-legion-goes-all-out-new-futuristic-gaming-machines/)
dates the family; the [manufacturer specification](https://psref.lenovo.com/syspool/Sys/PDF/Legion/Legion_5_15ACH6H/Legion_5_15ACH6H_Spec.pdf)
supports the component selection (that specification was revised in 2022). RAM/storage and
measurement settings above fix one reference configuration from the offered options.

Initial benchmark content shall be a 256 × 256-tile traversable map with buildings,
obstructions, wandering, and pursuit. Use three saved scenarios: ordinary exploration,
crowded combat with at least 20 nearby actors, and a late Loop with five stalkers.
Stress scenarios contain 100 active world NPCs including the five stalkers, plus one pet
and two elemental totems when those features exist. Saves also contain full inventory,
quest progress, buffs, loot changes, corpses, and pending replacements.

Record fixture seed, save, input sequence, build/content versions, and exact counts.
Benchmark the final populated map as well if it is larger or more costly than this fixture;
256 × 256 is a test workload, not a restriction on world design. Early partial milestones
may measure the systems they contain but cannot claim final-demo compliance.

### NFR-004 — Rendering performance

The game shall sustain **at least 30 FPS** on the reference configuration.

Acceptance:

- For each scenario, record 10 seconds of visible gameplay, sampled in ten consecutive
  one-second windows. Every window shall contain at least 30 presented frames.
- Repeat each scenario 10 times from its recorded starting state with identical input.
- Include ordinary exploration, crowded combat, and the late-Loop population; report
  per-second counts and frame-time distribution, including worst observed frame.
- Record hardware, OS/driver, build, display, power mode, fixture, and sampling interval.

Headless runs and runs on arbitrary faster hardware do not establish this rendering target.

### NFR-005 — New-game and load duration

Starting a new game and loading a supported valid save shall each take **less than 15 seconds**
on the reference configuration.

Acceptance:

- Measure from confirming New Game/Load until normal gameplay input is accepted, including
  world creation/restoration and required resources.
- Test New Game with the benchmark map/seed configuration and Load with each saved
  scenario separately, 10 fresh-process repetitions and 10 warm in-process repetitions each. A fresh process need not flush the
  OS disk cache; record this distinction instead of claiming a cold-disk benchmark.
- Every measured operation is below 15 seconds; 15.0 is a failure.
- If compatible demo-schema migrations are added, their total load time shares this bound.

Application launch before the menu is available is outside this measurement. Loop reset
has its own target in NFR-015.

### NFR-006 — Turn-processing duration

Processing one elapsed simulation turn shall take **less than 1 second** on the reference
configuration.

Acceptance:

- Measure from accepting the turn/progress step through player effects, the shared NPC
  phase, timers, navigation, periodic effects, and scheduled arrivals.
- Exclude time awaiting human input and deliberately paced visual animation.
- A multi-turn action records each turn separately and its total; no single elapsed turn
  may exceed the bound. Ten NPCs do not create ten separate timing allowances.
- Use the recorded action sequences for all benchmark scenarios; every measured turn is
  below one second. Report maxima, not just averages.

## Input and accessibility

### NFR-007 — Keyboard coverage and mouse support

Core play shall be possible by keyboard, with mouse operation for menus and most UI actions.

Acceptance:

- Keyboard-only play can start/load, move/wait, interact, select/cast skills, assign and use
  hotbar slots, manage inventory/equipment/quests, trade/train, save, change options, and exit.
- Mouse users can operate menus/services, click spell-book skills, select targets and confirm
  with a visible control, assign hotbar skills by drag-and-drop, and operate inventory/quests.
- World movement may remain keyboard-only; point-and-click navigation is outside the demo.
- Menu, text-entry, and targeting focus never also triggers world movement or a hotbar action.
- Controls remain usable at the minimum display size. FR-043 defines the default input matrix.

### NFR-008 — Alternate relationship palette

Options shall offer the standard green/yellow/red relationship palette and at least one
alternate palette aimed at common red-green color-vision deficiencies.

Initial alternate colors are friendly sky blue `#56B4E9`, neutral yellow `#F0E442`, and
hostile vermilion `#D55E00`. Include a written relationship label in the target/interaction
display so identifying a selected actor does not depend on color alone.

Acceptance:

- Selecting the palette immediately updates relationship indicators and persists globally.
- A human reviews friendly, neutral, and hostile actors against representative light/dark
  terrain at 640 × 360; indicators and selected-target labels remain distinguishable.
- Review protan/deutan simulations as supporting evidence, followed by human visual review;
  simulation alone does not establish accessibility. Record feedback and adjust if needed.
- Palette selection changes no relationships, combat, or targeting rules.

The [National Eye Institute](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/color-blindness/types-color-vision-deficiency)
identifies red-green deficiency as most common. The initial palette is selected from
[Okabe and Ito's Color Universal Design guidance](https://jfly.uni-koeln.de/color/), which
also recommends redundant visual information and human evaluation. This is an initial
design choice, not a guarantee for every visual condition. Review is lower priority than
core gameplay but remains part of final demo acceptance.

### NFR-009 — Slow synchronized informational blinking

If sprites blink or alternate to convey health or overlapping occupants, all such indicators
shall share a real-time display clock and change state **once every two seconds**. A full
two-state cycle therefore takes four seconds. Simulation time is unaffected.

Acceptance:

- Observed transitions are two seconds apart and synchronized across sprites; spawning a
  sprite joins the current phase rather than starting an independent blink.
- No rapid catch-up flashes occur after a stall, resize, or load.
- Indicators remain recognizable; essential text/controls do not blink.
- Inspect the composite display, including combat effects, to keep all flashing within
  the adopted ceiling of three flashes in any one-second interval.

The [W3C flashing guidance](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html)
sets a three-flashes-per-second ceiling unless area/luminance thresholds are met. The slower
sprite cadence is the selected game constraint.
A disable-blinking option is not required for the demo.

## Saving and reproducibility

### NFR-010 — Save-failure handling

Save failure shall visibly alert the player and preserve the last valid save on a failed
overwrite. It shall never be presented as success.

Acceptance:

- An unwritable destination or failed write produces a visible failure message.
- Slot timestamp/metadata do not claim a new save when writing failed.
- A failed overwrite leaves the prior valid file usable; validate a completed replacement
  before substituting it for the old file.
- The player can dismiss the error and continue the current in-memory game.

This basic preservation requirement applies when saves are introduced. Extensive crash,
power-loss recovery, journaling, or a backup-management system is outside the demo.

### NFR-011 — Damaged-save preservation

A damaged save shall be preserved under a new name, never deleted automatically. Playable
recovery from the damaged content is not required.

Acceptance:

- A failed damaged-save load applies no partial world state and reports failure.
- Rename with a `.damaged-<UTC timestamp>-<unique suffix>` suffix, preserving original bytes
  and avoiding name collisions. Mark the slot “Damaged” and show the retained filename.
- A damaged slot can be reused with normal confirmation without deleting the preserved file.
- If renaming fails, leave the original in place and report the error; never fall back to deletion.
- An unsupported version is reported as incompatible under NFR-012, not classified as damaged.

### NFR-012 — Demo save compatibility

The save family shall be `demo`, initially with schema revision 1. All demo builds sharing
a supported schema shall load it; any later demo-schema change must explicitly migrate it
or declare the old revision unsupported. Post-demo save formats are deliberately not
required to load demo saves.

Acceptance:

- A valid `demo` revision-1 fixture restores its full state under FR-041.
- If a supported migration exists, migrate in memory and write the current schema only on
  the next explicit save; loading alone does not rewrite the original file.
- A future, unknown, or explicitly unsupported family/revision gives a clear incompatibility
  message and leaves the file unchanged, with no partial restoration.
- An intentional compatibility break records affected family/revisions in release documentation.

No older public save format exists yet. Migration infrastructure and fixtures are required
only when an actual supported older revision exists; a hypothetical migration is not a test pass.
Compatibility does not promise identical combat balance across different game builds.

### NFR-013 — Reproducible simulation and world generation

The seed and saved simulation state shall support deterministic world/loot behavior under
FR-028/FR-029 and reproducible continuation under FR-041.

Acceptance:

- Corresponding initial and replacement NPC identities and chest loot remain identical across
  Loops despite changes in collection order, subject only to the explicit quest-item filter.
- For the same build/content, loading the same state and repeating the same actions
  reproduces NPC decisions and combat results.
- Frame rate and real-time input delays do not affect simulation results.
- Load restores random state, actor ordering, spawn ordinals, and pending schedules instead
  of restarting random sequences.

Different actions can change combat rolls. Memorizing combat randomness is not intended
progression; learning routes and seeded loot is. Combat randomness must not perturb source
loot. No cross-version/platform bit-for-bit replay requirement is introduced.

## Maintainability constraints

### NFR-014 — Simple implementation and reliable Loop reset

Implementation shall use GDScript and suitable Godot features, follow
[coding-style.md](../coding-style.md), and remain focused on current behavior.

Acceptance:

- Gameplay behavior is traceable to requirements and inspectable data without unnecessary
  generic frameworks.
- Repeated resets satisfy FR-002 without retained enemies, summons, callbacks, effects,
  pending actions, or transient rewards from ended Loops.
- Any new abstraction records its current problem, simpler alternative, and concrete benefit.

No unimplemented class hierarchy, global manager, or event bus is mandated.

### NFR-015 — Loop-reset duration

A Loop reset shall restore playable state in **less than 5 seconds** on the reference
configuration.

Acceptance:

- Measure from accepting player death through reset and availability of the next normal input,
  including cleanup, world rebuilding, starter loadout, and UI refresh.
- Restore the late-Loop fixture before each of 10 death/reset measurements; each completes
  below five seconds and satisfies FR-002. Also verify 10 consecutive resets without reloading. Reset correctness is required even if the performance target passes.
- Record every duration and any unexpected diagnostic or leftover state.
- A transition animation is part of this bound if it delays the next normal action.
