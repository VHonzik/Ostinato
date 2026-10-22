extends "res://bench/priority_world.gd"
## Read-only event timing for explaining the matched Stalker outcomes.

var events: Array[Dictionary] = []
var breath_releases: int = 0
var breath_exposures: int = 0


func watch(targets: Array[GridActor]) -> void:
	super.watch(targets)
	stalker_breath_released.connect(_watch_breath)


func _watch_breath(tiles: Array[Vector2i]) -> void:
	breath_releases += 1
	breath_exposures += int(tiles.has(player_tile))


func _begin_cast(skill: SkillDefinition, target: GridActor,
	poison_hands: int = PoisonRules.Hands.BOTH) -> void:
	if not watched.is_empty():
		_record("cast", skill.title)
	super._begin_cast(skill, target, poison_hands)


func add_message(message: String) -> void:
	super.add_message(message)
	if not watched.is_empty() and (message.ends_with(" damage.")
		or message.ends_with(" healing.") or "Fel Breath" in message
		or message == "Used Minor Healing Potion."):
		_record("event", message)


func _record(kind: String, label: String) -> void:
	var boss: GridActor = watched[0]
	events.append({"turn": turn_count, "kind": kind, "label": label,
		"hp": hero.health, "boss_hp": boss.health,
		"shield": hero.buffs.has(&"divine_shield_1"),
		"evasion": hero.buffs.has(&"evasion_1"),
		"combat_random": str(combat_random.state)})


func metrics() -> Dictionary:
	var result := super.metrics()
	result["events"] = events
	result["breath_releases"] = breath_releases
	result["breath_exposures"] = breath_exposures
	result["dodge_actions"] = int(get_meta("bench_breath_dodges", 0))
	result["dodge_cancelled_casts"] = int(get_meta("bench_dodge_cancelled_casts", 0))
	return result
