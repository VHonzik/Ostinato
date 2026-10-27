class_name ClassToolkitRules
extends RefCounted

## Shared class calculations and attacks. AttackProcs owns primary attack hooks.
static func has(hero: HeroState, identifier: StringName) -> bool:
	return hero.find_skill(identifier) != null


static func magnitude(hero: HeroState, identifier: StringName) -> int:
	var skill := hero.find_skill(identifier)
	return 0 if skill == null else skill.minimum


static func victory_rush(world: GridWorld, death_turn: int) -> void:
	var skill := world.hero.find_skill(&"victory_rush_1")
	if skill == null or death_turn < int(effect(world.hero, skill.id).get("ready", 0)):
		return
	if skill.cooldown_seconds > 0:
		var ready := death_turn + skill.cooldown_seconds
		world.hero.buffs[skill.id] = {"armor": 0, "until": ready, "ready": ready}
	SpellEffects.heal(world, null, floori(world.hero.max_health * skill.minimum / 100.0),
		skill.title)


static func proc(world: GridWorld, identifier: StringName, multiplier: float = 1.0) -> bool:
	var skill := world.hero.find_skill(identifier)
	return skill != null and world.combat_random.randf() < skill.coefficient * multiplier


static func effect(hero: HeroState, identifier: StringName) -> Dictionary:
	return hero.buffs.get(identifier, {})


static func apply(world: GridWorld, identifier: StringName, fields: Dictionary) -> void:
	var skill := world.hero.find_skill(identifier)
	if skill == null:
		return
	var buff := {"armor": 0, "until": world.turn_count + 1 + skill.duration}
	if skill.duration == 0:
		buff.until = 0
	buff.merge(fields, true)
	world.hero.buffs[identifier] = buff
	world.hero.refresh_stats()
	world.add_message("%s activated." % skill.title)


static func cooldown(hero: HeroState, skill: SkillDefinition) -> int:
	var turns := skill.cooldown_seconds
	match skill.family:
		&"charge": turns -= magnitude(hero, &"juggernaut_1")
		&"divine_shield": turns -= magnitude(hero, &"guardians_favor_1")
	return maxi(0, turns)


static func maelstrom_stacks(hero: HeroState) -> int:
	return int(effect(hero, &"maelstrom_weapon_1").get("charges", 0))


static func cast_duration(hero: HeroState, skill: SkillDefinition) -> float:
	if skill.family != &"lava_burst":
		return skill.cast_seconds
	var passive := hero.find_skill(&"maelstrom_weapon_1")
	var stacks := maelstrom_stacks(hero)
	if passive == null or stacks == 0:
		return skill.cast_seconds
	if stacks == passive.maximum:
		return 1.0
	return maxf(2.0, ceili(skill.cast_seconds * (passive.maximum - stacks) / passive.maximum))


static func spend_maelstrom(hero: HeroState, reserved: int) -> void:
	if reserved == 0:
		return
	var remaining := maelstrom_stacks(hero) - reserved
	if remaining > 0:
		hero.buffs[&"maelstrom_weapon_1"].charges = remaining
	else:
		hero.buffs.erase(&"maelstrom_weapon_1")


static func damage_multiplier(hero: HeroState) -> float:
	var percent := int(effect(hero, &"vengeance_1").get("bonus_percent", 0))
	percent += int(effect(hero, &"bandits_guile_1").get("bonus_percent", 0))
	var multiplier := 1.0 + percent / 100.0
	if hero.buffs.has(&"divine_shield_1"):
		multiplier *= 1.0 - magnitude(hero, &"divine_shield_1") / 100.0
	return multiplier


static func recklessness_scale(hero: HeroState) -> float:
	var skill := hero.find_skill(&"recklessness_1")
	if skill == null or hero.health <= 0 or hero.max_health <= 0:
		return 0.0
	var missing := 1.0 - float(hero.health) / hero.max_health
	var capped_missing := 1.0 - skill.health_cap_percent / 100.0
	return clampf(missing / capped_missing, 0.0, 1.0)


