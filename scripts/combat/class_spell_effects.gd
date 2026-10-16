class_name ClassSpellEffects
extends RefCounted

## Buffs, Holy weapon effects and explicit class defenses.
static func absorb(world: GridWorld, target: GridActor, amount: int, physical: bool) -> int:
	var buffs := world.hero.buffs if target == null else target.buffs
	if buffs.has(&"divine_shield_1"):
		return 0
	if target == null:
		amount = floori(amount * ClassToolkitRules.recklessness_taken_multiplier(world.hero))
	if not physical and target == null:
		amount = floori(amount * (1.0 - ClassToolkitRules.magnitude(world.hero, &"elemental_warding_1") / 100.0))
	return amount


static func retaliate(world: GridWorld, attacker: GridActor, defender: GridActor, amount: int) -> void:
	if world.is_terminal() or amount <= 0 or not attacker.alive:
		return
	if defender == null:
		ClassToolkitRules.discharge(world, attacker, true)


static func on_melee(world: GridWorld, event: AttackEvent) -> void:
	var target := event.target
	if world.is_terminal() or not target.alive:
		return
	if event.landed() and world.hero.buffs.has(&"seal_of_command_1"):
		var skill := SkillDefinition.catalog(&"seal_of_command_1")
		var weapon_roll := world.combat_random.randf()
		var raw := MeleeRules.weapon_damage(world.hero.melee, weapon_roll)
		var value := MeleeRules.round_weapon_damage(raw * skill.weapon_multiplier
			* ClassToolkitRules.damage_multiplier(world.hero)
			* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level),
			world.hero.melee, weapon_roll)
		SpellEffects.damage(world, target, value, "Seal of Command", world.turn_count)
		if not world.is_terminal():
			ClassToolkitRules.holy_event(world)


static func tick(world: GridWorld) -> void:
	for actor in world.actors:
		PoisonRules.tick(world, actor)
		if world.is_terminal():
			return
		for key in actor.debuffs.keys():
			if int(actor.debuffs[key].until) <= world.turn_count:
				actor.debuffs.erase(key)
	for key in world.hero.debuffs.keys():
		if int(world.hero.debuffs[key].until) <= world.turn_count:
			world.hero.debuffs.erase(key)
	SummonRules.refresh_auras(world)
