extends "res://bench/paladin_world.gd"

var rage_spent: Dictionary = {}
var finisher_points: Array[int] = []


func _resolve_skill(skill: SkillDefinition, target: GridActor, resource_spent: int = 0,
	poison_hands: int = PoisonRules.Hands.BOTH, maelstrom_stacks: int = 0,
	critical_bonus: int = 0) -> void:
	rage_spent[skill.title] = int(rage_spent.get(skill.title, 0)) + resource_spent
	if skill.family == &"eviscerate":
		finisher_points.append(hero.combo_points)
	super._resolve_skill(skill, target, resource_spent, poison_hands, maelstrom_stacks,
		critical_bonus)
