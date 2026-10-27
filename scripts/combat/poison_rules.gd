class_name PoisonRules
extends RefCounted

enum Hands { MAIN = 1, OFF = 2, BOTH = 3 }

const COATINGS: Array[StringName] = [&"instant_poison_1", &"deadly_poison_1"]


static func is_poison(skill: SkillDefinition) -> bool:
	return skill.id in COATINGS


static func coat(world: GridWorld, skill: SkillDefinition, hands: int = Hands.BOTH) -> void:
	for off_hand in [false, true]:
		if (hands & (Hands.OFF if off_hand else Hands.MAIN)) == 0:
			continue
		var weapon := world.hero.weapon_id(off_hand)
		if weapon == 0:
			continue
		var field := "off_weapon_id" if off_hand else "weapon_id"
		var expiry := "off_until" if off_hand else "main_until"
		for identifier in COATINGS:
			var previous: Dictionary = world.hero.buffs.get(identifier, {})
			if previous.is_empty():
				continue
			# Keep the unselected hand's original timer, including existing saves.
			previous["main_until"] = int(previous.get("main_until", previous.until))
			previous["off_until"] = int(previous.get("off_until", previous.until))
			previous[field] = 0
			previous[expiry] = 0
			previous.until = maxi(int(previous.main_until), int(previous.off_until))
			if int(previous.get("weapon_id", 0)) == 0 and int(previous.get("off_weapon_id", 0)) == 0:
				world.hero.buffs.erase(identifier)
		var coating: Dictionary = world.hero.buffs.get(skill.id, {"armor": 0, "until": 0})
		coating[field] = weapon
		coating[expiry] = world.turn_count + 1 + skill.duration
		coating.until = maxi(int(coating.until), int(coating[expiry]))
		world.hero.buffs[skill.id] = coating
	world.add_message("%s applied to %s." % [skill.title,
		"both hands" if hands == Hands.BOTH and world.hero.has_off_hand_weapon()
		else ("off hand" if hands == Hands.OFF else "main hand")])


static func coating(hero: HeroState, turn: int, off_hand: bool) -> StringName:
	var weapon := hero.weapon_id(off_hand)
	if weapon == 0:
		return &""
	for identifier in COATINGS:
		var effect: Dictionary = hero.buffs.get(identifier, {})
		var field := "off_weapon_id" if off_hand else "weapon_id"
		var expiry := "off_until" if off_hand else "main_until"
		if (int(effect.get(field, 0)) == weapon
			and int(effect.get(expiry, effect.get("until", 0))) > turn):
			return identifier
	return &""


static func on_hit(world: GridWorld, target: GridActor, off_hand: bool) -> void:
	var identifier := coating(world.hero, world.turn_count, off_hand)
	var skill := world.hero.find_skill(identifier)
	if skill == null or world.combat_random.randf() >= skill.coefficient:
		return
	if identifier == &"deadly_poison_1":
		apply_deadly(world, target)
		return
	world.npc_ability_hit.emit(target, &"poison_trigger")
	var value := floori(skill.minimum * ClassToolkitRules.damage_multiplier(world.hero)
		* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level))
	SpellEffects.damage(world, target, value, skill.title)
	if world.is_terminal() or not target.alive:
		return
	if (not ClassToolkitRules.has(world.hero, &"catalytic_venom_1")
		or not world.hero.has_off_hand_weapon()
		or coating(world.hero, world.turn_count, not off_hand) != &"deadly_poison_1"):
		return
	apply_deadly(world, target)


static func apply_deadly(world: GridWorld, target: GridActor) -> void:
	if world.is_terminal() or not target.alive:
		return
	var skill := world.hero.find_skill(&"deadly_poison_1")
	if skill == null:
		return
	var effect: Dictionary = target.debuffs.get(skill.id, {})
	if effect.is_empty() or world.turn_count > int(effect.until):
		effect = {"stacks": 0, "damage_credit": 0.0, "next_tick": world.turn_count + 1}
	effect.stacks = mini(skill.maximum, int(effect.stacks) + 1)
	effect["until"] = world.turn_count + skill.periodic_duration
	target.debuffs[skill.id] = effect
	world.npc_ability_hit.emit(target, &"poison_trigger")


static func tick(world: GridWorld, target: GridActor) -> void:
	var effect: Dictionary = target.debuffs.get(&"deadly_poison_1", {})
	if effect.is_empty():
		return
	if not target.alive or world.turn_count > int(effect.until):
		target.debuffs.erase(&"deadly_poison_1")
		return
	if world.is_terminal() or world.turn_count < int(effect.next_tick):
		return
	effect.next_tick += 1
	var skill := world.hero.find_skill(&"deadly_poison_1")
	effect.damage_credit += skill.periodic_damage * int(effect.stacks) \
		* ClassToolkitRules.damage_multiplier(world.hero) \
		* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level)
	var damage := floori(float(effect.damage_credit) + 0.000001)
	effect.damage_credit = maxf(0.0, float(effect.damage_credit) - damage)
	SpellEffects.damage(world, target, damage, skill.title, world.turn_count)
	if world.turn_count >= int(effect.until) or not target.alive:
		target.debuffs.erase(&"deadly_poison_1")
