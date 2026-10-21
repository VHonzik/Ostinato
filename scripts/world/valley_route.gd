class_name ValleyRoute
extends RefCounted

## The scene is the source of terrain, placements and exploration regions.
const SCENE_PATH: String = "res://scenes/valley.tscn"
const QUESTS: Array[String] = [
	"valley_wolves", "valley_patrol", "valley_timber_wolves", "valley_camp",
	"valley_mine", "valley_vineyard", "valley_explore",
]

static var BOUNDS: Rect2i:
	get:
		return layout_info().bounds
static var SPAWN: Vector2i:
	get:
		return layout_info().spawn
static var STALKER_DEADLINES: Array[int]:
	get:
		return layout_info().deadlines
static var STALKER_ENTRIES: Array[Vector2i]:
	get:
		return layout_info().entries

static var _layout_info: Dictionary = {}


static func instantiate_map() -> ValleyMap:
	var scene := ResourceLoader.load(SCENE_PATH, "PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	return scene.instantiate() as ValleyMap


static func create_world(seed_value: int, development_build: bool) -> GridWorld:
	var map := instantiate_map()
	_layout_info = map.layout_info()
	var world := map.create_world(seed_value, development_build)
	map.free()
	return world


static func build_terrain(world: GridWorld) -> void:
	var map := instantiate_map()
	_layout_info = map.layout_info()
	map.apply_terrain(world)
	map.free()


static func layout_info() -> Dictionary:
	if _layout_info.is_empty():
		var map := instantiate_map()
		_layout_info = map.layout_info()
		map.free()
	return _layout_info
