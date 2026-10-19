class_name AttackProcs
extends RefCounted


static func on_attack(world: GridWorld, event: AttackEvent) -> void:
	if world.is_terminal() or not event.is_primary():
		return
	# Keep this order explicit: handlers consume randomness and can end the encounter.
	_maelstrom(world, event)
	if event.is_swing() and event.hand == AttackEvent.Hand.MAIN:
		ClassSpellEffects.on_melee(world, event)
	if world.is_terminal():
		return
	_combo_points(world, event)
	_direct_hit_rewards(world, event)
	_critical_buffs(world, event)
	if not event.landed():
		return
	if event.school == AttackEvent.School.PHYSICAL:
		_physical_hit(world, event)
	if event.is_direct() and event.is_family(&"judgement") and not world.is_terminal():
		_judgement(world, event.target)


static func weapon_procs(world: GridWorld, event: AttackEvent) -> void:
	if not event.can_trigger_weapon_procs():
		return
	_windfury(world, event)
	if world.is_terminal() or not event.target.alive:
		return
	PoisonRules.on_hit(world, event.target, event.hand == AttackEvent.Hand.OFF)
	if world.is_terminal() or not event.target.alive:
		return
	if ClassToolkitRules.proc(world, &"static_shock_1"):
		ClassToolkitRules.discharge(world, event.target, false)
	if (event.can_trigger_main_gauche() and world.hero.has_off_hand_weapon()
		and ClassToolkitRules.proc(world, &"main_gauche_1")):
		ClassToolkitRules.bonus_strike(world, event.target, true, 1.0, "Main Gauche")


static func _combo_points(world: GridWorld, event: AttackEvent) -> void:
	if (event.can_build_combo() and ClassToolkitRules.has(world.hero, &"relentless_assault_1")
		and not world.combo_event_counted):
		world.hero.gain_combo_point()
		world.combo_event_counted = true


static func _direct_hit_rewards(world: GridWorld, event: AttackEvent) -> void:
	if not event.can_build_combo() or not event.is_direct():
		return
	if (event.critical() and ClassToolkitRules.has(world.hero, &"relentless_assault_1")
		and ClassToolkitRules.has(world.hero, &"seal_fate_1")):
		world.hero.combo_points = mini(5, world.hero.combo_points + 1)
	if ClassToolkitRules.has(world.hero, &"bandits_guile_1"):
		var previous := ClassToolkitRules.effect(world.hero, &"bandits_guile_1")
		var hits := int(previous.get("charges", 0)) + 1
		var percent := int(previous.get("bonus_percent", 0))
		if hits >= 4:
			var step := ClassToolkitRules.magnitude(world.hero, &"bandits_guile_1")
			percent = mini(3 * step, percent + step)
			hits = 0
		ClassToolkitRules.apply(world, &"bandits_guile_1",
			{"charges": hits, "bonus_percent": percent})


static func _critical_buffs(world: GridWorld, event: AttackEvent) -> void:
	if not event.critical():
		return
	if event.school == AttackEvent.School.PHYSICAL:
		ClassToolkitRules.apply(world, &"shaman_flurry_1",
			{"charges": 3, "haste_percent": ClassToolkitRules.magnitude(world.hero, &"shaman_flurry_1")})
		ClassToolkitRules.apply(world, &"wrecking_crew_1",
			{"physical_percent": ClassToolkitRules.magnitude(world.hero, &"wrecking_crew_1")})
	if event.can_trigger_battle_trance():
		ClassToolkitRules.apply(world, &"battle_trance_1", {"charges": 1})
	var stacks := mini(3, int(ClassToolkitRules.effect(world.hero,
		&"vengeance_1").get("charges", 0)) + 1)
	ClassToolkitRules.apply(world, &"vengeance_1", {"charges": stacks,
		"bonus_percent": stacks * ClassToolkitRules.magnitude(world.hero, &"vengeance_1")})


static func _physical_hit(world: GridWorld, event: AttackEvent) -> void:
	if (event.is_direct() and not event.is_family(&"execute")
		and ClassToolkitRules.proc(world, &"sudden_death_1")):
		ClassToolkitRules.apply(world, &"sudden_death_1", {"charges": 1})
	if event.hand == AttackEvent.Hand.OFF and ClassToolkitRules.proc(world, &"combat_potency_1"):
		world.hero.gain_rage(ClassToolkitRules.magnitude(world.hero, &"combat_potency_1"))
	if event.target.alive:
		weapon_procs(world, event)
	if event.is_direct() and event.amount > 0 and ClassToolkitRules.has(world.hero, &"sweeping_strikes_1"):
		_sweeping_strikes(world, event)


static func _sweeping_strikes(world: GridWorld, event: AttackEvent) -> void:
	for other in world.actors:
		if (other != event.target and other.relationship == GridActor.Relationship.HOSTILE
			and ClassToolkitRules.eligible(world, other, 1)):
			var value := floori(event.amount
				* ClassToolkitRules.magnitude(world.hero, &"sweeping_strikes_1") / 100.0)
			SpellEffects.damage(world, other, value, "Sweeping Strikes", -1, null, true)
			break


static func _judgement(world: GridWorld, target: GridActor) -> void:
	if target.alive and ClassToolkitRules.has(world.hero, &"heart_of_the_crusader_1"):
		target.debuffs["crusader_crit"] = {"until": world.turn_count + 11,
			"bonus": ClassToolkitRules.magnitude(world.hero, &"heart_of_the_crusader_1")}
	if ClassToolkitRules.proc(world, &"divine_purpose_1"):
		ClassToolkitRules.apply(world, &"divine_purpose_1", {"charges": 1})


static func _maelstrom(world: GridWorld, event: AttackEvent) -> void:
	var skill := world.hero.find_skill(&"maelstrom_weapon_1")
	if (skill == null or world.maelstrom_event_counted or not event.landed()
		or event.school != AttackEvent.School.PHYSICAL):
		return
	world.maelstrom_event_counted = true
	var stacks := ClassToolkitRules.maelstrom_stacks(world.hero)
	if stacks >= skill.maximum:
		return
	world.hero.buffs[skill.id] = {"armor": 0, "until": 0, "charges": stacks + skill.minimum}
	world.add_message("Maelstrom Weapon: %d/%d%s." % [stacks + skill.minimum, skill.maximum,
		"; Lava Burst ready instantly" if stacks + skill.minimum == skill.maximum else ""])


static func _windfury(world: GridWorld, event: AttackEvent) -> void:
	var enchant := ClassToolkitRules.effect(world.hero, &"windfury_weapon_1")
	if (event.hand == AttackEvent.Hand.MAIN and not enchant.is_empty()
		and int(enchant.weapon_id) == world.hero.weapon_id()
		and world.turn_count >= int(enchant.ready)
		and world.combat_random.randf() < SkillDefinition.catalog(&"windfury_weapon_1").coefficient):
		enchant.ready = world.turn_count + 3
		for index in range(2):
			ClassToolkitRules.bonus_strike(world, event.target, false,
				1.0 + ClassToolkitRules.magnitude(world.hero, &"elemental_weapons_1") / 100.0,
				"Windfury", SkillDefinition.catalog(&"windfury_weapon_1"))
