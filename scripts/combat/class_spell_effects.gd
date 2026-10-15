class_name ClassSpellEffects
extends RefCounted

## Buffs, Holy weapon effects and explicit class defenses.
static func can_apply(world: GridWorld, skill: SkillDefinition, target: GridActor) -> bool:
	if not ClassToolkitRules.can_apply(world, skill, target):
		return false
	if skill.effect == SkillDefinition.Effect.PASSIVE:
		return false
	if skill.effect == SkillDefinition.Effect.SUMMON:
		return SummonRules.placement(world, skill) != Vector2i(-1, -1)
	if skill.family == &"seal_of_command":
		return world.hero.equipment.has("weapons")
	if skill.family == &"slice_and_dice":
		return world.hero.combo_points > 0
	if skill.family == &"judgement":
		return world.hero.buffs.has(&"seal_of_command_1") and world.hero.equipment.has("weapons")
	return true


static func resolve(world: GridWorld, skill: SkillDefinition, target: GridActor) -> void:
	match skill.effect:
		SkillDefinition.Effect.SUMMON:
			SummonRules.summon(world, skill)
		SkillDefinition.Effect.ARMOR:
			buff(world, skill)
		SkillDefinition.Effect.JUDGEMENT:
			ClassToolkitRules.magic_attack(world, target, skill)


static func buff(world: GridWorld, skill: SkillDefinition) -> void:
	if PoisonRules.is_poison(skill):
		PoisonRules.coat(world, skill)
		return
	var buffs := world.hero.buffs
	for key in buffs.keys():
		var previous := SkillDefinition.catalog(StringName(key))
		if previous != null and previous.family == skill.family:
			buffs.erase(key)
	var effect := {"armor": 0, "until": world.turn_count + 1 + skill.duration}
	match skill.family:
		&"blessing_of_might":
			effect["strength"] = skill.minimum
		&"divine_shield":
			effect["immunity"] = 1
			if ClassToolkitRules.has(world.hero, &"guardians_favor_1"):
				effect.until += world.hero.find_skill(&"guardians_favor_1").duration
		&"windfury_weapon":
			effect["weapon_id"] = world.hero.weapon_id()
			effect["ready"] = 0
		&"slice_and_dice":
			effect["haste_percent"] = skill.haste_percent
			effect.until += skill.duration_per_combo * world.hero.combo_points
			var points := world.hero.combo_points
			world.hero.combo_points = 0
			ClassToolkitRules.eviscerate(world, points)
			ClassToolkitRules.finish(world, points)
		&"lightning_shield":
			effect["charges"] = 6 if ClassToolkitRules.has(world.hero, &"improved_shields_1") else 3
			effect["ready"] = 0
	buffs[skill.id] = effect
	world.hero.refresh_stats()
	world.add_message("%s applied." % skill.title)


static func absorb(world: GridWorld, target: GridActor, amount: int, physical: bool) -> int:
	var buffs := world.hero.buffs if target == null else target.buffs
	if buffs.has(&"divine_shield_1"):
		return 0
	if not physical and target == null:
		amount = floori(amount * (1.0 - ClassToolkitRules.magnitude(world.hero, &"elemental_warding_1") / 100.0))
	return amount


static func retaliate(world: GridWorld, attacker: GridActor, defender: GridActor, amount: int) -> void:
	if world.is_terminal() or amount <= 0 or not attacker.alive:
		return
	if defender == null:
		ClassToolkitRules.discharge(world, attacker, true)


static func on_melee(world: GridWorld, target: GridActor, _amount: int, landed: bool) -> void:
	if world.is_terminal() or not target.alive:
		return
	if landed and world.hero.buffs.has(&"seal_of_command_1"):
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
