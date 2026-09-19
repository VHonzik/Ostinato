class_name GridWorld
extends RefCounted

## Movement and the shared wandering phase: FR-007/008/010/011/013/023.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

var bounds: Rect2i
var blocked_tiles: Dictionary[Vector2i, bool] = {}
var actors: Array[GridActor] = []
var player_tile: Vector2i
var movement_speed: float = 1.0
var movement_credit: float = 0.0
var turn_count: int = 0
var random := RandomNumberGenerator.new()


func _init(map_bounds: Rect2i, spawn: Vector2i, world_seed: int = 1) -> void:
	bounds = map_bounds
	player_tile = spawn
	random.seed = world_seed


func is_open(tile: Vector2i) -> bool:
	if not bounds.has_point(tile) or blocked_tiles.has(tile) or tile == player_tile:
		return false
	for actor in actors:
		if actor.alive and actor.tile == tile:
			return false
	return true


func move_player(direction: Vector2i) -> bool:
	if not DIRECTIONS.has(direction) or movement_speed <= 0.0:
		return false
	# Reject before granting time or credit. Only the destination blocks a diagonal.
	if not is_open(player_tile + direction):
		return false
	movement_credit += movement_speed
	while movement_credit >= 1.0 and is_open(player_tile + direction):
		player_tile += direction
		movement_credit -= 1.0
	_finish_turn()
	return true


func wait_turn() -> void:
	_finish_turn()


func _finish_turn() -> void:
	# One shared phase, regardless of actor count. Earlier actors claim tiles first.
	for actor in actors:
		if not actor.alive or not actor.wander_area.has_area():
			continue
		var candidates: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var destination := actor.tile + direction
			if actor.wander_area.has_point(destination) and is_open(destination):
				candidates.append(destination)
		if not candidates.is_empty():
			actor.tile = candidates[random.randi_range(0, candidates.size() - 1)]
	turn_count += 1
