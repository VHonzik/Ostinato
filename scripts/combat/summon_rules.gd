class_name SummonRules
extends RefCounted

## FR-018: summons use ordinary actor occupancy and stable saved actor ordering.
static func slot(skill: SkillRank) -> String:
	if skill.family in [&"summon_imp", &"summon_voidwalker"]:
		return "pet"
	return "fire" if skill.family == &"searing_totem" else "earth"


static func active(world: GridWorld, kind: String) -> GridActor:
	for actor in world.actors:
		if actor.alive and actor.summon_kind == kind:
			return actor
	return null


static func placement(world: GridWorld, skill: SkillRank) -> Vector2i:
	var previous := active(world, slot(skill))
	for direction in GridWorld.DIRECTIONS:
		var tile := world.player_tile + direction
		if world.is_open(tile) or (slot(skill) != "pet" and previous != null and previous.tile == tile):
			return tile
	return Vector2i(-1, -1)


static func summon(world: GridWorld, skill: SkillRank) -> void:
	var tile := placement(world, skill)
	if tile == Vector2i(-1, -1):
		return
	var previous := active(world, slot(skill))
	if previous != null:
		remove(world, previous)
	var actor := GridActor.new(tile)
	actor.summon_kind = slot(skill)
	actor.summon_skill = skill.id
	actor.title = skill.title.trim_prefix("Summon ")
	actor.spawn_id = "summon/%d" % world.actors.size()
	actor.awards_experience = false
	actor.corpse_visible = false
	actor.melee.level = world.hero.level
	if actor.summon_kind == "pet":
		actor.npc_id = 416 if skill.family == &"summon_imp" else 1860
		actor.creature_type = "demon"
		set_pet_level(actor, world.hero.level, true)
	else:
		actor.max_health = 50 if skill.family == &"stoneclaw_totem" else 5
		actor.health = actor.max_health
		actor.expires_turn = world.turn_count + 1 + skill.duration
	world.actors.append(actor)
	refresh_auras(world)
	world.add_message("%s summoned." % actor.title)


static func set_pet_level(actor: GridActor, level: int, fill: bool = false) -> void:
	var values: Array = SummonData.LEVELS[str(actor.npc_id)][mini(level, 60) - 1]
	actor.melee.level = level
	var attributes := pet_attributes(actor)
	var extra_stamina := int(attributes.stamina)
	actor.max_health = int(values[0]) + mini(20, extra_stamina) + maxi(0, extra_stamina - 20) * 10
	actor.max_mana = int(values[1]) + maxi(0, (int(attributes.intellect) - int(values[5]) - 20) * 15 + 20)
	actor.melee.armor = int(values[2]) + int(attributes.agility) * 2 + actor.aura_armor
	var strength := int(attributes.strength)
	actor.melee.attack_power = maxi(0, strength - 10 if actor.npc_id == 416 else strength * 2 - 20)
	for buff in actor.buffs.values():
		actor.melee.armor += int(buff.get("armor", 0))
		actor.melee.attack_power += int(buff.get("attack_power", 0))
	actor.melee.damage_min = float(values[7])
	actor.melee.damage_max = float(values[7]) * 1.5
	actor.health = actor.max_health if fill else mini(actor.health, actor.max_health)
	actor.mana = actor.max_mana if fill else mini(actor.mana, actor.max_mana)


static func pet_attributes(actor: GridActor) -> Dictionary:
	var values: Array = SummonData.LEVELS[str(actor.npc_id)][mini(actor.melee.level, 60) - 1]
	var attributes := {"strength": int(values[3]) + actor.aura_strength,
		"spirit": int(values[4]), "intellect": int(values[5]), "agility": int(values[6]),
		"stamina": actor.aura_stamina}
	for buff in actor.buffs.values():
		for attribute in attributes:
			attributes[attribute] += int(buff.get(attribute, 0))
	return attributes



static func remove(world: GridWorld, actor: GridActor) -> void:
	actor.alive = false
	actor.health = 0
	actor.engaged = false
	actor.summon_target = -1
	actor.corpse_visible = false
	refresh_auras(world)


static func command(world: GridWorld, identifier: StringName, target: GridActor) -> bool:
	var pet := active(world, "pet")
	if pet == null:
		world.add_message("No active pet.")
		return false
	if identifier == &"pet_dismiss":
		remove(world, pet)
	elif identifier == &"pet_follow":
		pet.summon_target = -1
		pet.ability_ready = 0
	elif identifier == &"pet_attack":
		if (target == null or not world.actors.has(target) or not target.alive
			or target.relationship == GridActor.Relationship.FRIENDLY
			or not world.has_sight(world.player_tile, target.tile)):
			return false
		if pet.summon_target != world.actors.find(target):
			pet.ability_ready = 0
		pet.summon_target = world.actors.find(target)
		target.relationship = GridActor.Relationship.HOSTILE
		target.engaged = true
		target.returning_home = false
		add_threat(world, target, pet, 1)
	world.add_message(ClassSkillData.pet_command(identifier).title)
	return true


