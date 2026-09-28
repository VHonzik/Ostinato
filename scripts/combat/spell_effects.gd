class_name SpellEffects
extends RefCounted

## Current mage/druid effects, isolated from input and cast pacing (DATA-002/003 M5).
static func amount(world: GridWorld, skill: SkillRank, critical: bool = true) -> int:
	var scaling := maxi(0, mini(world.hero.level, skill.scaling_max) - skill.training_level)
	var value := world.combat_random.randi_range(skill.minimum, skill.maximum)
	value += int(scaling * skill.scaling_rate)
	var power := world.hero.healing_power if skill.effect == SkillRank.Effect.HEAL else world.hero.spell_power
	value += int(power * skill.coefficient)
	var chance := world.hero.spell_critical + 3.7 + world.hero.intellect / (
		14.77 + 0.65 * mini(world.hero.level, 60))
	if critical and world.combat_random.randf() * 100.0 < chance:
		value = int(value * 1.5)
	return value


static func resolve(world: GridWorld, skill: SkillRank, target: GridActor) -> void:
	if skill.effect == SkillRank.Effect.NOVA:
		for actor in world.actors:
			if (actor.alive and actor.relationship != GridActor.Relationship.FRIENDLY
				and GridWorld.tile_distance(world.player_tile, actor.tile) <= skill.range_tiles
				and world.has_sight(world.player_tile, actor.tile)):
				actor.relationship = GridActor.Relationship.HOSTILE
				actor.engaged = true
				if _hits(world, skill, actor):
					var value := SpellResistance.mitigate(amount(world, skill),
						resistance(world, skill, actor), world.combat_random.randf())
					damage(world, actor, value, skill.title)
					if actor.alive:
						actor.rooted_until = world.turn_count + 1 + skill.duration
						actor.root_skill = skill.id
		return
	if skill.target == SkillRank.Target.ENEMY and not _hits(world, skill, target):
		return
	match skill.effect:
		SkillRank.Effect.DAMAGE, SkillRank.Effect.CHANNEL:
			var value := amount(world, skill)
			if skill.family != &"frostbolt":
				value = SpellResistance.mitigate(value, resistance(world, skill, target),
					world.combat_random.randf())
			damage(world, target, value, skill.title)
			if target.alive:
				if skill.family == &"frostbolt":
					target.slowed_until = world.turn_count + 1 + skill.duration
				_periodic(world, skill, target)
		SkillRank.Effect.HEAL:
			var value := amount(world, skill)
			heal(world, target, value, skill.title)
		SkillRank.Effect.HEAL_OVER_TIME:
			_periodic(world, skill, target)
			world.add_message("%s applied." % skill.title)
		SkillRank.Effect.ROOT:
			for actor in world.actors:
				if actor.root_skill == skill.id:
					actor.rooted_until = 0
			for effect in world.periodic_effects.duplicate():
				if effect.get("skill", "") == String(skill.id):
					world.periodic_effects.erase(effect)
			target.rooted_until = world.turn_count + 1 + skill.duration
			target.root_skill = skill.id
			_periodic(world, skill, target)
			world.add_message("%s rooted." % target.title)
		SkillRank.Effect.POLYMORPH:
			for actor in world.actors:
				actor.polymorphed_until = 0
			target.polymorphed_until = world.turn_count + 1 + skill.duration
			target.polymorphed_on_turn = world.turn_count + 1
			world.add_message("%s becomes a sheep." % target.title)
		SkillRank.Effect.ARMOR:
			_buff(world, skill, target)
		SkillRank.Effect.CONJURE:
			var quantity := conjured_quantity(world, skill)
			InventoryRules.add(world.hero.inventory, ItemData.instance(skill.item_id, quantity))
			world.add_message("Conjured %s x%d." % [ItemData.get_item(skill.item_id).title, quantity])


static func conjured_quantity(world: GridWorld, skill: SkillRank) -> int:
	return clampi(2 + 2 * (world.hero.level - skill.training_level), 2, 20)


static func can_apply(world: GridWorld, skill: SkillRank, target: GridActor) -> bool:
	if skill.effect == SkillRank.Effect.CONJURE:
		var trial := world.hero.inventory.duplicate(true)
		return InventoryRules.add(trial, ItemData.instance(skill.item_id, conjured_quantity(world, skill)))
	if skill.effect == SkillRank.Effect.ROOT and world.indoor_tiles.has(world.player_tile):
		return false
	if skill.effect == SkillRank.Effect.POLYMORPH and target != null:
		return target.creature_type in ["beast", "humanoid", "critter"]
	if skill.effect == SkillRank.Effect.HEAL_OVER_TIME:
		var identity := -1 if target == null else world.actors.find(target)
		for effect in world.periodic_effects:
			var previous := SkillRank.catalog(StringName(effect.get("skill", "fireball_1")))
			if (int(effect.actor) == identity and previous.family == skill.family
				and previous.rank > skill.rank):
				return false
	if skill.effect == SkillRank.Effect.ARMOR:
		var buffs := world.hero.buffs if target == null else target.buffs
		for key in buffs:
			var existing := SkillRank.catalog(StringName(key))
			if existing != null and existing.family == skill.family and existing.rank > skill.rank:
				return false
	return true


