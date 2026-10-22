extends "res://bench/pull_world.gd"
## Additional observation only; sample fights replay without this observer.

var vanish_turns: Array[int] = []
var evasion_turns: Array[int] = []
var hidden_boundaries: int = 0
var evasion_boundaries: int = 0
var vanish_reduction: int = 0
var evasion_reduction: int = 0
var incoming_hits: int = 0
var evasion_hits: int = 0
var incoming_attempts: int = 0
var evasion_attempts: int = 0
var prevented: int = 0
var hidden_damage: int = 0
var whirlwind_crits: int = 0
var finisher_points: Array[int] = []


func _begin_cast(skill: SkillDefinition, target: GridActor,
	poison_hands: int = PoisonRules.Hands.BOTH) -> void:
	if skill.family == &"vanish": vanish_turns.append(turn_count)
	if skill.family == &"evasion": evasion_turns.append(turn_count)
	var vanish_ready := int(hero.cooldowns.get("vanish", 0))
	var evasion_ready := int(hero.cooldowns.get("evasion", 0))
	if skill.family == &"eviscerate": finisher_points.append(hero.combo_points)
	super._begin_cast(skill, target, poison_hands)
	if skill.family == &"eviscerate":
		vanish_reduction += maxi(0, vanish_ready - int(hero.cooldowns.get("vanish", 0)))
		evasion_reduction += maxi(0, evasion_ready - int(hero.cooldowns.get("evasion", 0)))


func _finish_turn() -> void:
	if not watched.is_empty():
		# Timed buffs expire before the next boundary's ground ticks/enemy phase.
		hidden_boundaries += int(int(hero.buffs.get(&"vanish_1", {}).get("until", 0)) > turn_count + 1)
		evasion_boundaries += int(int(hero.buffs.get(&"evasion_1", {}).get("until", 0)) > turn_count + 1)
	super._finish_turn()


func add_message(message: String) -> void:
	var previous_damage := damage_total
	if not watched.is_empty():
		if " -> You: " in message and message.ends_with(" damage."):
			incoming_attempts += 1
			evasion_attempts += int(hero.buffs.has(&"evasion_1"))
			if int(message.get_slice(", ", 1)) > 0:
				incoming_hits += 1
				evasion_hits += int(hero.buffs.has(&"evasion_1"))
		if message.begins_with("Shield Block prevents "):
			prevented += int(message.trim_prefix("Shield Block prevents "))
		if message.begins_with("Whirlwind (critical)"):
			whirlwind_crits += 1
	super.add_message(message)
	if VanishRules.active(self): hidden_damage += damage_total - previous_damage


func metrics() -> Dictionary:
	var result := super.metrics()
	result.merge({"vanish_turns": vanish_turns, "evasion_turns": evasion_turns,
		"hidden_boundaries": hidden_boundaries, "evasion_boundaries": evasion_boundaries,
		"vanish_reduction": vanish_reduction, "evasion_reduction": evasion_reduction,
		"incoming_hits": incoming_hits, "evasion_hits": evasion_hits,
		"incoming_attempts": incoming_attempts, "evasion_attempts": evasion_attempts,
		"block_prevented": prevented, "hidden_damage": hidden_damage,
		"whirlwind_crits": whirlwind_crits, "finisher_points": finisher_points})
	return result
