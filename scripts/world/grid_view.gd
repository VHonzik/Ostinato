class_name GridView
extends Node2D

const TILE_SIZE: int = 32
# Shared by the player and trainer NPCs.
const CLASS_SPRITES: Dictionary[StringName, Vector2i] = {
	&"Mage": Vector2i(3, 0),
	&"Druid": Vector2i(4, 0),
	&"Warlock": Vector2i(5, 0),
	&"Priest": Vector2i(6, 0),
	&"Shaman": Vector2i(6, 0),
	&"Paladin": Vector2i(2, 2),
	&"Warrior": Vector2i(2, 0),
	&"Rogue": Vector2i(4, 0),
}
# Source NPC identity keeps species silhouettes independent of relationship colors.
const ENEMY_SPRITES: Dictionary[int, Vector2i] = {
	299: Vector2i(7, 4), # Young Wolf
	69: Vector2i(7, 4), # Timber Wolf
	6: Vector2i(0, 5), # Kobold Vermin
	257: Vector2i(1, 5), # Kobold Worker
	80: Vector2i(1, 5), # Kobold Laborer
	38: Vector2i(1, 2), # Defias Thug
	103: Vector2i(5, 2), # Garrick Padfoot
}
const CHARACTERS: Texture2D = preload(
	"res://assets/spritesheets/scroolospritescharacters_nobg.png"
)
const ENVIRONMENT: Texture2D = preload(
	"res://assets/spritesheets/scroolospritesenvironment_nobg.png"
)

const VALLEY_ATLAS: Texture2D = preload("res://assets/spritesheets/valley/sprites.png")
const VALLEY_ACTORS: Dictionary[int, StringName] = {
	197: &"marshal", 823: &"willem", 900003: &"trader", 299: &"wolf", 69: &"wolf",
	9296: &"milly", 1642: &"gate_guard", 911: &"llane", 915: &"jorrick",
	925: &"sammuel", 900002: &"shaman_mentor", 6: &"kobold_miner", 257: &"kobold_worker",
	80: &"kobold_foreman", 38: &"bandit", 103: &"garrick",
}
const VALLEY_CLASSES: Dictionary[StringName, StringName] = {
	&"Warrior": &"warrior", &"Rogue": &"rogue", &"Shaman": &"shaman", &"Paladin": &"paladin",
}

# Owner-selected cells from the original sheets; remaining art uses the valley atlas.
const REFERENCE_CHARACTERS: Dictionary[StringName, Vector2i] = {
	&"willem": Vector2i(1, 0),
	&"warrior": Vector2i(2, 0), &"llane": Vector2i(2, 0),
	&"rogue": Vector2i(4, 0), &"jorrick": Vector2i(4, 0),
	&"shaman": Vector2i(6, 0), &"shaman_mentor": Vector2i(6, 0),
	&"milly": Vector2i(0, 1), &"bandit": Vector2i(1, 2),
	&"paladin": Vector2i(2, 2), &"sammuel": Vector2i(2, 2), &"gate_guard": Vector2i(2, 2),
	&"garrick": Vector2i(5, 2), &"wolf": Vector2i(7, 4),
	&"kobold_miner": Vector2i(0, 5),
	&"kobold_worker": Vector2i(1, 5), &"kobold_foreman": Vector2i(1, 5),
}
const REFERENCE_ENVIRONMENT: Dictionary[StringName, Vector2i] = {
	&"abbey_entrance": Vector2i(14, 0), &"abbey_wall_straight": Vector2i(0, 2),
	&"abbey_wall_vertical": Vector2i(1, 2),
	&"grass": Vector2i(0, 4),
	&"boulder": Vector2i(1, 4), &"small_rock": Vector2i(1, 4), &"flowers": Vector2i(2, 4),
	&"broadleaf_tree": Vector2i(3, 4), &"pine_tree": Vector2i(4, 4),
	&"chest_closed": Vector2i(6, 5), &"chest_open": Vector2i(7, 5),
	&"humanoid_corpse": Vector2i(1, 6), &"animal_corpse": Vector2i(1, 6),
}

