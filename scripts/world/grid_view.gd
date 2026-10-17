class_name GridView
extends Node2D

const TILE_SIZE: int = 32
# Shared by the player and trainer NPCs.
const CLASS_SPRITES: Dictionary[StringName, Vector2i] = {
	&"Shaman": Vector2i(3, 0),
	&"Paladin": Vector2i(1, 0),
	&"Warrior": Vector2i(0, 0),
	&"Rogue": Vector2i(2, 0),
}
const ABILITY_CHARACTERS: Texture2D = preload("res://assets/spritesheets/characters.png")
const CLASS_ART: Dictionary[StringName, Vector2i] = {
	&"warrior": Vector2i(0, 0), &"llane": Vector2i(0, 0),
	&"paladin": Vector2i(1, 0), &"sammuel": Vector2i(1, 0),
	&"rogue": Vector2i(2, 0), &"jorrick": Vector2i(2, 0),
	&"shaman": Vector2i(3, 0), &"shaman_mentor": Vector2i(3, 0),
}
const PLAYER_ABILITIES: Dictionary[StringName, Vector2i] = {
	&"charge": Vector2i(0, 3),
	&"battle_shout": Vector2i(0, 4), &"seal_of_command": Vector2i(1, 3),
	&"divine_shield": Vector2i(1, 4), &"instant_poison": Vector2i(2, 2),
	&"deadly_poison": Vector2i(2, 2), &"evasion": Vector2i(2, 3),
	&"lightning_shield": Vector2i(3, 2),
}
const ENEMY_ABILITIES: Dictionary[StringName, Vector2i] = {
	&"mortal_strike": Vector2i(0, 1), &"execution_sentence": Vector2i(1, 1),
	&"eviscerate": Vector2i(2, 1), &"windfury_weapon": Vector2i(3, 1),
	&"earth_shock": Vector2i(3, 3),
	&"whirlwind": Vector2i(0, 2),
}
const ABILITY_BLINK_SECONDS: float = 1.5
const CONSECRATION_CELL := Vector2i(1, 2)
# Source NPC identity keeps species silhouettes independent of relationship colors.
const ENEMY_SPRITES: Dictionary[int, Vector2i] = {
	299: Vector2i(7, 4), # Young Wolf
	69: Vector2i(8, 4), # Timber Wolf
	6: Vector2i(0, 5), # Kobold Vermin
	257: Vector2i(1, 5), # Kobold Worker
	80: Vector2i(6, 5), # Kobold Laborer
	38: Vector2i(1, 2), # Defias Thug
	103: Vector2i(5, 2), # Garrick Padfoot
}
const CHARACTERS: Texture2D = preload(
	"res://assets/spritesheets/scroolospritescharacters_nobg.png"
)
const ENVIRONMENT: Texture2D = preload(
	"res://assets/spritesheets/scroolospritesenvironment_nobg.png"
)

const NPC_BASE_SPRITE: Texture2D = preload("res://assets/sprites/dev/npc_base.svg")
const EARTH_ELEMENTAL_SPRITE: Texture2D = preload("res://assets/sprites/dev/earth_elemental.svg")

const VALLEY_ATLAS: Texture2D = preload("res://assets/spritesheets/valley/sprites.png")
const VALLEY_ACTORS: Dictionary[int, StringName] = {
	299: &"wolf", 69: &"wolf", 6: &"kobold_miner", 257: &"kobold_worker",
	80: &"kobold_foreman", 38: &"bandit", 103: &"garrick",
}
const VALLEY_CLASSES: Dictionary[StringName, StringName] = {
	&"Warrior": &"warrior", &"Rogue": &"rogue", &"Shaman": &"shaman", &"Paladin": &"paladin",
}