static func recklessness_damage_multiplier(hero: HeroState) -> float:
	return 1.0 + recklessness_scale(hero) * magnitude(hero, &"recklessness_1") / 100.0


static func recklessness_taken_multiplier(hero: HeroState) -> float:
	var skill := hero.find_skill(&"recklessness_1")
	if skill == null:
		return 1.0
	return 1.0 + recklessness_scale(hero) * skill.damage_taken_percent / 100.0


static func on_damage_taken(world: GridWorld, amount: int) -> void:
	var hero := world.hero
	var skill := hero.find_skill(&"enrage_1")
	if (skill == null or amount <= 0 or hero.health <= 0 or world.is_terminal()
		or hero.last_enrage_roll_turn == world.turn_count):
		return
	hero.last_enrage_roll_turn = world.turn_count
	if proc(world, skill.id):
		apply(world, skill.id,
			{"physical_percent": skill.minimum, "critical_percent": skill.critical_percent})


static func eligible(world: GridWorld, target: GridActor, radius: int) -> bool:
	return (target.alive and target.relationship != GridActor.Relationship.FRIENDLY
		and GridWorld.tile_distance(world.player_tile, target.tile) <= radius
		and world.has_sight(world.player_tile, target.tile))


static func slice_and_dice(world: GridWorld, points: int) -> void:
	var skill := world.hero.find_skill(&"slice_and_dice_1")
	if skill == null or world.is_terminal():
		return
	apply(world, skill.id, {"haste_percent": skill.haste_percent,
		"until": world.turn_count + 1 + skill.duration + skill.duration_per_combo * points})


static func physical_attack(world: GridWorld, target: GridActor, skill: SkillDefinition,
	flat_bonus: int, build_points: bool = true, commit_target: bool = true,
	weapon_scale: float = 1.0) -> void:
	if commit_target:
		world.last_attacked_enemy = target
	var event := weapon_outcome(world, target, skill, world.hero.melee)
	var multiplier := skill.weapon_multiplier * weapon_scale
	if skill.family == &"whirlwind" and world.hero.buffs.has(&"wrecking_crew_1"):
		var wrecking := world.hero.find_skill(&"wrecking_crew_1")
		if wrecking != null:
			multiplier *= 1.0 + wrecking.whirlwind_percent / 100.0
	var value := MeleeRules.damage(world.hero.melee, target.melee, event.result,
		world.combat_random.randf(), multiplier, flat_bonus,
		recklessness_damage_multiplier(world.hero))
	event.amount = floori(value * damage_multiplier(world.hero))
	event.build_points = build_points
	SpellEffects.attack(world, event, skill.title)
	AttackProcs.on_attack(world, event)


static func weapon_outcome(world: GridWorld, target: GridActor, skill: SkillDefinition,
	weapon: MeleeProfile, critical_bonus: int = 0) -> AttackEvent:
	if skill != null:
		critical_bonus += world.ability_critical_bonus
	var result := MeleeRules.outcome(weapon, target.melee,
		world.combat_random.randf() * 100.0, critical_bonus)
	var landed := result not in [&"miss", &"dodge"]
	if (skill != null and landed and skill.family == &"mortal_strike"
		and world.hero.buffs.has(&"juggernaut_1")):
		world.hero.buffs.erase(&"juggernaut_1")
		result = &"critical"
	return AttackEvent.new(target, skill, result, 0)


static func magic_attack(world: GridWorld, target: GridActor, skill: SkillDefinition,
	extra: float = 1.0, critical_bonus: int = 0) -> AttackEvent:
	world.last_attacked_enemy = target
	world.auto_attack_target = target
	var event := magic_outcome(world, target, skill, extra, critical_bonus)
	if event.landed():
		resolve_magic(world, event)
	return event


