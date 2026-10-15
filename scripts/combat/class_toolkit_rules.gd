class_name ClassToolkitRules
extends RefCounted

## Primary attacks call these hooks once. Bonus damage never calls attack hooks.
static func has(hero: HeroState, identifier: StringName) -> bool:
	return hero.find_skill(identifier) != null


static func magnitude(hero: HeroState, identifier: StringName) -> int:
	var skill := hero.find_skill(identifier)
	return 0 if skill == null else skill.minimum


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


static func cost(hero: HeroState, skill: SkillDefinition) -> int:
	if skill.effect == SkillDefinition.Effect.PASSIVE:
		return 0
	if skill.family == &"execute" and hero.buffs.has(&"sudden_death_1"):
		return 0
	if skill.family == &"judgement" and hero.buffs.has(&"divine_purpose_1"):
		return 0
	if skill.rage_cost > 0 and hero.buffs.has(&"battle_trance_1"):
		return 0
	var amount := skill.rage_cost
	if skill.effect == SkillDefinition.Effect.EXECUTE:
		amount = clampi(hero.rage, skill.rage_cost, skill.execute_rage_cap)
	if skill.class_tab == &"Paladin":
		amount = ceili(amount * (1.0 - magnitude(hero, &"benediction_1") / 100.0))
	return amount


static func consume_cost_proc(hero: HeroState, skill: SkillDefinition) -> void:
	if skill.family == &"execute" and hero.buffs.has(&"sudden_death_1"):
		hero.buffs.erase(&"sudden_death_1")
	elif skill.family == &"judgement" and hero.buffs.has(&"divine_purpose_1"):
		hero.buffs.erase(&"divine_purpose_1")
	elif skill.rage_cost > 0:
		hero.buffs.erase(&"battle_trance_1")


static func cooldown(hero: HeroState, skill: SkillDefinition) -> int:
	var turns := skill.cooldown_seconds
	match skill.family:
		&"charge": turns -= magnitude(hero, &"juggernaut_1")
		&"earth_shock": turns -= magnitude(hero, &"improved_earth_shock_1")
		&"divine_shield": turns -= magnitude(hero, &"guardians_favor_1")
		&"judgement":
			if has(hero, &"sanctity_of_battle_1"):
				turns = maxi(1, ceili(turns / hero.attack_haste()))
	return maxi(0, turns)


static func damage_multiplier(hero: HeroState) -> float:
	var percent := int(effect(hero, &"vengeance_1").get("bonus_percent", 0))
	percent += int(effect(hero, &"bandits_guile_1").get("bonus_percent", 0))
	var multiplier := 1.0 + percent / 100.0
	if hero.buffs.has(&"divine_shield_1"):
		multiplier *= 1.0 - magnitude(hero, &"divine_shield_1") / 100.0
	return multiplier


static func can_apply(world: GridWorld, skill: SkillDefinition, target: GridActor) -> bool:
	match skill.family:
		&"feral_spirit": return wolf_tiles(world).size() >= 2
		&"windfury_weapon", &"instant_poison", &"deadly_poison": return world.hero.equipment.has("weapons")
		&"whirlwind":
			return world.actors.any(func(actor: GridActor) -> bool:
				return eligible(world, actor, skill.range_tiles))
		&"execute":
			return skill.execute_eligible(target) or world.hero.buffs.has(&"sudden_death_1")
	return true


static func eligible(world: GridWorld, target: GridActor, radius: int) -> bool:
	return (target.alive and target.relationship != GridActor.Relationship.FRIENDLY
		and GridWorld.tile_distance(world.player_tile, target.tile) <= radius
		and world.has_sight(world.player_tile, target.tile))


static func resolve(world: GridWorld, skill: SkillDefinition, target: GridActor) -> void:
	match skill.family:
		&"whirlwind":
			for enemy in world.actors.duplicate():
				if world.is_terminal():
					break
				if eligible(world, enemy, skill.range_tiles):
					enemy.relationship = GridActor.Relationship.HOSTILE
					enemy.engaged = true
					physical_attack(world, enemy, skill, skill.minimum, true, false)
		&"booming_shout":
			for enemy in world.actors.duplicate():
				if world.is_terminal():
					break
				if not enemy.chest and eligible(world, enemy, skill.range_tiles):
					enemy.relationship = GridActor.Relationship.HOSTILE
					enemy.engaged = true
					enemy.returning_home = false
					SpellEffects.damage(world, enemy, skill.minimum, skill.title, -1, null, true)
		&"earth_shock":
			var extra := 1.0 + magnitude(world.hero, &"elemental_assault_1") / 100.0
			if world.hero.buffs.has(&"elemental_assault_1"):
				extra += 0.5
				world.hero.buffs.erase(&"elemental_assault_1")
			extra *= ClassToolkitData.EARTH_SHOCK_DAMAGE_MULTIPLIER
			var result := magic_attack(world, target, skill, extra)
			if result.landed and target.alive and not world.is_terminal():
				target.swing.remaining += 1.0
				target.debuffs["interrupt"] = {"until": world.turn_count + 3}
				if has(world.hero, &"improved_earth_shock_1"):
					target.stunned_until = world.turn_count + 1 + magnitude(world.hero, &"improved_earth_shock_1")
				world.add_message("Earth Shock interrupts %s and delays its next swing." % target.title)
		&"feral_spirit": summon_wolves(world, skill)


