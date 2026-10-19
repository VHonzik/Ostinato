class_name PaladinRules
extends RefCounted

## A sentenced target and a single fixed patch of ground belong to this Loop.
static func sentence(world: GridWorld, target: GridActor, skill: SkillDefinition) -> void:
	world.last_attacked_enemy = target
	world.auto_attack_target = target
	var event := ClassToolkitRules.magic_outcome(world, target, skill)
	if not event.landed():
		return
	target.debuffs[skill.id] = {"until": world.turn_count + 1 + skill.delay_turns,
		"damage": event.amount, "critical": int(event.critical())}
	world.npc_ability_hit.emit(target, skill.family)
	world.add_message("Judgement on %s: verdict in %d turns." % [
		target.title, skill.delay_turns])


static func consecrate(world: GridWorld, skill: SkillDefinition) -> void:
	var raw := MeleeRules.weapon_damage(world.hero.melee, world.combat_random.randf())
	world.consecration = {"center": world.player_tile,
		"until": world.turn_count + 1 + skill.duration, "next_tick": world.turn_count + 1,
		"damage": (skill.periodic_damage + raw * skill.weapon_multiplier)
			* ClassToolkitRules.damage_multiplier(world.hero)}
	world.add_message("Consecration: holy ground for %d turns." % skill.duration)


static func covers(world: GridWorld, tile: Vector2i) -> bool:
	if world.consecration.is_empty():
		return false
	var skill := world.hero.find_skill(&"consecration_1")
	var center: Vector2i = world.consecration.center
	return (skill != null and world.turn_count < int(world.consecration.until)
		and GridWorld.tile_distance(center, tile) <= skill.range_tiles
		and world.has_sight(center, tile))


static func melee_vulnerability(world: GridWorld, event: AttackEvent) -> void:
	var target := event.target
	if (not event.landed() or event.school != AttackEvent.School.PHYSICAL
		or not event.is_primary() or GridWorld.tile_distance(world.player_tile, target.tile) > 1
		or not target.debuffs.has(&"heart_of_the_crusader_1")):
		return
	target.debuffs.erase(&"heart_of_the_crusader_1")
	var skill := world.hero.find_skill(&"heart_of_the_crusader_1")
	if skill == null or not target.alive:
		return
	var weapon := (world.hero.off_hand_melee() if event.hand == AttackEvent.Hand.OFF
		else world.hero.melee)
	var roll := world.combat_random.randf()
	var raw := MeleeRules.weapon_damage(weapon, roll)
	if event.hand == AttackEvent.Hand.OFF:
		raw *= (HeroState.BASE_OFF_HAND_DAMAGE_PERCENT
			+ ClassToolkitRules.magnitude(world.hero, &"ambidexterity_1")) / 100.0
	var value := MeleeRules.round_weapon_damage(raw * skill.weapon_multiplier
		* ClassToolkitRules.damage_multiplier(world.hero)
		* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level), weapon, roll)
	SpellEffects.damage(world, target, value, skill.title, world.turn_count)


static func tick(world: GridWorld) -> void:
	if world.is_terminal():
		return
	for target in world.actors:
		var effect: Dictionary = target.debuffs.get(&"judgement_1", {})
		if effect.is_empty():
			continue
		if not target.alive:
			target.debuffs.erase(&"judgement_1")
			continue
		if world.turn_count < int(effect.until):
			continue
		target.debuffs.erase(&"judgement_1")
		var skill := world.hero.find_skill(&"judgement_1")
		var event := AttackEvent.new(target, skill,
			&"critical" if int(effect.critical) == 1 else &"hit", int(effect.damage),
			AttackEvent.School.HOLY)
		ClassToolkitRules.resolve_magic(world, event, world.turn_count)
		if world.is_terminal():
			return
	var ground := world.consecration
	if ground.is_empty():
		return
	if world.turn_count >= int(ground.until):
		world.consecration.clear()
		return
	if world.turn_count < int(ground.next_tick):
		return
	ground.next_tick += 1
	world.consecration_ticked.emit()
	for target in world.actors:
		if (not target.alive or target.relationship == GridActor.Relationship.FRIENDLY
			or not covers(world, target.tile)):
			continue
		var amount := float(ground.damage) * MeleeRules.level_damage_multiplier(
			world.hero.level, target.melee.level)
		var value := floori(amount)
		if world.combat_random.randf() < amount - value:
			value += 1
		SpellEffects.damage(world, target, value, "Consecration", world.turn_count)
		if world.is_terminal():
			return