# Owner-selected cells from the original sheets; remaining art uses the valley atlas.
const REFERENCE_CHARACTERS: Dictionary[StringName, Vector2i] = {
	&"willem": Vector2i(1, 0),
	&"milly": Vector2i(0, 1), &"bandit": Vector2i(1, 2),
	&"gate_guard": Vector2i(2, 2),
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
const QUEST_MARKER_REGION := Rect2(160, 208, 16, 16)

## NPC keys match valley sprite names; summons use earth_elemental or wolf,
## and fallback characters use character_<column>_<row>.
@export var npc_sprites: Dictionary[StringName, ActorSpriteLayers] = {}
## Player keys are class names. The default faction layer is empty.
@export var player_sprites: Dictionary[StringName, ActorSpriteLayers] = {}

var world: GridWorld:
	set(value):
		if world == value:
			return
		if world != null:
			world.npc_combat_text.disconnect(combat_text.spawn)
			world.ability_used.disconnect(_show_player_ability)
			world.npc_ability_hit.disconnect(_show_npc_ability)
		world = value
		combat_text.clear()
		_player_blink.clear()
		_npc_blinks.clear()
		_consecration_blink.clear()
		if world != null:
			world.npc_combat_text.connect(combat_text.spawn)
			world.ability_used.connect(_show_player_ability)
			world.npc_ability_hit.connect(_show_npc_ability)
var selected: GridActor
var alternate_palette: bool = false
var combat_text := FloatingCombatText.new()

var _valley_regions: Dictionary = {}
var _blink_elapsed: float = 0.0
var _blink_alternate_visible: bool = false
var _quest_marker_sprite: AtlasTexture
var _player_blink: Dictionary = {}
var _npc_blinks: Dictionary[GridActor, Dictionary] = {}
var _consecration_blink: Dictionary = {}
var _ability_sprites: Dictionary[Vector2i, AtlasTexture] = {}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(combat_text)


static func tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE_SIZE) + Vector2.ONE * (TILE_SIZE / 2.0)


static func class_sprite(category: StringName) -> Vector2i:
	return CLASS_SPRITES.get(category, CLASS_SPRITES[&"Warrior"])


static func actor_sprite(actor: GridActor) -> Vector2i:
	if actor.summon_kind == "wolf":
		return ENEMY_SPRITES[299]
	if CLASS_SPRITES.has(actor.service):
		return class_sprite(actor.service)
	if actor.stalker:
		return Vector2i(3, 4)
	return ENEMY_SPRITES.get(actor.npc_id, Vector2i.ZERO)


static func health_tint(health: int, max_health: int) -> Color:
	if max_health <= 0 or health * 4 >= max_health * 3:
		return Color.WHITE
	return Color.RED if health * 5 <= max_health else Color.YELLOW


func npc_sprite_layers(actor: GridActor) -> ActorSpriteLayers:
	var key: StringName
	var contact := NpcDefinition.find(actor.npc_id)
	if actor.summon_kind == "earth_elemental":
		key = &"earth_elemental"
	elif actor.summon_kind == "wolf":
		key = &"wolf"
	elif not actor.stalker and contact != null and contact.sprite != &"":
		key = contact.sprite
	elif (actor.stalker or VALLEY_ACTORS.has(actor.npc_id)
		or VALLEY_CLASSES.has(actor.service)):
		key = &"stalker" if actor.stalker else VALLEY_ACTORS.get(actor.npc_id,
			VALLEY_CLASSES.get(actor.service, &"stalker"))
	else:
		var source := actor_sprite(actor)
		key = StringName("character_%d_%d" % [source.x, source.y])
	if not npc_sprites.has(key):
		var faction: Texture2D
		if actor.summon_kind == "earth_elemental":
			faction = EARTH_ELEMENTAL_SPRITE
		elif key.begins_with("character_"):
			faction = _character_sprite(actor_sprite(actor))
		else:
			faction = _valley_sprite_texture(key)
		npc_sprites[key] = ActorSpriteLayers.new(NPC_BASE_SPRITE, faction)
	return npc_sprites[key]


func player_sprite_layers(category: StringName) -> ActorSpriteLayers:
	if not player_sprites.has(category):
		var base := (_valley_sprite_texture(VALLEY_CLASSES[category])
			if VALLEY_CLASSES.has(category) else _ability_sprite(class_sprite(category)))
		player_sprites[category] = ActorSpriteLayers.new(base)
	return player_sprites[category]


func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/spritesheets/valley/sprites.json"))
	for name in catalog.sprites:
		var entry: Dictionary = catalog.sprites[name]
		_valley_regions[StringName(name)] = Rect2(entry.x, entry.y, entry.width, entry.height)
	_quest_marker_sprite = _atlas_sprite(ENVIRONMENT, QUEST_MARKER_REGION)