static func eviscerate(world: GridWorld, points: int) -> void:
	var skill := world.hero.find_skill(&"eviscerate_1")
	var target := world.last_attacked_enemy
	if (skill == null or target == null or not world.actors.has(target)
		or not eligible(world, target, skill.range_tiles)):
		return
	target.relationship = GridActor.Relationship.HOSTILE
	target.engaged = true
	target.returning_home = false
	world.auto_attack_target = target
	physical_attack(world, target, skill, skill.minimum * points, false)


static func physical_attack(world: GridWorld, target: GridActor, skill: SkillDefinition,
	flat_bonus: int, build_points: bool = true, commit_target: bool = true) -> void:
	if commit_target:
		world.last_attacked_enemy = target
	var outcome := weapon_outcome(world, target, skill, world.hero.melee)
	var behind := MeleeRules.is_behind(target.facing, world.player_tile - target.tile)
	var multiplier := skill.weapon_multiplier
	if behind:
		multiplier *= 1.0 + magnitude(world.hero, &"opportunity_1") / 100.0
	var value := MeleeRules.damage(world.hero.melee, target.melee, outcome.result,
		world.combat_random.randf(), multiplier, flat_bonus)
	value = floori(value * damage_multiplier(world.hero))
	SpellEffects.damage(world, target, value, "%s (%s)" % [skill.title, outcome.result],
		-1, null, true, outcome.result)
	on_attack(world, target, skill, outcome.landed, outcome.critical, value, true, false, build_points)


static func weapon_outcome(world: GridWorld, target: GridActor, skill: SkillDefinition,
	weapon: MeleeProfile) -> Dictionary:
	var extra := int(target.debuffs.get("crusader_crit", {}).get("bonus", 0))
	if skill != null and skill.family == &"heroic_strike":
		extra += magnitude(world.hero, &"incite_1")
	weapon.critical += extra
	var result := MeleeRules.outcome(weapon, target.melee,
		MeleeRules.is_behind(target.facing, world.player_tile - target.tile),
		world.combat_random.randf() * 100.0)
	weapon.critical -= extra
	var landed := result not in [&"miss", &"dodge"]
	var guaranteed := false
	if skill != null and landed:
		var key := &"incite_1" if skill.family == &"heroic_strike" else (
			&"juggernaut_1" if skill.family == &"mortal_strike" else &"")
		if key != &"" and world.hero.buffs.has(key):
			world.hero.buffs.erase(key)
			result = &"critical"
			guaranteed = true
	if (skill != null and skill.family == &"heroic_strike" and result == &"critical"
		and not guaranteed):
		apply(world, &"incite_1", {"charges": 1})
	return {"result": result, "landed": landed, "critical": result == &"critical"}


static func magic_attack(world: GridWorld, target: GridActor, skill: SkillDefinition,
	extra: float = 1.0) -> Dictionary:
	world.last_attacked_enemy = target
	world.auto_attack_target = target
	var hit_chance := 100.0 - MeleeRules.miss_chance(world.hero.melee, target.melee)
	if world.combat_random.randf() * 100.0 >= hit_chance:
		world.npc_combat_text.emit(target.tile, 0, &"miss")
		world.add_message("%s misses %s." % [skill.title, target.title])
		return {"landed": false, "critical": false}
	var critical := false
	var chance := MeleeRules.critical_chance(world.hero.melee, target.melee)
	chance += int(target.debuffs.get("crusader_crit", {}).get("bonus", 0))
	critical = world.combat_random.randf() * 100.0 < chance
	if skill.family == &"judgement":
		for key: StringName in [&"art_of_war_1", &"sacred_duty_1"]:
			if int(effect(world.hero, key).get("critical_ready", 0)) > 0:
				critical = true
				world.hero.buffs.erase(key)
	var weapon_roll := world.combat_random.randf()
	var raw := MeleeRules.weapon_damage(world.hero.melee, weapon_roll)
	var flat_bonus := skill.minimum
	if skill.family == &"judgement":
		flat_bonus += magnitude(world.hero, &"sanctity_of_battle_1")
	var value := MeleeRules.round_weapon_damage((raw * skill.weapon_multiplier
		+ flat_bonus) * extra * damage_multiplier(world.hero)
		* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level),
		world.hero.melee, weapon_roll)
	if critical:
		value *= 2
	SpellEffects.damage(world, target, value, skill.title, -1, null, false,
		&"critical" if critical else &"hit")
	on_attack(world, target, skill, true, critical, value, false)
	if not world.is_terminal() and skill.school == 1:
		holy_event(world)
	return {"landed": true, "critical": critical}