const BLINK_SECONDS: float = 2.0
const LOW_HEALTH_COLOR := Color("#8b2222")
const QUEST_MARKER_REGION := Rect2(160, 208, 16, 16)

var world: GridWorld
var selected: GridActor
var alternate_palette: bool = false

var _valley_regions: Dictionary = {}
var _blink_elapsed: float = 0.0
var _blink_alternate_visible: bool = false


static func tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE_SIZE) + Vector2.ONE * (TILE_SIZE / 2.0)


static func class_sprite(category: StringName) -> Vector2i:
	return CLASS_SPRITES.get(category, CLASS_SPRITES[&"Mage"])


static func actor_sprite(actor: GridActor) -> Vector2i:
	if actor.summon_kind == "pet":
		return Vector2i(5 if actor.npc_id == 416 else 6, 4)
	if CLASS_SPRITES.has(actor.service):
		return class_sprite(actor.service)
	if actor.stalker:
		return Vector2i(3, 4)
	return ENEMY_SPRITES.get(actor.npc_id, Vector2i.ZERO)


func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/spritesheets/valley/sprites.json"))
	for name in catalog.sprites:
		var entry: Dictionary = catalog.sprites[name]
		_valley_regions[StringName(name)] = Rect2(entry.x, entry.y, entry.width, entry.height)


func _process(delta: float) -> void:
	_blink_elapsed += delta
	if _blink_elapsed >= BLINK_SECONDS:
		var phases := floori(_blink_elapsed / BLINK_SECONDS)
		_blink_elapsed = fmod(_blink_elapsed, BLINK_SECONDS)
		if phases % 2 == 1:
			_blink_alternate_visible = not _blink_alternate_visible
		queue_redraw()


# Living occupants hide corpses/chests; the player hides every other sprite on its tile.
func _sprite_occupants() -> Dictionary[Vector2i, GridActor]:
	var occupants: Dictionary[Vector2i, GridActor] = {}
	for actor in world.actors:
		if actor.tile == world.player_tile or not (actor.alive or actor.corpse_visible):
			continue
		if not occupants.has(actor.tile) or actor.alive and not occupants[actor.tile].alive:
			occupants[actor.tile] = actor
	return occupants


func _terrain_sprite(tile: Vector2i, occupants: Dictionary[Vector2i, GridActor]) -> StringName:
	if tile == world.player_tile or occupants.has(tile):
		return &""
	return world.scenery_tiles.get(tile, world.ground_tiles.get(tile, &""))


func _actor_color(actor: GridActor) -> Color:
	if (actor.alive and actor.relationship != GridActor.Relationship.FRIENDLY
		and actor.max_health > 0 and actor.health * 10 < actor.max_health * 3
		and _blink_alternate_visible):
		return LOW_HEALTH_COLOR
	if actor.relationship == GridActor.Relationship.FRIENDLY:
		return Color("#9acd95")
	if alternate_palette:
		return (Color("#F0E442") if actor.relationship == GridActor.Relationship.NEUTRAL
			else Color("#D55E00"))
	return (Color("#e8c979") if actor.relationship == GridActor.Relationship.NEUTRAL
		else Color("#ee7871"))