func _process(delta: float) -> void:
	if (not _player_blink.is_empty() or not _npc_blinks.is_empty()
		or not _consecration_blink.is_empty()):
		_advance_ability_blink(_player_blink, delta)
		_advance_ability_blink(_consecration_blink, delta)
		for actor: GridActor in _npc_blinks.keys():
			_advance_ability_blink(_npc_blinks[actor], delta)
			if not actor.alive or _npc_blinks[actor].is_empty():
				_npc_blinks.erase(actor)
		queue_redraw()
	_blink_elapsed += delta
	if _blink_elapsed >= BLINK_SECONDS:
		var phases := floori(_blink_elapsed / BLINK_SECONDS)
		_blink_elapsed = fmod(_blink_elapsed, BLINK_SECONDS)
		if phases % 2 == 1:
			_blink_alternate_visible = not _blink_alternate_visible
		queue_redraw()


func _show_player_ability(skill: SkillDefinition) -> void:
	if skill.family == &"consecration":
		var tiles: Array[Vector2i] = []
		var center: Vector2i = world.consecration.center
		for y in range(center.y - skill.range_tiles, center.y + skill.range_tiles + 1):
			for x in range(center.x - skill.range_tiles, center.x + skill.range_tiles + 1):
				var tile := Vector2i(x, y)
				if (world.bounds.has_point(tile) and not world.blocked_tiles.has(tile)
					and PaladinRules.covers(world, tile)):
					tiles.append(tile)
		_consecration_blink = {"tiles": tiles, "elapsed": 0.0}
		if tiles.has(world.player_tile):
			_player_blink.clear()
		for actor: GridActor in _npc_blinks.keys():
			if tiles.has(actor.tile):
				_npc_blinks.erase(actor)
		queue_redraw()
	if PLAYER_ABILITIES.has(skill.family):
		_replace_consecration_tile(world.player_tile)
		_player_blink = {"sprite": _ability_sprite(PLAYER_ABILITIES[skill.family]),
			"elapsed": 0.0}
		queue_redraw()


func _show_npc_ability(actor: GridActor, family: StringName) -> void:
	if ENEMY_ABILITIES.has(family):
		_replace_consecration_tile(actor.tile)
		_npc_blinks[actor] = {"sprite": _ability_sprite(ENEMY_ABILITIES[family]), "elapsed": 0.0}
		queue_redraw()


func _replace_consecration_tile(tile: Vector2i) -> void:
	if not _consecration_blink.is_empty():
		_consecration_blink.tiles.erase(tile)


func _advance_ability_blink(effect: Dictionary, delta: float) -> void:
	if effect.is_empty():
		return
	effect.elapsed += delta
	if float(effect.elapsed) >= ABILITY_BLINK_SECONDS:
		effect.clear()


func _blink_sprite(effect: Dictionary) -> Texture2D:
	if effect.is_empty():
		return null
	return effect.sprite


func _consecration_visible(tile: Vector2i) -> bool:
	return (not _consecration_blink.is_empty()
		and _consecration_blink.tiles.has(tile))


func _ability_sprite(cell: Vector2i) -> AtlasTexture:
	if not _ability_sprites.has(cell):
		_ability_sprites[cell] = _atlas_sprite(ABILITY_CHARACTERS,
			Rect2(Vector2(cell * 16), Vector2(16, 16)))
	return _ability_sprites[cell]


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
	if tile == world.player_tile or occupants.has(tile) or _consecration_visible(tile):
		return &""
	return world.scenery_tiles.get(tile, world.ground_tiles.get(tile, &""))


