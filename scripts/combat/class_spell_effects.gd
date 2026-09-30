class_name ClassSpellEffects
extends RefCounted

## Concrete M7 rules supplement SpellEffects; source choices are in DATA-003 renaissance.md.
static func can_apply(world: GridWorld, skill: SkillRank, target: GridActor) -> bool:
	if skill.effect == SkillRank.Effect.PASSIVE:
		return false
	if skill.effect == SkillRank.Effect.SUMMON:
		return SummonRules.placement(world, skill) != Vector2i(-1, -1)
	if skill.family in [&"rockbiter_weapon", &"flametongue_weapon", &"seal_of_righteousness", &"seal_of_the_crusader"]:
		return world.hero.equipment.has("main_hand")
	if skill.family == &"life_tap":
		return world.hero.health > SpellEffects.amount(world, skill, false, false)
	if skill.family == &"power_word_shield":
		return (world.hero.weakened_until if target == null else target.weakened_until) <= world.turn_count
	if skill.family in [&"blessing_of_protection", &"divine_protection"]:
		return (world.hero.forbearance_until if target == null else target.forbearance_until) <= world.turn_count
	if skill.family == &"judgement":
		return not seal(world.hero).is_empty()
	if skill.effect == SkillRank.Effect.RESURRECT:
		return (not world.in_combat() and target != null and not target.alive
			and not target.story_guard and not target.chest and target.summon_kind == ""
			and target.relationship == GridActor.Relationship.FRIENDLY and world.is_open(target.tile))
	if skill.family == &"healthstone":
		for item in world.hero.inventory:
			if not item.is_empty() and int(item.id) == 5512:
				return false
	return true


static func resolve(world: GridWorld, skill: SkillRank, target: GridActor) -> bool:
	match skill.effect:
		SkillRank.Effect.SUMMON:
			SummonRules.summon(world, skill)
		SkillRank.Effect.CURSE:
			remove_curse(world, target)
			target.debuffs["weakness"] = {"until": world.turn_count + 1 + skill.duration, "reduction": 3}
			world.add_message("Curse of Weakness applied to " + target.title + ".")
		SkillRank.Effect.FEAR:
			for actor in world.actors:
				actor.feared_until = 0
			target.feared_until = world.turn_count + 1 + skill.duration
			world.add_message(target.title + " flees in fear.")
		SkillRank.Effect.STUN:
			target.stunned_until = world.turn_count + 1 + skill.duration
			world.add_message(target.title + " is stunned.")
		SkillRank.Effect.LIFE_TAP:
			var value := SpellEffects.amount(world, skill, false)
			world.hero.health -= value
			world.hero.mana = mini(world.hero.max_mana, world.hero.mana + value)
			world.add_message("Life Tap: %d health exchanged for mana." % value)
		SkillRank.Effect.JUDGEMENT:
			judge(world, target)
		SkillRank.Effect.PURIFY:
			var debuffs := world.hero.debuffs if target == null else target.debuffs
			for kind in ["poison", "disease"]:
				for key in debuffs.keys():
					if int(debuffs[key].get("dispel", 0)) == (4 if kind == "poison" else 3):
						debuffs.erase(key)
						break
			world.add_message("Purify removes one poison and one disease, if present.")
		SkillRank.Effect.RESURRECT:
			target.alive = true
			target.health = mini(70, target.max_health)
			target.died_on_turn = -1
			target.engaged = false
			world.add_message(target.title + " resurrected.")
		_:
			if skill.family == &"lay_on_hands":
				SpellEffects.heal(world, target, world.hero.max_health, skill.title)
				world.hero.mana = 0
				world.hero.last_mana_turn = world.turn_count + 1
			elif skill.effect == SkillRank.Effect.ARMOR and ClassSkillData.RANKS.has(String(skill.id)):
				buff(world, skill, target)
			else:
				return false
	return true


static func remove_curse(world: GridWorld, target: GridActor) -> void:
	target.debuffs.erase("weakness")
	for effect in world.periodic_effects.duplicate():
		if int(effect.actor) == world.actors.find(target) and effect.skill == "curse_of_agony_1":
			world.periodic_effects.erase(effect)


