extends "res://bench/paladin_world.gd"
## Observe live HP changes; never alter combat or random draws.

var healing: Dictionary = {}
var healing_total: int = 0
var damage_taken: int = 0
var raw_damage_taken: int = 0
var initial_health: int = 0
var _previous_health: int = 0
var _watching_health: bool = false
var charm_breaks: int = 0
var _charm_hit_health: int = 0


func watch(targets: Array[GridActor]) -> void:
	super.watch(targets)
	initial_health = hero.health
	_previous_health = hero.health
	_watching_health = true


func add_message(message: String) -> void:
	if _watching_health:
		var change := hero.health - _previous_health
		if message == "Lucky charm saves you from a lethal hit! You have 1 HP; the charm breaks.":
			assert(hero.health == 1 and change == 1 - _previous_health)
			assert(hero.inventory.any(func(item: Dictionary) -> bool:
				return not item.is_empty() and item.id == ItemData.BROKEN_LUCKY_CHARM_ID))
			_charm_hit_health = _previous_health
			charm_breaks += 1
			damage_taken -= change
		elif " -> You: " in message and message.ends_with(" damage."):
			var tail := message.get_slice(" -> You: ", 1).trim_suffix(" damage.")
			var amount := int(tail.get_slice(", ", tail.get_slice_count(", ") - 1))
			if _charm_hit_health > 0:
				assert(change == 0 and amount >= _charm_hit_health and hero.health == 1)
				_charm_hit_health = 0
			else:
				assert(-change == mini(_previous_health, amount))
			damage_taken -= change
			raw_damage_taken += amount
		elif " -> You: " in message and message.ends_with(" healing."):
			_record_heal(message.get_slice(" -> You: ", 0), change)
		elif message == "Used Minor Healing Potion.":
			_record_heal("Potion", change)
		else:
			assert(change == 0, "Unaccounted HP change: " + message)
		_previous_health = hero.health
	super.add_message(message)


func _regenerate() -> void:
	var before := hero.health
	super._regenerate()
	if _watching_health:
		_record_heal("Out-of-combat regeneration", hero.health - before)
		_previous_health = hero.health


func _record_heal(source: String, amount: int) -> void:
	assert(amount >= 0)
	healing[source] = int(healing.get(source, 0)) + amount
	healing_total += amount


func metrics() -> Dictionary:
	assert(hero.health == _previous_health)
	assert(_charm_hit_health == 0)
	assert(initial_health + healing_total - damage_taken == hero.health)
	return {"initial_health": initial_health, "healing": healing.duplicate(),
		"healing_total": healing_total, "damage_taken": damage_taken,
		"raw_damage_taken": raw_damage_taken, "charm_breaks": charm_breaks}
