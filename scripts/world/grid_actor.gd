class_name GridActor
extends RefCounted

## Array position is stable spawn/turn identity until world recreation.
enum Relationship { FRIENDLY, NEUTRAL, HOSTILE }

var npc_id: int = 0
var population_slot: int = -1
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
var summon_kind: String = ""
var summon_skill: StringName = &""
var expires_turn: int = 0
var stunned_until: int = 0
var threat: Dictionary = {}
var debuffs: Dictionary = {}


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
