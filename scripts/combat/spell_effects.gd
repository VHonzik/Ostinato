class_name SpellEffects
extends RefCounted

## Shared damage, healing and class effects; all playable abilities use rage.
static func can_apply(world: GridWorld, skill: SkillDefinition, target: GridActor) -> bool:
	return SkillBehaviors.for_skill(skill).can_apply(world, skill, target)


static func resolve(world: GridWorld, skill: SkillDefinition, target: GridActor,
	resource_spent: int = 0, poison_hands: int = PoisonRules.Hands.BOTH) -> void:
	if world.is_terminal():
		return
	var cast := SkillBehavior.Cast.new(skill, target, resource_spent, poison_hands)
	SkillBehaviors.for_skill(skill).resolve(world, cast)
	world.ability_used.emit(skill)


static func attack(world: GridWorld, event: AttackEvent, title: String,
	death_turn: int = -1) -> void:
	if world.is_terminal() or not event.target.alive:
		return
	if event.skill != null and event.landed():
		world.npc_ability_hit.emit(event.target, event.skill.family)
	var label := title
	if event.is_primary() and event.school == AttackEvent.School.PHYSICAL:
		label = "%s (%s)" % [title, event.result]
	damage(world, event.target, event.amount, label, death_turn, null,
		event.school == AttackEvent.School.PHYSICAL, event.result,
		event.origin == AttackEvent.Origin.SWING and event.hand == AttackEvent.Hand.MAIN)


static func damage(
	world: GridWorld, target: GridActor, value: int, title: String,
	death_turn: int = -1, source: GridActor = null, physical: bool = false,
	result: StringName = &"hit", log_outcome: bool = false
) -> void:
	if world.is_terminal() or not target.alive:
		return
	value = ClassSpellEffects.absorb(world, target, value, physical)
	if target.relationship != GridActor.Relationship.FRIENDLY:
		SummonRules.add_threat(world, target, source, value)
	target.health = maxi(0, target.health - value)
	world.npc_combat_text.emit(target.tile, value, result)
	if log_outcome:
		world.add_message("You -> %s: %s, %d damage." % [target.title, result, value])
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
