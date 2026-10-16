class_name SkillBehavior
extends RefCounted

## Behaviors resolve effects; the world owns payment, cooldowns and turn advancement.
class Cast:
	extends RefCounted

	var skill: SkillDefinition
	var target: GridActor
	var resource_spent: int
	var poison_hands: int

	func _init(definition: SkillDefinition, actor: GridActor, spent: int,
		hands: int) -> void:
		skill = definition
		target = actor
		resource_spent = spent
		poison_hands = hands


func can_apply(_world: GridWorld, _skill: SkillDefinition, _target: GridActor) -> bool:
	return true


func resolve(_world: GridWorld, _cast: Cast) -> void:
	pass