static func magic_outcome(world: GridWorld, target: GridActor, skill: SkillDefinition,
	extra: float = 1.0, critical_bonus: int = 0) -> AttackEvent:
	var hit_chance := 100.0 - MeleeRules.miss_chance(world.hero.melee, target.melee)
	var hit_roll := world.combat_random.randf() * 100.0
	if hit_chance < 100.0 and hit_roll >= hit_chance:
		world.npc_combat_text.emit(target.tile, 0, &"miss")
		world.add_message("%s misses %s." % [skill.title, target.title])
		return AttackEvent.new(target, skill, &"miss", 0, skill.school as AttackEvent.School)
	var critical := false
	var chance := MeleeRules.critical_chance(world.hero.melee, target.melee)
	chance += critical_bonus + world.ability_critical_bonus
	critical = world.combat_random.randf() * 100.0 < chance
	var empowered := (skill.family == &"judgement"
		and int(effect(world.hero, &"art_of_war_1").get("critical_ready", 0)) > 0)
	if empowered:
		critical = true
		world.hero.buffs.erase(&"art_of_war_1")
	var weapon_roll := world.combat_random.randf()
	var raw := (MeleeRules.weapon_damage(world.hero.melee, weapon_roll)
		if skill.weapon_multiplier != 0.0 else 0.0)
	var amount := (raw * skill.weapon_multiplier + skill.minimum) * extra * damage_multiplier(world.hero)
	amount *= MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level)
	# Flat spells reuse a uniform rounding roll without depending on weapon damage bands.
	var value := (floori(amount) + int(weapon_roll < amount - floori(amount))
		if skill.weapon_multiplier == 0.0 else
		MeleeRules.round_weapon_damage(amount, world.hero.melee, weapon_roll))
	if critical:
		value = (roundi(value * SkillDefinition.catalog(&"art_of_war_1").critical_damage_percent / 100.0)
			if empowered else value * 2)
	return AttackEvent.new(target, skill, &"critical" if critical else &"hit",
		value, skill.school as AttackEvent.School)


static func resolve_magic(world: GridWorld, event: AttackEvent, death_turn: int = -1) -> void:
	SpellEffects.attack(world, event, event.skill.title, death_turn)
	AttackProcs.on_attack(world, event)
	if not world.is_terminal() and event.school == AttackEvent.School.HOLY:
		holy_event(world)


static func consume_flurry(hero: HeroState) -> void:
	if hero.buffs.has(&"shaman_flurry_1"):
		hero.buffs[&"shaman_flurry_1"].charges -= 1
		if int(hero.buffs[&"shaman_flurry_1"].charges) <= 0:
			hero.buffs.erase(&"shaman_flurry_1")


static func holy_event(world: GridWorld) -> void:
	if world.holy_event_counted or not has(world.hero, &"art_of_war_1"):
		return
	world.holy_event_counted = true
	var buff := effect(world.hero, &"art_of_war_1")
	if int(buff.get("critical_ready", 0)) > 0:
		return
	var events := int(buff.get("charges", 0)) + 1
	apply(world, &"art_of_war_1", {"charges": events % 3, "critical_ready": 1 if events >= 3 else 0})


static func bonus_strike(world: GridWorld, target: GridActor, off_hand: bool,
	multiplier: float, title: String, skill: SkillDefinition = null) -> void:
	if world.is_terminal() or not target.alive:
		return
	var weapon := world.hero.off_hand_melee() if off_hand else world.hero.melee
	var result := MeleeRules.outcome(weapon, target.melee,
		world.combat_random.randf() * 100)
	# Bonus strikes use normal hit/armor but cannot crit or trigger any primary hooks.
	if result == &"critical":
		result = &"hit"
	var value := MeleeRules.damage(weapon, target.melee, result,
		world.combat_random.randf(), multiplier, 0, recklessness_damage_multiplier(world.hero))
	var event := AttackEvent.new(target, skill, result,
		floori(value * damage_multiplier(world.hero)))
	event.origin = AttackEvent.Origin.BONUS
	event.hand = AttackEvent.Hand.OFF if off_hand else AttackEvent.Hand.MAIN
	SpellEffects.attack(world, event, title)


