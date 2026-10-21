class_name SummonRules
extends RefCounted

## Elemental and spirit wolves share actor occupancy and stable saved ordering.
static func slot(skill: SkillDefinition) -> String:
	return "wolf" if skill.family == &"feral_spirit" else "earth_elemental"


static func definition(actor: GridActor) -> SkillDefinition:
	if actor.summon_skill == ItemData.ANCESTRAL_TOTEM_HOTBAR_ID:
		return ItemData.ancestral_totem_action()
	return SkillDefinition.catalog(actor.summon_skill)


static func active(world: GridWorld, kind: String) -> GridActor:
	for actor in world.actors:
		if actor.alive and actor.summon_kind == kind:
			return actor
	return null


static func placement(world: GridWorld, _skill: SkillDefinition) -> Vector2i:
	for direction in GridWorld.DIRECTIONS:
		var tile := world.player_tile + direction
		if world.is_open(tile):
			return tile
	return Vector2i(-1, -1)


static func summon(world: GridWorld, skill: SkillDefinition) -> void:
	var tile := placement(world, skill)
	if tile == Vector2i(-1, -1):
		return
	var actor := GridActor.new(tile)
	actor.summon_kind = slot(skill)
	actor.summon_skill = skill.id
	actor.title = skill.title.trim_prefix("Summon ")
	if skill.id == ItemData.ANCESTRAL_TOTEM_HOTBAR_ID:
		actor.title = ItemData.get_item(ItemData.ANCESTRAL_TOTEM_ID).summon_title
	actor.spawn_id = "summon/%d" % world.actors.size()
	actor.awards_experience = false
	actor.corpse_visible = false
	actor.melee.level = world.hero.level
	actor.creature_type = "elemental"
	actor.max_health = skill.minimum
	actor.health = actor.max_health
	actor.melee.damage_min = ItemData.ELEMENTAL_DAMAGE_MIN
	actor.melee.damage_max = ItemData.ELEMENTAL_DAMAGE_MAX
	actor.melee.interval = ItemData.ELEMENTAL_SWING_TURNS
	actor.melee.critical = 0.0
	actor.melee.dodge = 0.0
	# Zero means no expiration; the elemental remains until killed or Loop reset.
	actor.expires_turn = 0
	world.actors.append(actor)
	world.add_message("%s summoned." % actor.title)


static func remove(world: GridWorld, actor: GridActor) -> void:
	actor.alive = false
	actor.health = 0
	actor.engaged = false
	actor.corpse_visible = false


static func add_threat(world: GridWorld, target: GridActor, source: GridActor, amount: int) -> void:
	var key := str(-1 if source == null else world.actors.find(source))
	target.threat[key] = int(target.threat.get(key, 0)) + maxi(0, amount)


static func enemy_target(world: GridWorld, actor: GridActor) -> GridActor:
	var elemental := active(world, "earth_elemental")
	if (elemental != null and actor.engaged
		and actor.relationship == GridActor.Relationship.HOSTILE):
		var skill := definition(elemental)
		if (GridWorld.tile_distance(elemental.tile, actor.tile) <= skill.range_tiles
			and world.has_sight(elemental.tile, actor.tile)):
			return elemental
	var best: GridActor
	# Concealment removes the hero from selection, without clearing stored threat.
	var score := -1 if VanishRules.active(world) else int(actor.threat.get("-1", 0))
	for index in range(world.actors.size()):
		var candidate := world.actors[index]
		var threat := int(actor.threat.get(str(index), 0))
		if candidate.alive and candidate.summon_kind != "" and threat > score:
			best = candidate
			score = threat
	return best


static func act(world: GridWorld, actor: GridActor) -> void:
	if world.is_terminal():
		return
	if actor.expires_turn > 0 and world.turn_count >= actor.expires_turn:
		remove(world, actor)
		return
	if actor.summon_kind == "wolf":
		ClassToolkitRules.act_wolf(world, actor)
	elif actor.summon_kind == "earth_elemental":
		_act_elemental(world, actor)


static func approach(world: GridWorld, actor: GridActor, destination: Vector2i, radius: int) -> void:
	if GridWorld.tile_distance(actor.tile, destination) <= radius and world.has_sight(actor.tile, destination):
		return
	var goals: Array[Vector2i] = []
	for direction in GridWorld.DIRECTIONS:
		if world._terrain_open(destination + direction):
			goals.append(destination + direction)
	world._step_toward(actor, goals, destination)


static func _act_elemental(world: GridWorld, elemental: GridActor) -> void:
	var target := world.auto_attack_target
	if (target == null or not target.alive or not target.engaged
		or target.relationship != GridActor.Relationship.HOSTILE):
		target = null
		for enemy in world.actors:
			if (enemy.alive and enemy.engaged
				and enemy.relationship == GridActor.Relationship.HOSTILE
				and enemy_target(world, enemy) == elemental):
				target = enemy
				break
	if target == null:
		approach(world, elemental, world.player_tile, 1)
		elemental.swing.advance(false, elemental.melee.interval)
		return
	approach(world, elemental, target.tile, 1)
	var ready := (GridWorld.tile_distance(elemental.tile, target.tile) == 1
		and world.has_sight(elemental.tile, target.tile))
	for index in range(elemental.swing.advance(ready, elemental.melee.interval)):
		if world.is_terminal() or not target.alive:
			break
		var result := MeleeRules.outcome(elemental.melee, target.melee,
			world.combat_random.randf() * 100.0)
		var value := MeleeRules.damage(elemental.melee, target.melee, result,
			world.combat_random.randf())
		SpellEffects.damage(world, target, value, elemental.title, world.turn_count,
			elemental, true, result)
