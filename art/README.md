# Art sources and runtime sprites

Keep editable Aseprite sources here:

- [characters.aseprite](characters.aseprite): class characters and ability effects.
- [warrior.aseprite](warrior.aseprite): Warrior art source.

Edit the sources manually and export the corresponding runtime sheet.

The game uses four sheets under [assets/spritesheets/](../assets/spritesheets/):

- `characters.png`: current classes, trainers, Stalker layers, Earth Elemental and ability effects.
- `scroolospritescharacters_nobg.png`: other reference characters and creatures.
- `scroolospritesenvironment_nobg.png`: reference terrain, chests, corpses and quest marker.
- `valley/sprites.png`: remaining contacts, terrain and props.
  [sprites.json](../assets/spritesheets/valley/sprites.json) maps names to atlas rectangles.

Keep the valley lookup aligned when moving cells. Preserve existing `.import` files
when replacing a runtime image. Use nearest filtering; sprite selection lives in
[GridView](../scripts/world/grid_view.gd).

The SVG under [assets/sprites/dev/](../assets/sprites/dev/) supplies the temporary
NPC base heart. In `characters.png`, the fifth column holds Stalker health and faction
layers, Fel Breath wind-up and cone tile art from top to bottom. The fourth column,
fifth row supplies Earth Elemental's health layer; its faction layer is empty. Fel Breath
uses normal 1.5-second sprite replacements on each wind-up turn and release, excluding
the player from the area flash. The countdown and steady cone border preserve the
warning between turns. Windfury uses the fourth column, second row on landed bonus hits.
Living actors use independent base and faction textures through
[ActorSpriteLayers](../scripts/world/actor_sprite_layers.gd). Replace pairs using
the GridView node's `npc_sprites` or `player_sprites` dictionaries, with matching
canvas sizes and positions.

See the [art plan](../docs/art-plan.md) for direction and [class mechanics](../docs/class-mechanics.md)
for ability effect cells and placement. After resource changes run
`pwsh -NoProfile -File tools/validate.ps1`. Review appearance in game.