func _actor_color(actor: GridActor) -> Color:
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
		if not actor.alive and actor.corpse_visible and not _consecration_visible(actor.tile):
			var sprite := &"animal_corpse" if actor.creature_type == "beast" else &"humanoid_corpse"
			if actor.chest:
				sprite = &"chest_open" if actor.loot_assigned else &"chest_closed"
			_draw_valley_sprite(actor.tile, sprite)
	for actor: GridActor in occupants.values():
		if actor.alive:
			_draw_actor(actor)
	if selected != null:
		var selection := Rect2(Vector2(selected.tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
		draw_rect(selection.grow(2), Color.WHITE, false, 1)
	var player_rect := Rect2(Vector2(world.player_tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
	draw_rect(player_rect.grow(1), Color("#83c5cf"), false, 1)
	_draw_player()
	_draw_consecration()


func _draw_actor(actor: GridActor) -> void:
	if _consecration_visible(actor.tile):
		return
	var sprites := npc_sprite_layers(actor)
	var effect := _blink_sprite(_npc_blinks.get(actor, {}))
	var faction := sprites.faction_sprite
	if _blink_alternate_visible and QuestRules.has_marker(world, actor):
		faction = _quest_marker_sprite
	_draw_sprite_layers(actor.tile, sprites.base_sprite if effect == null else effect,
		faction if effect == null else null,
		health_tint(actor.health, actor.max_health), _actor_color(actor))
	if actor.debuffs.has(&"execution_sentence_1"):
		var remaining := int(actor.debuffs[&"execution_sentence_1"].until) - world.turn_count
		var position := Vector2(actor.tile * TILE_SIZE)
		draw_rect(Rect2(position + Vector2(18, 0), Vector2(14, 15)), Color("#382b15"))
		draw_string(ThemeDB.fallback_font, position + Vector2(21, 12), str(remaining),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffe187"))


func _draw_consecration() -> void:
	if _consecration_blink.is_empty():
		return
	for tile: Vector2i in _consecration_blink.tiles:
		if not _consecration_visible(tile):
			continue
		var color := Color.WHITE
		var actor := world.actor_at(tile)
		if tile == world.player_tile:
			color = health_tint(world.hero.health, world.hero.max_health)
		elif actor != null:
			color = health_tint(actor.health, actor.max_health)
		_draw_sprite_layers(tile, _ability_sprite(CONSECRATION_CELL), null, color, Color.WHITE)


func _draw_player() -> void:
	if _consecration_visible(world.player_tile):
		return
	var sprites := player_sprite_layers(world.hero.selected_class)
	var effect := _blink_sprite(_player_blink)
	_draw_sprite_layers(world.player_tile, sprites.base_sprite if effect == null else effect,
		sprites.faction_sprite if effect == null else null,
		health_tint(world.hero.health, world.hero.max_health), Color.WHITE)


# Both textures use the entire tile, so matching asset pixels stay aligned.
func _draw_sprite_layers(tile: Vector2i, base: Texture2D, faction: Texture2D,
	base_color: Color, faction_color: Color) -> void:
	var rectangle := Rect2(Vector2(tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
	if base != null:
		draw_texture_rect(base, rectangle, false, base_color)
	if faction != null:
		draw_texture_rect(faction, rectangle, false, faction_color)


func _character_sprite(source: Vector2i) -> AtlasTexture:
	return _atlas_sprite(CHARACTERS, Rect2(Vector2(source * 16), Vector2(16, 16)))


func _valley_sprite_texture(key: StringName) -> AtlasTexture:
	if CLASS_ART.has(key):
		return _ability_sprite(CLASS_ART[key])
	if REFERENCE_CHARACTERS.has(key):
		return _character_sprite(REFERENCE_CHARACTERS[key])
	return _atlas_sprite(VALLEY_ATLAS, _valley_regions[key])


func _atlas_sprite(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var sprite := AtlasTexture.new()
	sprite.atlas = texture
	sprite.region = region
	return sprite


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
	if CLASS_ART.has(sprite):
		draw_texture_rect(_ability_sprite(CLASS_ART[sprite]), rectangle, false, color)
	elif REFERENCE_CHARACTERS.has(sprite):
		var source: Vector2i = REFERENCE_CHARACTERS[sprite]
		draw_texture_rect_region(CHARACTERS, rectangle,
			Rect2(Vector2(source * 16), Vector2(16, 16)), color)
	elif REFERENCE_ENVIRONMENT.has(sprite):
		var source: Vector2i = REFERENCE_ENVIRONMENT[sprite]
		draw_texture_rect_region(ENVIRONMENT, rectangle,
			Rect2(Vector2(source * 16), Vector2(16, 16)), color)
	else:
		draw_texture_rect_region(VALLEY_ATLAS, rectangle, _valley_regions[sprite], color)
