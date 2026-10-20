# Art sources and runtime sprites

Keep editable Aseprite sources here:

- [characters.aseprite](characters.aseprite): class characters and ability effects.
- [warrior.aseprite](warrior.aseprite): preserved Warrior source from the old art runs.

The generation scripts, recipes, candidates and individual duplicate PNGs have been
removed. Edit the sources manually and export the corresponding runtime sheet.

The game uses four sheets under [assets/spritesheets/](../assets/spritesheets/):

- `characters.png`: current classes, trainers and ability effects.
- `scroolospritescharacters_nobg.png`: other reference characters and creatures.
- `scroolospritesenvironment_nobg.png`: reference terrain, chests, corpses and quest marker.
- `valley/sprites.png`: remaining contacts, Stalker, terrain and props.
  [sprites.json](../assets/spritesheets/valley/sprites.json) maps names to atlas rectangles.

Keep the valley lookup aligned when moving cells. Preserve existing `.import` files
when replacing a runtime image. Use nearest filtering; sprite selection lives in
[GridView](../scripts/world/grid_view.gd).

The SVGs under [assets/sprites/dev/](../assets/sprites/dev/) supply the temporary
NPC base heart, Earth Elemental and Fel Breath warnings. Replace `breath_windup_sprite`
and `breath_tile_sprite` on GridView with final transparent textures; the tile sprite
blinks under occupants while a steady border preserves the threatened area.
Living actors use independent base and faction
textures through `ActorSpriteLayers`. Replace pairs using the GridView node's
`npc_sprites` or `player_sprites` dictionaries, with matching canvas sizes and positions.

See the [art plan](../docs/art-plan.md) for direction. After resource changes run
`pwsh -NoProfile -File tools/validate.ps1`. Review appearance in game.