static func on_attack(world: GridWorld, target: GridActor, skill: SkillDefinition,
	landed: bool, critical: bool, value: int, physical: bool, off_hand: bool = false,
	build_points: bool = true) -> void:
	if world.is_terminal():
		return
	var direct := skill != null
	var finisher := direct and skill.family == &"eviscerate"
	if landed and build_points and not finisher and (direct or (physical and not off_hand)):
		if has(world.hero, &"relentless_assault_1") and not world.combo_event_counted:
			world.hero.gain_combo_point()
			world.combo_event_counted = true
	if landed and direct and build_points and not finisher:
		if critical and has(world.hero, &"relentless_assault_1") and has(world.hero, &"seal_fate_1"):
			world.hero.combo_points = mini(5, world.hero.combo_points + 1)
		if has(world.hero, &"bandits_guile_1"):
			var previous := effect(world.hero, &"bandits_guile_1")
			var hits := int(previous.get("charges", 0)) + 1
			var percent := int(previous.get("bonus_percent", 0))
			if hits >= 4:
				var step := magnitude(world.hero, &"bandits_guile_1")
				percent = mini(3 * step, percent + step)
				hits = 0
			apply(world, &"bandits_guile_1", {"charges": hits, "bonus_percent": percent})
	if critical:
		if physical:
			var flurry := &"shaman_flurry_1" if has(world.hero, &"shaman_flurry_1") else &"warrior_flurry_1"
			world.hero.buffs.erase(&"warrior_flurry_1")
			world.hero.buffs.erase(&"shaman_flurry_1")
			apply(world, flurry, {"charges": 3, "haste_percent": magnitude(world.hero, flurry)})
			apply(world, &"wrecking_crew_1", {"physical_percent": magnitude(world.hero, &"wrecking_crew_1")})
			apply(world, &"elemental_assault_1", {"charges": 1})
		if direct and skill.family != &"heroic_strike" and not finisher:
			apply(world, &"battle_trance_1", {"charges": 1})
		var stacks := mini(3, int(effect(world.hero, &"vengeance_1").get("charges", 0)) + 1)
		apply(world, &"vengeance_1", {"charges": stacks,
			"bonus_percent": stacks * magnitude(world.hero, &"vengeance_1")})
	if not landed:
		return
	if physical:
		if direct and skill.family != &"execute" and proc(world, &"sudden_death_1"):
			apply(world, &"sudden_death_1", {"charges": 1})
		if off_hand:
			if proc(world, &"combat_potency_1"):
				world.hero.gain_rage(magnitude(world.hero, &"combat_potency_1"))
		if target.alive:
			weapon_procs(world, target, off_hand, not direct or skill.family == &"heroic_strike")
		if direct and value > 0 and has(world.hero, &"sweeping_strikes_1"):
			for other in world.actors:
				if other != target and other.relationship == GridActor.Relationship.HOSTILE and eligible(world, other, 1):
					SpellEffects.damage(world, other, floori(value * magnitude(world.hero, &"sweeping_strikes_1") / 100.0), "Sweeping Strikes", -1, null, true)
					break
	if direct and skill.family == &"judgement" and not world.is_terminal():
		if target.alive and has(world.hero, &"heart_of_the_crusader_1"):
			target.debuffs["crusader_crit"] = {"until": world.turn_count + 11,
				"bonus": magnitude(world.hero, &"heart_of_the_crusader_1")}
		if proc(world, &"divine_purpose_1"):
			apply(world, &"divine_purpose_1", {"charges": 1})
		if proc(world, &"sacred_duty_1"):
			apply(world, &"sacred_duty_1", {"critical_ready": 1})


static func consume_flurry(hero: HeroState) -> void:
	for key: StringName in [&"warrior_flurry_1", &"shaman_flurry_1"]:
		if hero.buffs.has(key):
			hero.buffs[key].charges -= 1
			if int(hero.buffs[key].charges) <= 0:
				hero.buffs.erase(key)


static func holy_event(world: GridWorld) -> void:
	if world.holy_event_counted or not has(world.hero, &"art_of_war_1"):
		return
	world.holy_event_counted = true
	var buff := effect(world.hero, &"art_of_war_1")
	if int(buff.get("critical_ready", 0)) > 0:
		return
	var events := int(buff.get("charges", 0)) + 1
	apply(world, &"art_of_war_1", {"charges": events % 3, "critical_ready": 1 if events >= 3 else 0})


