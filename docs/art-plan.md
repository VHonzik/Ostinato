# Valley art direction

Visual guidance for the playable valley. Use the owner's [map sketch](map.svg) for
composition and [art workflow](../art/README.md) for editable sources and runtime sheets.
Current placements and NPC identities live in [the content reference](npc-dialogue.md).

## Valley layout

![Owner's valley map sketch](map.svg)

Keep the abbey, western wolf woods, northern kobold camp and Echo Ridge Mine,
southeastern vineyard, eastern ridge and southwestern gate recognizable. Garrick
occupies the eastern vineyard; the player starts south of the marshal, and stalkers
enter by the guard on the gate road. Three chests reward exploration.

The playable scene is 84×82 tiles, with five tiles between player spawn and marshal.
The sketch guides proportions and relative distances; the scene holds exact placements.
Keep both axes at the same scale when adapting the sketch.

- The mine shares the outdoor map, with no scene transition.
- The abbey entrance is on its south edge; doorways connect usable interior spaces.
- Trees, walls and vine trellises block movement. Flowers, bushes, decorative rocks
  and grass remain passable; tile custom data defines movement and sight blocking.
- Preserve routes to contacts, mine, gate and chests when placing terrain details.
- Give the ten friendly contacts distinctive outlines or props, including Janos,
  Khelden and the four named class trainers.

## Visual direction

Use nearest-neighbor sampling, transparent actor/prop backgrounds and a 32×32 world
tile. Reference 16×16 art is doubled; valley atlas cells are 32×32. Start with one
pose per actor; animation is optional. Keep editable sources and runtime atlas
coordinates aligned when replacing art.

Favor solid silhouettes, sparse interior details and little shading. Friends should
read as resolute adults; hostile creatures should look dangerous. Distinguish roles
through outlines and props before relying on color. Use full-body NPCs with visible
feet and distinctive equipment.

| Group | Art coverage | Visual aim |
| --- | --- | --- |
| Player | Warrior, Rogue, Shaman, Paladin | Recognizable weapon, hood, totem and shield silhouettes |
| Contacts | Marshal, Willem, Janos, Khelden, Milly, guard and four trainers | Distinct roles, class props and equipment |
| Enemies | Young/Timber Wolves, three kobold types, Defias Thug, Garrick, stalker | Readable species and ranks; unmistakable stalker |
| Remains | Shared corpse art | Lootability communicated by interaction/UI |
| Ground | Plain outdoors, dirt road, abbey/mine floors, tilled soil | Quiet surfaces beneath actors; no repeating grass field |
| Boundaries | Abbey walls, cliffs, entrances and corners | Clear blocking and connected walkable interiors |
| Nature | Trees, bushes, rocks, flowers and sparse grass tufts | Fewer tufts in woods; readable routes |
| Landmarks | Abbey cross, banner, bench, brazier; mine supports/cart/ore; trellises/baskets; gate/fence/signposts | Recognizable clusters built from reusable props |
| Interaction props | Closed/open chests, crates and dropped bags | Clear chest states and consistent silhouettes |

## Actor layers and UI

Living actors have separate base and faction textures. Base tint shows health;
faction art uses green for friendly, yellow for neutral and red for hostile actors.
Most NPCs use a corner heart base; Stalker and Earth Elemental have dedicated bases.
Quest offers/ready hand-ins alternate faction art with an exclamation mark, and
engaged hostiles blink a red exclamation mark. The player uses class art without a
faction layer. Appearance and readability need human review.

Living occupants cover terrain decorations, chests and corpses on their tile.
Ability effects can temporarily replace actor art or flash fixed ground; see
[class mechanics](class-mechanics.md) for current effect cells, timing and placement.

Follow the owner's [UI sketch](UI_design.svg). Keep panel frames, text, health/rage/XP
bars, hotbar borders, selection markers and ground outlines drawn by Godot. Hotbar
slots and active effects use text labels; icons can be refined alongside the toolkit.
Prioritize player/enemy silhouettes, terrain joins and clear effects without adding
visual noise to the plain outdoor ground.