static func buff(world: GridWorld, skill: SkillRank, target: GridActor) -> void:
	var buffs := world.hero.buffs if target == null else target.buffs
	if skill.family == &"devotion_aura" and buffs.has(skill.id):
		buffs.erase(skill.id)
		SummonRules.refresh_auras(world)
		world.add_message("Devotion Aura disabled.")
		return
	for key in buffs.keys():
		var previous := SkillRank.catalog(StringName(key))
		if previous == null:
			continue
		if (previous.family == skill.family
			or (String(previous.family).begins_with("seal_") and String(skill.family).begins_with("seal_"))
			or (String(previous.family).begins_with("blessing_") and String(skill.family).begins_with("blessing_"))
			or (previous.family in [&"rockbiter_weapon", &"flametongue_weapon"]
				and skill.family in [&"rockbiter_weapon", &"flametongue_weapon"])):
			if target != null and target.summon_kind != "pet":
				target.melee.armor -= int(buffs[key].get("armor", 0))
				target.melee.attack_power -= int(buffs[key].get("attack_power", 0))
				if buffs[key].has("stamina"):
					target.max_health -= int(buffs[key].stamina) * 10
			buffs.erase(key)
	var effect := {"armor": 0, "until": world.turn_count + 1 + skill.duration}
	match skill.family:
		&"devotion_aura":
			effect.armor = skill.minimum
			effect.until = 2147483647
		&"demon_skin":
			effect.armor = skill.minimum
			effect["regen"] = 3 if skill.rank == 1 else 5
			effect["next"] = world.turn_count + 6
		&"power_word_fortitude":
			effect["stamina"] = 3
		&"power_word_shield":
			effect["absorb"] = 44 + int(world.hero.healing_power * skill.coefficient)
			if target == null:
				world.hero.weakened_until = world.turn_count + 16
			else:
				target.weakened_until = world.turn_count + 16
		&"blessing_of_might":
			effect["attack_power"] = 20
		&"blessing_of_protection", &"divine_protection":
			effect["physical_immunity"] = 1
			if target == null:
				world.hero.forbearance_until = world.turn_count + 61
			else:
				target.forbearance_until = world.turn_count + 61
		&"lightning_shield":
			effect["charges"] = 3
			effect["ready"] = 0
		&"rockbiter_weapon", &"flametongue_weapon":
			effect["weapon_id"] = int(world.hero.equipment.main_hand.id)
			if skill.family == &"rockbiter_weapon":
				effect["weapon_dps"] = 2 if skill.rank == 1 else 4
		&"seal_of_the_crusader":
			effect["attack_power"] = 31
			effect["crusader"] = 1
	buffs[skill.id] = effect
	if target == null:
		world.hero.refresh_stats()
	elif target.summon_kind != "pet":
		target.melee.armor += int(effect.armor)
		target.melee.attack_power += int(effect.get("attack_power", 0))
		if effect.has("stamina"):
			target.max_health += 30
		target.health = mini(target.health, target.max_health)
	SummonRules.refresh_auras(world)
	world.add_message("%s rank %d applied." % [skill.title, skill.rank])


static func seal(hero: HeroState) -> Dictionary:
	for key in hero.buffs:
		if String(key).begins_with("seal_"):
			return {"key": key, "skill": SkillRank.catalog(StringName(key))}
	return {}


static func judge(world: GridWorld, target: GridActor) -> void:
	var current := seal(world.hero)
	if current.is_empty():
		return
	var skill: SkillRank = current.skill
	world.hero.buffs.erase(current.key)
	world.hero.refresh_stats()
	if skill.family == &"seal_of_the_crusader":
		target.debuffs["crusader"] = {"until": world.turn_count + 10, "holy_power": 20}
		world.add_message("Judgement of the Crusader applied.")
	else:
		var value := 15 if skill.rank == 1 else 25
		var scaling := maxi(0, mini(world.hero.level, 7 if skill.rank == 1 else 16) - skill.training_level)
		value += int(scaling * (1.8 if skill.rank == 1 else 1.9))
		var power := world.hero.spell_power + int(target.debuffs.get("crusader", {}).get("holy_power", 0))
		value += int(power * 0.5 * (1.0 - (20 - skill.training_level) * 0.0375))
		SpellEffects.damage(world, target, value, "Judgement of Righteousness", world.turn_count)