static func discharge(world: GridWorld, target: GridActor, reactive: bool) -> void:
	var shield := effect(world.hero, &"lightning_shield_1")
	if (shield.is_empty() or int(shield.charges) <= 0
		or (reactive and world.turn_count < int(shield.ready))):
		return
	shield.charges -= 1
	if reactive:
		shield.ready = world.turn_count + 3
	var value := SkillDefinition.catalog(&"lightning_shield_1").minimum
	value = floori(value * damage_multiplier(world.hero)
		* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level))
	SpellEffects.damage(world, target, value, "Lightning Shield", world.turn_count)
	if int(shield.charges) <= 0:
		world.hero.buffs.erase(&"lightning_shield_1")


static func finish(world: GridWorld, points: int, _skill: SkillDefinition) -> void:
	if world.is_terminal():
		return
	if has(world.hero, &"restless_blades_1"):
		var reduction := ceili(points * magnitude(world.hero, &"restless_blades_1") / 2.0)
		for key in world.hero.cooldowns:
			if key == "war_horn":
				continue
			world.hero.cooldowns[key] = maxi(world.turn_count, int(world.hero.cooldowns[key]) - reduction)
	world.add_message("Finisher spent %d combo points." % points)


static func wolf_tiles(world: GridWorld) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for direction in GridWorld.DIRECTIONS:
		var tile := world.player_tile + direction
		var occupant := world.actor_at(tile)
		if world.is_open(tile) or (occupant != null and occupant.summon_kind == "wolf"):
			tiles.append(tile)
	return tiles


static func summon_wolves(world: GridWorld, skill: SkillDefinition) -> void:
	var tiles := wolf_tiles(world)
	for actor in world.actors:
		if actor.alive and actor.summon_kind == "wolf":
			SummonRules.remove(world, actor)
	for index in range(2):
		var wolf := GridActor.new(tiles[index])
		wolf.title = "Spirit Wolf"
		wolf.creature_type = "beast"
		wolf.summon_kind = "wolf"
		wolf.summon_skill = skill.id
		wolf.spawn_id = "summon/%d" % world.actors.size()
		wolf.awards_experience = false
		wolf.corpse_visible = false
		wolf.max_health = skill.minimum
		wolf.health = wolf.max_health
		wolf.expires_turn = world.turn_count + 1 + skill.duration
		wolf.melee.level = world.hero.level
		wolf.melee.damage_min = world.hero.melee.damage_min * skill.weapon_multiplier
		wolf.melee.damage_max = world.hero.melee.damage_max * skill.weapon_multiplier
		wolf.melee.attack_power = floori(world.hero.melee.attack_power * skill.weapon_multiplier)
		wolf.melee.interval = 2.0
		world.actors.append(wolf)
	world.add_message("Two Spirit Wolves summoned.")


static func act_wolf(world: GridWorld, wolf: GridActor) -> void:
	var target := world.auto_attack_target
	if target == null or not target.alive or not world.has_sight(world.player_tile, target.tile):
		SummonRules.approach(world, wolf, world.player_tile, 1)
		wolf.swing.advance(false, wolf.melee.interval)
		return
	SummonRules.approach(world, wolf, target.tile, 1)
	var ready := GridWorld.tile_distance(wolf.tile, target.tile) == 1 and world.has_sight(wolf.tile, target.tile)
	for index in range(wolf.swing.advance(ready, wolf.melee.interval)):
		if world.is_terminal() or not target.alive:
			break
		var result := MeleeRules.outcome(wolf.melee, target.melee, world.combat_random.randf() * 100)
		var value := MeleeRules.damage(wolf.melee, target.melee, result,
			world.combat_random.randf())
		var before := target.health
		SpellEffects.damage(world, target, floori(value * damage_multiplier(world.hero)),
			wolf.title, world.turn_count, wolf, true, result)
		if not world.is_terminal():
			var skill := SkillDefinition.catalog(wolf.summon_skill)
			SpellEffects.heal(world, null,
				floori((before - target.health) * skill.healing_percent / 100.0), skill.title)
