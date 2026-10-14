class_name ClassSpellEffects
extends RefCounted

## Buffs, Holy weapon effects and explicit class defenses.
static func can_apply(world: GridWorld, skill: SkillRank, target: GridActor) -> bool:
	if not ClassToolkitRules.can_apply(world, skill, target):
		return false
	if skill.effect == SkillRank.Effect.PASSIVE:
		return false
	if skill.effect == SkillRank.Effect.SUMMON:
		return SummonRules.placement(world, skill) != Vector2i(-1, -1)
	if skill.family == &"seal_of_command":
		return world.hero.equipment.has("main_hand")
	if skill.family == &"slice_and_dice":
		return world.hero.combo_points > 0
	if skill.family == &"judgement":
		return world.hero.buffs.has(&"seal_of_command_1") and world.hero.equipment.has("main_hand")
	return true


static func resolve(world: GridWorld, skill: SkillRank, target: GridActor) -> void:
	match skill.effect:
		SkillRank.Effect.SUMMON:
			SummonRules.summon(world, skill)
		SkillRank.Effect.ARMOR:
			buff(world, skill)
		SkillRank.Effect.JUDGEMENT:
			ClassToolkitRules.magic_attack(world, target, skill)


static func buff(world: GridWorld, skill: SkillRank) -> void:
	var buffs := world.hero.buffs
	for key in buffs.keys():
		var previous := SkillRank.catalog(StringName(key))
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
			effect["weapon_id"] = int(world.hero.equipment.main_hand.id)
			effect["ready"] = 0
		&"instant_poison":
			effect["weapon_id"] = int(world.hero.equipment.main_hand.id)
			effect["off_weapon_id"] = int(world.hero.equipment.get("off_hand", {}).get("id", 0))
		&"slice_and_dice":
			effect["haste_percent"] = skill.haste_percent
			effect.until += skill.duration_per_combo * world.hero.combo_points
			var points := world.hero.combo_points
			world.hero.combo_points = 0
			ClassToolkitRules.finish(world, points)
		&"lightning_shield":
			effect["charges"] = 6 if ClassToolkitRules.has(world.hero, &"improved_shields_1") else 3
			effect["ready"] = 0
	buffs[skill.id] = effect
	world.hero.refresh_stats()
	world.add_message("%s rank %d applied." % [skill.title, skill.rank])


static func _holy_weapon_damage(world: GridWorld, skill: SkillRank) -> int:
	var weapon := world.hero.melee
	var bonus := weapon.attack_power / 14.0 * weapon.interval
	var minimum := floori(weapon.damage_min + bonus)
	var maximum := floori(weapon.damage_max + bonus)
	return maxi(1, floori(world.combat_random.randi_range(minimum, maximum)
		* skill.weapon_multiplier))


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
		var skill := SkillRank.catalog(&"seal_of_command_1")
		var value := floori(_holy_weapon_damage(world, skill) * ClassToolkitRules.damage_multiplier(world.hero))
		SpellEffects.damage(world, target, value, "Seal of Command", world.turn_count)
		if not world.is_terminal():
			ClassToolkitRules.holy_event(world)


static func tick(world: GridWorld) -> void:
	for actor in world.actors:
		for key in actor.debuffs.keys():
			if int(actor.debuffs[key].until) <= world.turn_count:
				actor.debuffs.erase(key)
	for key in world.hero.debuffs.keys():
		if int(world.hero.debuffs[key].until) <= world.turn_count:
			world.hero.debuffs.erase(key)
	SummonRules.refresh_auras(world)