static func add_threat(world: GridWorld, target: GridActor, source: GridActor, amount: int) -> void:
	var key := str(-1 if source == null else world.actors.find(source))
	target.threat[key] = int(target.threat.get(key, 0)) + maxi(0, amount)


static func enemy_target(world: GridWorld, actor: GridActor) -> GridActor:
	var best: GridActor
	var fade := 55 if world.hero.buffs.has(&"fade_1") else 0
	var score := int(actor.threat.get("-1", 0)) - fade
	for key in actor.threat:
		var index := int(key)
		if index < 0 or index >= world.actors.size():
			continue
		var candidate := world.actors[index]
		if candidate.alive and candidate.summon_kind != "" and int(actor.threat[key]) > score:
			best = candidate
			score = int(actor.threat[key])
	return best


static func act(world: GridWorld, actor: GridActor) -> void:
	if world.is_terminal():
		return
	if actor.expires_turn > 0 and world.turn_count >= actor.expires_turn:
		remove(world, actor)
		return
	var skill := SkillRank.catalog(actor.summon_skill)
	if actor.summon_kind == "pet":
		if actor.melee.level != world.hero.level:
			set_pet_level(actor, world.hero.level)
		if world.turn_count % 4 == 0:
			var attributes := pet_attributes(actor)
			if world.turn_count - actor.last_mana_turn >= 5:
				var spirit: float = attributes.spirit
				var regen := spirit / 4.0 + 12.5 if actor.npc_id == 416 else spirit / 5.0 + 15.0
				actor.mana = mini(actor.max_mana,
					actor.mana + int(sqrt(float(attributes.intellect)) * regen * 0.4))
			if not world.in_combat():
				var regen := float(attributes.spirit) * 0.11 + 1 if actor.npc_id == 416 else float(attributes.spirit) * 0.25
				actor.health = mini(actor.max_health, actor.health + int(regen * 4))
		var target: GridActor = null
		if actor.summon_target >= 0 and actor.summon_target < world.actors.size():
			target = world.actors[actor.summon_target]
		if (target == null or not world.actors.has(target) or not target.alive
			or target.relationship == GridActor.Relationship.FRIENDLY
			or not world.has_sight(world.player_tile, target.tile)):
			actor.summon_target = -1
			actor.ability_ready = 0
			approach(world, actor, world.player_tile, 1)
			actor.swing.advance(false, actor.melee.interval)
			return
		var imp := actor.npc_id == 416
		approach(world, actor, target.tile, 6 if imp else 1)
		if not world.has_sight(actor.tile, target.tile):
			actor.ability_ready = 0
			return
		var distance := GridWorld.tile_distance(actor.tile, target.tile)
		if imp:
			var cost := 20 if actor.melee.level >= 8 else 10
			if distance <= 6 and actor.mana >= cost:
				if actor.ability_ready == 0:
					actor.ability_ready = world.turn_count + 1
				elif world.turn_count >= actor.ability_ready:
					actor.mana -= cost
					actor.last_mana_turn = world.turn_count
					actor.ability_ready = world.turn_count + 2
					var rank_two := actor.melee.level >= 8
					var base := 12 if rank_two else 6
					base += int((mini(actor.melee.level, 13 if rank_two else 5)
						- (8 if rank_two else 1)) * (0.4 if rank_two else 0.3))
					spell_attack(world, actor, target, base, base + 2, 2, "Firebolt")
			else:
				actor.ability_ready = 0
		else:
			if distance == 1 and actor.melee.level >= 10 and actor.mana >= 20 and world.turn_count >= actor.secondary_ready:
				actor.mana -= 20
				actor.last_mana_turn = world.turn_count
				actor.secondary_ready = world.turn_count + 5
				add_threat(world, target, actor, 45 + maxi(0, mini(actor.melee.level, 15) - 10) * 2)
				world.add_message("Voidwalker: Torment.")
			for swing in range(actor.swing.advance(distance == 1 and not ClassSpellEffects.immune(actor.buffs), actor.melee.interval)):
				if world.is_terminal() or not target.alive:
					break
				actor.facing = MeleeRules.facing_toward(target.tile - actor.tile)
				var outcome := MeleeRules.outcome(actor.melee, target.melee,
					MeleeRules.is_behind(target.facing, actor.tile - target.tile), world.combat_random.randf() * 100)
				var value := MeleeRules.damage(actor.melee, target.melee, outcome,
					world.combat_random.randf(), world.combat_random.randf())
				SpellEffects.damage(world, target, value, actor.title, world.turn_count, true, actor)
	elif skill.family == &"searing_totem":
		var target := nearest_enemy(world, actor, 4)
		if target != null:
			if actor.ability_ready == 0:
				actor.ability_ready = world.turn_count + 1.2
			if world.turn_count >= actor.ability_ready:
				actor.ability_ready += 2.2
				spell_attack(world, actor, target, 9, 11, 2, "Searing Totem")
		else:
			actor.ability_ready = 0
	elif skill.family == &"stoneclaw_totem" and world.turn_count >= actor.secondary_ready:
		actor.secondary_ready = world.turn_count + 2
		for enemy in world.actors:
			if eligible_enemy(world, actor, enemy, 1):
				enemy.engaged = true
				add_threat(world, enemy, actor, 22)
	elif skill.family == &"earthbind_totem":
		for enemy in world.actors:
			if eligible_enemy(world, actor, enemy, 2):
				enemy.debuffs["earthbind"] = {"until": world.turn_count + 2, "slow": 50}


