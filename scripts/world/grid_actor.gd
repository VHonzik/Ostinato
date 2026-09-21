class_name GridActor
extends RefCounted

## Array position is stable spawn/turn identity until world recreation (FR-013).
enum Relationship { FRIENDLY, NEUTRAL, HOSTILE }

var tile: Vector2i
var home_tile: Vector2i
var alive: bool = true
var wander_area: Rect2i
var title: String = "Groundskeeper"
var relationship: Relationship = Relationship.FRIENDLY
var engaged: bool = false
var returning_home: bool = false
var blocked_turns: int = 0
var aggro_range: int = 5
var max_health: int = 42
var health: int = 42
var melee := MeleeProfile.new()
var swing := SwingTimer.new()
var facing := Vector2i.DOWN
var awards_experience: bool = true
var corpse_visible: bool = true
var died_on_turn: int = -1
var service: StringName = &""
var buffs: Dictionary = {}
var chilled_until: int = 0
var movement_credit: float = 0.0
var story_guard: bool = false
var stalker: bool = false


func _init(start_tile: Vector2i, area: Rect2i = Rect2i()) -> void:
	tile = start_tile
	home_tile = start_tile
	wander_area = area


func relationship_name() -> String:
	if not alive:
		return "Corpse"
	return ["Friendly", "Neutral", "Hostile"][relationship]