static func weapon_procs(world: GridWorld, target: GridActor, off_hand: bool,
	allow_main_gauche: bool = true) -> void:
	var enchant := effect(world.hero, &"windfury_weapon_1")
	var weapon_id := world.hero.weapon_id()
	if (not off_hand and not enchant.is_empty() and int(enchant.weapon_id) == weapon_id
		and world.turn_count >= int(enchant.ready)
		and world.combat_random.randf() < SkillDefinition.catalog(&"windfury_weapon_1").coefficient):
		enchant.ready = world.turn_count + 3
		for index in range(2):
			bonus_strike(world, target, false, 1.0 + magnitude(world.hero, &"elemental_weapons_1") / 100.0, "Windfury")
	if world.is_terminal() or not target.alive:
		return
	PoisonRules.on_hit(world, target, off_hand)
	if world.is_terminal() or not target.alive:
		return
	if proc(world, &"static_shock_1"):
		discharge(world, target, false)
	if allow_main_gauche and not off_hand and world.hero.has_off_hand_weapon() and proc(world, &"main_gauche_1"):
		bonus_strike(world, target, true, 1.0, "Main Gauche")


static func bonus_strike(world: GridWorld, target: GridActor, off_hand: bool,
	multiplier: float, title: String) -> void:
	if world.is_terminal() or not target.alive:
		return
	var weapon := world.hero.off_hand_melee() if off_hand else world.hero.melee
	var result := MeleeRules.outcome(weapon, target.melee,
		MeleeRules.is_behind(target.facing, world.player_tile - target.tile), world.combat_random.randf() * 100)
	# Bonus strikes use normal hit/armor but cannot crit or trigger any primary hooks.
	if result == &"critical":
		result = &"hit"
	var value := MeleeRules.damage(weapon, target.melee, result,
		world.combat_random.randf(), multiplier)
	SpellEffects.damage(world, target, floori(value * damage_multiplier(world.hero)),
		title, -1, null, true, result)


static func discharge(world: GridWorld, target: GridActor, reactive: bool) -> void:
	var shield := effect(world.hero, &"lightning_shield_1")
	if (shield.is_empty() or int(shield.charges) <= 0
		or (reactive and world.turn_count < int(shield.ready))):
		return
	shield.charges -= 1
	if reactive:
		shield.ready = world.turn_count + 3
	var value := SkillDefinition.catalog(&"lightning_shield_1").minimum
	value = floori(value * (1.0 + magnitude(world.hero, &"improved_shields_1") / 100.0)
		* damage_multiplier(world.hero)
		* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level))
	SpellEffects.damage(world, target, value, "Lightning Shield", world.turn_count)
	if int(shield.charges) <= 0:
		world.hero.buffs.erase(&"lightning_shield_1")


static func finish(world: GridWorld, points: int) -> void:
	if world.is_terminal():
		return
	if has(world.hero, &"restless_blades_1"):
		var reduction := ceili(points * magnitude(world.hero, &"restless_blades_1") / 2.0)
		for key in world.hero.cooldowns:
			world.hero.cooldowns[key] = maxi(world.turn_count, int(world.hero.cooldowns[key]) - reduction)
	if has(world.hero, &"relentless_assault_1") and proc(world, &"ruthlessness_1"):
		world.hero.combo_points = mini(5, world.hero.combo_points + magnitude(world.hero, &"ruthlessness_1"))
	if proc(world, &"relentless_strikes_1", points):
		world.hero.gain_rage(magnitude(world.hero, &"relentless_strikes_1"))
	world.add_message("Finisher spent %d combo points." % points)


static func incoming(world: GridWorld, attacker: GridActor, amount: int, critical: bool) -> void:
	if world.is_terminal() or not attacker.alive:
		return
	if amount > 0 and critical and has(world.hero, &"eye_for_an_eye_1"):
		SpellEffects.damage(world, attacker, floori(amount * magnitude(world.hero, &"eye_for_an_eye_1") / 100.0), "Eye for an Eye", world.turn_count)


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
		var result := MeleeRules.outcome(wolf.melee, target.melee, false, world.combat_random.randf() * 100)
		var value := MeleeRules.damage(wolf.melee, target.melee, result,
			world.combat_random.randf())
		var before := target.health
		SpellEffects.damage(world, target, floori(value * damage_multiplier(world.hero)),
			wolf.title, world.turn_count, wolf, true, result)
		if not world.is_terminal() and has(world.hero, &"spirit_hunt_1"):
			SpellEffects.heal(world, null, floori((before - target.health) * magnitude(world.hero, &"spirit_hunt_1") / 100.0), "Spirit Hunt")
