extends "res://bench/stalker_passive_world.gd"
## Observe production combat only. Never alter effects, stats, costs or random draws.

var decision_log: Array[Dictionary] = []
var stack_gains: int = 0
var full_lava: int = 0


func _begin_cast(skill: SkillDefinition, target: GridActor,
	poison_hands: int = PoisonRules.Hands.BOTH) -> void:
	var stacks := ClassToolkitRules.maelstrom_stacks(hero)
	decision_log.append({"turn": turn_count, "skill": skill.title,
		"points": hero.combo_points, "maelstrom": stacks, "rage": hero.rage})
	if skill.family == &"lava_burst" and stacks == 5:
		full_lava += 1
	super._begin_cast(skill, target, poison_hands)


func add_message(message: String) -> void:
	if message.begins_with("Maelstrom Weapon: "):
		stack_gains += 1
	super.add_message(message)
