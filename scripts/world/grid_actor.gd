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
var spawn_id: String = ""
var loot_table: int = 0
var loot_assigned: bool = false
var loot: Array[Dictionary] = []
var loot_copper: int = 0
var chest: bool = false
var creature_type: String = "humanoid"
var resistances: Dictionary = {}
var rooted_until: int = 0
var root_skill: StringName = &""
var slowed_until: int = 0
var polymorphed_until: int = 0
var polymorphed_on_turn: int = 0


func _init(start_tile: Vector2i, area: Rect2i = Rect2i()) -> void:
	tile = start_tile
	home_tile = start_tile
	wander_area = area


func relationship_name() -> String:
	if chest:
		return "Chest"
	if not alive:
		return "Corpse"
	return ["Friendly", "Neutral", "Hostile"][relationship]