static func immune(buffs: Dictionary) -> bool:
	for effect in buffs.values():
		if int(effect.get("physical_immunity", 0)) > 0:
			return true
	return false


static func absorb(world: GridWorld, target: GridActor, amount: int, physical: bool) -> int:
	var buffs := world.hero.buffs if target == null else target.buffs
	if physical and immune(buffs):
		return 0
	if physical:
		amount = maxi(0, amount - (world.hero.aura_reduction if target == null else target.aura_reduction))
	for effect in buffs.values():
		if int(effect.get("absorb", 0)) > 0:
			var taken := mini(amount, int(effect.absorb))
			effect.absorb -= taken
			amount -= taken
	return amount


static func retaliate(world: GridWorld, attacker: GridActor, defender: GridActor, amount: int) -> void:
	if amount <= 0 or not attacker.alive:
		return
	var buffs := world.hero.buffs if defender == null else defender.buffs
	if buffs.has(&"lightning_shield_1"):
		var shield: Dictionary = buffs[&"lightning_shield_1"]
		if int(shield.charges) > 0 and world.turn_count >= int(shield.ready):
			shield.charges -= 1
			shield.ready = world.turn_count + 3
			var value := SpellResistance.mitigate(13, SpellResistance.percent(world.hero.level,
				attacker.melee.level, int(attacker.resistances.get("3", 0)), false), world.combat_random.randf())
			SpellEffects.damage(world, attacker, value, "Lightning Shield", world.turn_count)
			if int(shield.charges) == 0:
				buffs.erase(&"lightning_shield_1")


static func on_melee(world: GridWorld, target: GridActor, amount: int) -> void:
	if amount <= 0 or not target.alive:
		return
	var current := seal(world.hero)
	if not current.is_empty() and current.skill.family == &"seal_of_righteousness":
		var skill: SkillRank = current.skill
		var two_handed := bool(ItemData.get_item(int(world.hero.equipment.get("main_hand", {}).get("id", 35))).two_handed)
		var speed := world.hero.melee.interval
		var base := skill.minimum * 1.2 * 1.03 * speed / 100.0
		base = 1.44 * base + 1 if two_handed else 0.85 * ceilf(base) - 1
		var value := maxi(1, int(base + 0.03 * (world.hero.melee.damage_min + world.hero.melee.damage_max) / 2) + 1)
		var power := world.hero.spell_power + int(target.debuffs.get("crusader", {}).get("holy_power", 0))
		value += int(power * speed * (0.108 if two_handed else 0.092)
			* (1.0 - (20 - skill.training_level) * 0.0375))
		SpellEffects.damage(world, target, value, "Seal of Righteousness")
	if target.alive and world.hero.buffs.has(&"flametongue_weapon_1"):
		var enchant: Dictionary = world.hero.buffs[&"flametongue_weapon_1"]
		if int(enchant.weapon_id) == int(world.hero.equipment.get("main_hand", {}).get("id", 0)):
			var damage_per_second := (326.0 + maxi(0, mini(world.hero.level, 16) - 10) * 19) / 100.0
			var value := maxi(1, int(damage_per_second * world.hero.melee.interval + world.hero.spell_power * 0.1 * 0.625))
			value = SpellResistance.mitigate(value, SpellResistance.percent(world.hero.level,
				target.melee.level, int(target.resistances.get("2", 0)), false), world.combat_random.randf())
			SpellEffects.damage(world, target, value, "Flametongue Weapon")
	if target.debuffs.has("crusader"):
		target.debuffs.crusader.until = world.turn_count + 11


static func tick(world: GridWorld) -> void:
	for key in world.hero.buffs:
		var buff: Dictionary = world.hero.buffs[key]
		if buff.has("regen") and world.turn_count >= int(buff.next):
			world.hero.health = mini(world.hero.max_health, world.hero.health + int(buff.regen))
			buff.next += 5
	for actor in world.actors:
		for key in actor.debuffs.keys():
			if int(actor.debuffs[key].until) <= world.turn_count:
				actor.debuffs.erase(key)
	for key in world.hero.debuffs.keys():
		if int(world.hero.debuffs[key].until) <= world.turn_count:
			world.hero.debuffs.erase(key)
	SummonRules.refresh_auras(world)