static func approach(world: GridWorld, actor: GridActor, destination: Vector2i, radius: int) -> void:
	if GridWorld.tile_distance(actor.tile, destination) <= radius and world.has_sight(actor.tile, destination):
		return
	var goals: Array[Vector2i] = []
	for direction in GridWorld.DIRECTIONS:
		if world._terrain_open(destination + direction):
			goals.append(destination + direction)
	world._step_toward(actor, goals, destination)


static func eligible_enemy(world: GridWorld, actor: GridActor, enemy: GridActor, radius: int) -> bool:
	return (enemy.alive and enemy.relationship == GridActor.Relationship.HOSTILE
		and GridWorld.tile_distance(actor.tile, enemy.tile) <= radius
		and world.has_sight(actor.tile, enemy.tile))


static func nearest_enemy(world: GridWorld, actor: GridActor, radius: int) -> GridActor:
	var best: GridActor
	var distance := radius + 1
	for enemy in world.actors:
		var current := GridWorld.tile_distance(actor.tile, enemy.tile)
		if eligible_enemy(world, actor, enemy, radius) and current < distance:
			best = enemy
			distance = current
	return best


static func spell_attack(world: GridWorld, actor: GridActor, target: GridActor,
	minimum: int, maximum: int, school: int, title: String) -> void:
	target.engaged = true
	var difference := target.melee.level - actor.melee.level
	var hit := 96.0 - difference if difference <= 2 else 94.0 - (difference - 2) * 11
	var resistance := SpellResistance.percent(actor.melee.level, target.melee.level,
		int(target.resistances.get(str(school), 0)), false)
	if world.combat_random.randf() * 100 >= clampf(hit - SpellResistance.full_resist_chance(resistance), 1, 99):
		world.add_message("%s -> %s: resisted." % [title, target.title])
		return
	var value := SpellResistance.mitigate(world.combat_random.randi_range(minimum, maximum),
		resistance, world.combat_random.randf())
	SpellEffects.damage(world, target, value, title, world.turn_count, true, actor)


static func refresh_auras(world: GridWorld) -> void:
	world.hero.aura_strength = 0
	world.hero.aura_stamina = 0
	world.hero.aura_armor = 0
	world.hero.aura_reduction = 0
	for actor in world.actors:
		if not actor.alive or actor.summon_kind == "" or (actor.expires_turn > 0 and world.turn_count >= actor.expires_turn):
			continue
		var distance := GridWorld.tile_distance(actor.tile, world.player_tile)
		if actor.npc_id == 416 and actor.melee.level >= 4 and distance <= 6:
			world.hero.aura_stamina = 2 + int((mini(actor.melee.level, 14) - 4) * 0.1)
		if distance <= 4:
			if actor.summon_skill == &"strength_of_earth_totem_1":
				world.hero.aura_strength = 10
			elif actor.summon_skill == &"stoneskin_totem_1":
				world.hero.aura_reduction = 4
	world.hero.refresh_stats()

	var devotion := 0
	for key in world.hero.buffs:
		if String(key).begins_with("devotion_aura"):
			devotion = int(world.hero.buffs[key].armor)
	for ally in world.actors:
		if not ally.alive or ally.summon_kind != "pet":
			continue
		var armor := devotion if GridWorld.tile_distance(ally.tile, world.player_tile) <= 6 else 0
		var strength := 0
		var stamina := 0
		var reduction := 0
		for source in world.actors:
			if not source.alive or source.summon_kind == "" or (source.expires_turn > 0 and world.turn_count >= source.expires_turn):
				continue
			var distance := GridWorld.tile_distance(source.tile, ally.tile)
			if source.npc_id == 416 and source.melee.level >= 4 and distance <= 6:
				stamina = 2 + int((mini(source.melee.level, 14) - 4) * 0.1)
			if distance <= 4:
				if source.summon_skill == &"strength_of_earth_totem_1":
					strength = 10
				elif source.summon_skill == &"stoneskin_totem_1":
					reduction = 4
		ally.aura_armor = armor
		ally.aura_strength = strength
		ally.aura_stamina = stamina
		ally.aura_reduction = reduction
		set_pet_level(ally, ally.melee.level)