func _draw() -> void:
	if world == null:
		return
	var occupants := _sprite_occupants()
	_draw_valley_ground(occupants)
	for actor: GridActor in occupants.values():
		if not actor.alive and actor.corpse_visible:
			var sprite := &"animal_corpse" if actor.creature_type == "beast" else &"humanoid_corpse"
			if actor.chest:
				sprite = &"chest_open" if actor.loot_assigned else &"chest_closed"
			_draw_valley_sprite(actor.tile, sprite)
	for actor: GridActor in occupants.values():
		if actor.alive:
			var color := _actor_color(actor)
			if _blink_alternate_visible and QuestRules.has_marker(world, actor):
				draw_texture_rect_region(ENVIRONMENT,
					Rect2(Vector2(actor.tile * TILE_SIZE), Vector2.ONE * TILE_SIZE),
					QUEST_MARKER_REGION, Color("#9acd95"))
			elif actor.summon_kind in ["earth", "fire"]:
				var totem_color := Color("#cf884c") if actor.summon_kind == "earth" else Color("#ffb75a")
				draw_rect(Rect2(tile_center(actor.tile) - Vector2(6, 12), Vector2(12, 24)), totem_color)
				draw_line(tile_center(actor.tile) - Vector2(10, 6), tile_center(actor.tile) + Vector2(10, -6), color, 2)
			elif (actor.stalker or VALLEY_ACTORS.has(actor.npc_id)
				or VALLEY_CLASSES.has(actor.service)):
				var sprite: StringName = VALLEY_ACTORS.get(actor.npc_id,
					VALLEY_CLASSES.get(actor.service, &"stalker"))
				_draw_valley_sprite(actor.tile, &"stalker" if actor.stalker else sprite,
					color)
			else:
				_draw_character(actor.tile, actor_sprite(actor), color)
			if actor.polymorphed_until > world.turn_count:
				draw_circle(tile_center(actor.tile), 10, Color.WHITE)
			if actor.rooted_until > world.turn_count:
				draw_rect(Rect2(tile_center(actor.tile) - Vector2(12, 12), Vector2(24, 24)),
					Color("#71b580"), false, 1)
	if selected != null:
		var selection := Rect2(Vector2(selected.tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
		draw_rect(selection.grow(2), Color.WHITE, false, 1)
	var player_rect := Rect2(Vector2(world.player_tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
	draw_rect(player_rect.grow(1), Color("#83c5cf"), false, 1)
	if VALLEY_CLASSES.has(world.hero.selected_class):
		_draw_valley_sprite(world.player_tile, VALLEY_CLASSES[world.hero.selected_class])
	else:
		_draw_character(world.player_tile,
			class_sprite(world.hero.selected_class), Color("#d8f2ef"))


func _draw_character(tile: Vector2i, source: Vector2i, color: Color) -> void:
	var rectangle := Rect2(Vector2(tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
	draw_rect(Rect2(rectangle.position + Vector2(6, 26), Vector2(20, 4)), Color("#12251f"))
	draw_texture_rect_region(
		CHARACTERS, rectangle, Rect2(Vector2(source * 16), Vector2(16, 16)), color
	)


func _draw_valley_ground(occupants: Dictionary[Vector2i, GridActor]) -> void:
	var visible := get_viewport_transform().affine_inverse() * get_viewport_rect()
	var start := Vector2i((visible.position / TILE_SIZE).floor()) - Vector2i.ONE
	var end := Vector2i((visible.end / TILE_SIZE).ceil()) + Vector2i.ONE
	for y in range(maxi(start.y, world.bounds.position.y), mini(end.y, world.bounds.end.y)):
		for x in range(maxi(start.x, world.bounds.position.x), mini(end.x, world.bounds.end.x)):
			var tile := Vector2i(x, y)
			var rectangle := Rect2(Vector2(tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
			var shade := Color("#243b35")
			if world.blocked_tiles.has(tile) and not world.scenery_tiles.has(tile):
				shade = Color("#152620")
			draw_rect(rectangle, shade)
			var sprite := _terrain_sprite(tile, occupants)
			if sprite != &"":
				_draw_valley_sprite(tile, sprite)


func _draw_valley_sprite(tile: Vector2i, sprite: StringName, color: Color = Color.WHITE) -> void:
	var rectangle := Rect2(Vector2(tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
	if REFERENCE_CHARACTERS.has(sprite):
		var source: Vector2i = REFERENCE_CHARACTERS[sprite]
		draw_texture_rect_region(CHARACTERS, rectangle,
			Rect2(Vector2(source * 16), Vector2(16, 16)), color)
	elif REFERENCE_ENVIRONMENT.has(sprite):
		var source: Vector2i = REFERENCE_ENVIRONMENT[sprite]
		draw_texture_rect_region(ENVIRONMENT, rectangle,
			Rect2(Vector2(source * 16), Vector2(16, 16)), color)
	else:
		draw_texture_rect_region(VALLEY_ATLAS, rectangle, _valley_regions[sprite], color)