static func _hits(world: GridWorld, skill: SkillRank, target: GridActor) -> bool:
	var difference := target.melee.level - world.hero.level
	var chance := 96.0 - difference if difference <= 2 else 94.0 - (difference - 2) * 11
	chance += world.hero.spell_hit
	var percent := resistance(world, skill, target)
	if skill.effect in [SkillRank.Effect.ROOT, SkillRank.Effect.POLYMORPH] or skill.family == &"frostbolt":
		chance -= percent
	else:
		chance -= SpellResistance.full_resist_chance(percent)
	if world.combat_random.randf() * 100.0 >= clampf(chance, 1.0, 99.0):
		world.add_message("%s -> %s: resisted." % [skill.title, target.title])
		return false
	return true


static func resistance(world: GridWorld, skill: SkillRank, target: GridActor) -> float:
	var value := int(target.resistances.get(str(skill.school), 0))
	var binary := skill.effect in [SkillRank.Effect.ROOT, SkillRank.Effect.POLYMORPH] or skill.family == &"frostbolt"
	return SpellResistance.percent(world.hero.level, target.melee.level, value, binary)


static func damage(
	world: GridWorld, target: GridActor, value: int, title: String,
	death_turn: int = -1, break_root: bool = true
) -> void:
	target.health = maxi(0, target.health - value)
	if value > 0:
		target.polymorphed_until = 0
		var threshold := 50 if target.melee.level <= 8 else 25 * target.melee.level - 150
		if (break_root and target.rooted_until > world.turn_count
			and world.combat_random.randf() < float(value) / threshold):
			target.rooted_until = 0
	if title.begins_with("You ("):
		world.add_message("You -> %s: %s, %d damage." % [target.title,
			title.trim_prefix("You (").trim_suffix(")"), value])
	else:
		world.add_message("%s -> %s: %d damage." % [title, target.title, value])
	world._check_npc_death(target, death_turn)


static func heal(world: GridWorld, target: GridActor, value: int, title: String) -> void:
	if target == null:
		world.hero.health = mini(world.hero.max_health, world.hero.health + value)
	else:
		target.health = mini(target.max_health, target.health + value)
	world.add_message("%s -> %s: %d healing." % [title, "You" if target == null else target.title, value])


static func _periodic(world: GridWorld, skill: SkillRank, target: GridActor) -> void:
	if skill.periodic_damage <= 0:
		return
	var identity := -1 if target == null else world.actors.find(target)
	for effect in world.periodic_effects.duplicate():
		var previous := SkillRank.catalog(StringName(effect.get("skill", "fireball_1")))
		if int(effect.actor) == identity and previous.family == skill.family:
			world.periodic_effects.erase(effect)
	var healing := skill.effect == SkillRank.Effect.HEAL_OVER_TIME
	var power := world.hero.healing_power if healing else world.hero.spell_power
	world.periodic_effects.append({"actor": identity, "skill": String(skill.id),
		"next": world.turn_count + 1 + skill.tick_seconds,
		"remaining": floori(float(skill.duration) / skill.tick_seconds),
		"amount": skill.periodic_damage + int(power * skill.tick_coefficient)})


static func _buff(world: GridWorld, skill: SkillRank, target: GridActor) -> void:
	var buffs := world.hero.buffs if target == null else target.buffs
	for key in buffs.keys():
		if SkillRank.catalog(StringName(key)).family == skill.family:
			if target != null:
				target.melee.armor -= int(buffs[key].get("armor", 0))
			buffs.erase(key)
	var buff := {"armor": 0, "until": world.turn_count + 1 + skill.duration}
	if skill.family == &"intellect":
		buff["intellect"] = skill.minimum
	elif skill.family == &"thorns":
		buff["thorns"] = skill.minimum
	else:
		buff.armor = skill.minimum
		if skill.id == &"mark_2":
			for stat in ["strength", "agility", "stamina", "intellect", "spirit"]:
				buff[stat] = 2
	buffs[skill.id] = buff
	if target == null:
		world.hero.refresh_stats()
	else:
		target.melee.armor += int(buff.armor)
	world.add_message("%s rank %d applied to %s." % [
		skill.title, skill.rank, "You" if target == null else target.title])


static func tick(world: GridWorld) -> void:
	for effect in world.periodic_effects.duplicate():
		var actor: GridActor = null if int(effect.actor) == -1 else world.actors[int(effect.actor)]
		var skill := SkillRank.catalog(StringName(effect.get("skill", "fireball_1")))
		if actor != null and (not actor.alive or (
			skill.effect == SkillRank.Effect.ROOT and actor.rooted_until < world.turn_count)):
			world.periodic_effects.erase(effect)
			continue
		if world.turn_count >= int(effect.next):
			var value := int(effect.get("amount", 1))
			if skill.effect == SkillRank.Effect.HEAL_OVER_TIME:
				heal(world, actor, value, skill.title)
			else:
				var percent := resistance(world, skill, actor)
				if skill.effect == SkillRank.Effect.ROOT:
					percent *= 0.1
				value = SpellResistance.mitigate(value, percent, world.combat_random.randf())
				damage(world, actor, value, skill.title, world.turn_count, false)
			effect.remaining -= 1
			effect.next += skill.tick_seconds
			if effect.remaining == 0 or (actor != null and not actor.alive):
				world.periodic_effects.erase(effect)
