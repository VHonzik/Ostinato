# Reduced valley and sprite plan

Draft for the owner’s art work, not the current map. Keep Northshire recognizable
through the abbey, wolf woods, mine, vineyard and gate. Aim for a few encounters
with clear silhouettes and space to maneuver. Enemy counts and pacing await play.

## Valley sketch

Use the owner’s [map sketch](map.svg) as the layout reference, replacing the earlier
text map. This is the proposed world; the playable map has not been rebuilt yet.

![Owner’s valley map sketch](map.svg)

The sketch places wolves west of the abbey, easier kobolds to the north and harder
kobolds farther north in the mine. Bandits occupy the southeastern vineyard, with
Garrick at the eastern end. The player starts south of the marshal; the guard stands
at the southwestern gate, with stalkers approaching from outside. Three marked chests
provide exploration destinations. Use the sketch for approximate relative distances,
then adjust routes and encounters through play.

Use the nine friendly contacts shown: marshal, Willem, Milly, guard, Llane, Jorrick,
Sammuel, shaman and trader. Give each a distinctive prop and outline. The shaman’s
name/story and the trader’s exact services can be settled with their gameplay work.
The previous stream, bridge and woods-to-mine shortcut are no longer part of this plan.

## Scale and blocking

The measured sketch bounds are 570×550px; the player-to-marshal vertical distance
is 34px. Set that distance to about five tiles, giving 6.8 sketch pixels per tile
and an approximate 84×81-tile map (roughly 80 tiles tall). Scale both axes equally;
the sketch guides proportions rather than requiring an exact trace of every line.

- The mine shares the outdoor map; there is no separate mine scene or transition.
- The abbey entrance is on its bottom/south edge.
- The black-and-white interior shapes have blocking perimeters except at entrances.
  Connect the usable interior spaces through doorways.
- Add movement-blocking trees across the west, south and north sides. Trees are
  omitted from the sketch; place them around its routes and encounter areas while
  preserving access to the gate, NPCs, mine and chests.

Exact doorway widths, internal connections, tree positions and enemy placements
can be settled in the first playable map prototype. No further sketch detail is
needed to start that work.

## First spritesheet

32×32 cells, transparent actor/prop backgrounds, nearest-neighbor sampling. Start
with one facing/pose per actor; animation is optional later. Buildings assemble from
tiles and props. Leave the atlas layout flexible until these shapes have been tried
in game; no new packer or fixed sheet capacity is needed.

| Group | Sprites to draw | Distinction to aim for |
| --- | --- | --- |
| Player | Warrior, rogue, shaman, paladin | Broad weapon, low hood, totem, shield; recognizable beyond color |
| Friends | Marshal, Willem, Milly, gate guard, four mentors, trader | Plume/map, robe/book, basket, spear, four class props, trader’s satchel/scales |
| Enemies | Wolf, kobold miner, harder kobold/foreman, bandit, Garrick, stalker | Animal vs humanoid shapes; leaders differ in silhouette; stalker unmistakable |
| Remains | Humanoid corpse, animal corpse | Shared, subdued shapes; lootability remains a UI marker |
| Ground | Grass (two variants), dirt road, abbey floor, mine floor, tilled soil | Quiet surfaces beneath actors; no checkerboard required |
| Boundaries | Abbey wall straight/corner/end/doorway; cliff face/corner | Rotate or reuse where lighting permits; add junctions only if the sketch needs them |
| Nature | Broadleaf tree, pine, bush, boulder, small rock | Strong blocked-tile shapes, no hidden walkable gaps |
| Landmarks and props | Abbey entrance/cross, banner, bench, brazier; mine mouth, timber support, cart, ore; vine trellis, grape basket; gate post, fence/end, signpost | Distinct landmark clusters built from reusable pieces |
| Interaction props | Closed/open chest, crate, dropped bag | Reuse across branches; keep chest states visibly different |

Use shared corpse and prop art rather than a sprite for every historical NPC/item.
The old mage and other retiring classes keep their placeholder art during the transition.

## UI and effects

Keep panel frames, text, bars, slot borders and selection markers drawn by Godot.
Use a small shared set of 32px icons initially: weapon strike, bleed, poison,
wind, lightning shield, blessing/seal, healing and a generic effect fallback.
Reuse the relevant ability icon for its buff; show remaining turns in text. Final
ability-specific icons follow the chosen toolkit, rather than the old spell catalog.

The current screen uses text placeholders in slots and for active effects. The next
art pass should try player/hostile silhouettes, one wall, grass and road first in
this screen, then fill out the list after human review.
