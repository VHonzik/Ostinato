class_name GridWorld
extends RefCounted

signal message_added(message: String)

## Movement and the shared wandering phase: FR-007/008/010/011/013/023.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const CHAT_LIMIT: int = 100

var hero: HeroState
var messages: PackedStringArray = []
var bounds: Rect2i
var blocked_tiles: Dictionary[Vector2i, bool] = {}
var actors: Array[GridActor] = []
var player_tile: Vector2i
var movement_speed: float = 1.0
var movement_credit: float = 0.0
var turn_count: int = 0
var random := RandomNumberGenerator.new()


func _init(
	map_bounds: Rect2i, spawn: Vector2i, world_seed: int = 1,
	development_build: bool = OS.is_debug_build()
) -> void:
	hero = HeroState.new(development_build)
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


func cast_skill(identifier: StringName) -> bool:
	var skill := hero.find_skill(identifier)
	if skill == null:
		add_message("Cannot cast: that rank is not learned.")
		return false
	if skill.effect == SkillRank.Effect.PREVIEW:
		add_message("%s rank %d: preview only; real effects arrive in milestone 4." % [
			skill.title, skill.rank,
		])
		return false
	match skill.effect:
		SkillRank.Effect.PRACTICE:
			add_message("Practice rank %d: cast complete (1 turn, 0 mana)." % skill.rank)
		SkillRank.Effect.EXPERIENCE:
			add_message("Gain 450 XP rank %d: gained 450 XP." % skill.rank)
			for gained_level in hero.add_experience(450):
				add_message("Level up! You are now level %d. Health and mana restored." % gained_level)
		SkillRank.Effect.DEATH_NOTICE:
			add_message("Death trigger invoked. Death state arrives in milestone 3; keep exploring.")
	_finish_turn()
	return true


func add_message(message: String) -> void:
	messages.append(message)
	if messages.size() > CHAT_LIMIT:
		messages.remove_at(0)
	message_added.emit(message)


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
