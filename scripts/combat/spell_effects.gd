class_name SpellEffects
extends RefCounted

## Shared damage, healing and class effects; all playable abilities use rage.
static func can_apply(world: GridWorld, skill: SkillRank, target: GridActor) -> bool:
	return ClassSpellEffects.can_apply(world, skill, target)


static func resolve(world: GridWorld, skill: SkillRank, target: GridActor) -> void:
	if world.is_terminal():
		return
	ClassSpellEffects.resolve(world, skill, target)


static func damage(
	world: GridWorld, target: GridActor, value: int, title: String,
	death_turn: int = -1, source: GridActor = null, physical: bool = false
) -> void:
	if world.is_terminal() or not target.alive:
		return
	value = ClassSpellEffects.absorb(world, target, value, physical or title.begins_with("You ("))
	if target.relationship != GridActor.Relationship.FRIENDLY:
		SummonRules.add_threat(world, target, source, value)
	target.health = maxi(0, target.health - value)
	if title.begins_with("You ("):
		world.add_message("You -> %s: %s, %d damage." % [target.title,
			title.trim_prefix("You (").trim_suffix(")"), value])
	else:
		world.add_message("%s -> %s: %d damage." % [title, target.title, value])
	world._check_npc_death(target, death_turn)
	world.check_terminal()


static func heal(world: GridWorld, target: GridActor, value: int, title: String) -> void:
	if world.is_terminal():
		return
	var missing := world.hero.max_health - world.hero.health if target == null else target.max_health - target.health
	var threat := mini(value, missing) / 2
	var enemies: Array[GridActor] = []
	for enemy in world.actors:
		if enemy.alive and enemy.engaged and enemy.relationship == GridActor.Relationship.HOSTILE:
			enemies.append(enemy)
	if not enemies.is_empty():
		for enemy in enemies:
			SummonRules.add_threat(world, enemy, null, threat / enemies.size())
	if target == null:
		world.hero.health = mini(world.hero.max_health, world.hero.health + value)
	else:
		target.health = mini(target.max_health, target.health + value)
	world.add_message("%s -> %s: %d healing." % [title, "You" if target == null else target.title, value])
