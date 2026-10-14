# Valley art pipeline

This folder maintains generation and packing for the world/static sprites in
[the art plan](../docs/art-plan.md). Ability icons and effects are deferred.

## Files and ownership

- [sprites.json](sprites.json): catalog order, names, reference crops, prompts,
  seeds, and generation/export settings for the selected sprites.
- [assets/sprites/valley/](../assets/sprites/valley/): selected individual PNGs.
  Edit or replace these when refining a sprite.
- [assets/spritesheets/valley/sprites.png](../assets/spritesheets/valley/sprites.png):
  packed atlas; [sprites.json](../assets/spritesheets/valley/sprites.json) maps names
  to rectangles and source files. Rebuild from the individual sprites.
- `assets/generated/`: ignored candidates and preview sheets.
- `art/runs/`: ignored job IDs, raw images, references, and frozen batch recipes.

The selected baseline contains the sprites from the accepted prototype. Its
PNG pixels are preserved, and the catalog includes the actual settings used by
those selected variants. The game map uses the selected atlas
for roads/interiors and remaining boundaries, contacts, enemies and props. Owner-selected
characters, abbey walls/entrance, nature, chests and the shared corpse instead use
the original scroolo sheets directly; their mappings live in `GridView`. Outdoor ground
is plain. The quest exclamation mark also uses the original environment sheet.
The current mage and mage trainer retain reference art until the class pivot. Some equipment, remains, and tile connections need refinement.

Living actors use an `ActorSpriteLayers` resource with independent `base_sprite` and
`faction_sprite` textures. Replace pairs through the GridView node's `npc_sprites` or
`player_sprites` dictionaries; their keys are described in
[grid_view.gd](../scripts/world/grid_view.gd). Use matching canvas sizes and pixel positions
for the two textures: both fill the same tile rectangle with nearest filtering.
NPCs temporarily use [a corner heart](../assets/sprites/dev/npc_base.svg) for the base;
existing NPC art is the faction layer. Current player art is the base layer.

## Generate a candidate

Start your existing ComfyUI ROCm server. Run these commands from the project root:

```powershell
& C:\comfyui-rocm\python_env\python.exe art/generate.py --check
& C:\comfyui-rocm\python_env\python.exe art/generate.py --only wolf --seed 42
# Other useful selections:
& C:\comfyui-rocm\python_env\python.exe art/generate.py --group friends
& C:\comfyui-rocm\python_env\python.exe art/generate.py --list
# With no selection arguments, generate the whole catalog:
& C:\comfyui-rocm\python_env\python.exe art/generate.py
```

The pipeline uses SDXL and Pixel Art XL LoRA through ComfyUI's HTTP API. It crops
existing spritesheets as image-to-image references. The tested client is the
existing Python 3.12.9 / Pillow 12.3.0 runtime; no extra install is needed.
`--server` overrides the URL in the catalog. Paths resolve from the project root.

Generation prints its run ID. Candidates appear in
`assets/generated/valley/<run>/`, alongside a frozen `generation.json`.
Resume an interrupted batch with:

```powershell
& C:\comfyui-rocm\python_env\python.exe art/generate.py --resume art/runs/<run>
```

Resume skips exported sprites, uses cached raw images, retrieves submitted jobs,
and queues remaining entries. It does not cancel the server queue or silently retry
failed GPU jobs. `--timeout 1800` increases the wait per job, including queue time.
Start a new run for another candidate.

## Tune and select

Entry settings override their `style`, which overrides global settings. Change a
sprite's `prompt`, `seed`, or reference cell for its role. Adjust `denoise` for
freedom from the reference. `reference_rotate` and `reference_scale` change its
starting pose. The catalog retains individual overrides needed by selected variants.

Exports use nearest sampling and flat palettes without dithering. Ground stays
opaque. Cutouts use a corner-color matte; `background_tolerance` and
`remove_interior_background` control removal. Dark material may be erased and
background artifacts may remain. Inspect both raw and exported images when tuning.
Model, GPU, and server changes can alter seeded results.

Review candidates at native size and enlarged with nearest sampling. Check full
body silhouettes and equipment, hostile poses, prop identity, chest states, and
terrain joins. For a selected candidate, copy its PNG into `assets/sprites/valley/`
under the same name; keep the existing `.import` file. Keep the catalog aligned
with its selected prompt, seed, and overrides. Manual pixel edits belong in the
same individual PNGs.

## Pack separately

The packer defaults to the catalog and selected sprite folder. It requires all
selected names and correct cell sizes, preserves RGBA, and refuses to overwrite
an existing output folder.

```powershell
# Rebuild selected sprites into a fresh, ignored review folder:
& C:\comfyui-rocm\python_env\python.exe art/pack.py --output assets/generated/sheets/valley-review
# Preview a retake without replacing selected source sprites:
& C:\comfyui-rocm\python_env\python.exe art/pack.py --input assets/sprites/valley assets/generated/valley/<run> --only wolf --output assets/generated/sheets/wolf-review
```

Later `--input` folders override earlier sprites. `--columns` controls layout.
Use a new output folder for each review. After selecting individual PNGs and
reviewing a complete pack, copy its `sprites.png` and `sprites.json` into
`assets/spritesheets/valley/`, preserving the existing texture `.import` file.
Pack from the selected source folder for the maintained atlas, so metadata points
to stable source files. Avoid editing the atlas directly: repacking would lose
those edits. Use nearest texture filtering in Godot.

## Checks

```powershell
& C:\comfyui-rocm\python_env\python.exe -m unittest discover -s art -p 'test_*.py'
pwsh -NoProfile -File tools/validate.ps1
```

Python tests cover API failure handling, resume/export preservation, transparency,
and packing. Godot checks resource imports, script loading, and startup. Visual
quality and tile readability remain human review.
