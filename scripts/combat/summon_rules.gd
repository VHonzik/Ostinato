class_name SummonRules
extends RefCounted

## Totems and spirit wolves share actor occupancy and stable saved ordering.
static func slot(skill: SkillDefinition) -> String:
	return "wolf" if skill.family == &"feral_spirit" else "earth"


static func active(world: GridWorld, kind: String) -> GridActor:
	for actor in world.actors:
		if actor.alive and actor.summon_kind == kind:
			return actor
	return null


static func placement(world: GridWorld, skill: SkillDefinition) -> Vector2i:
	var previous := active(world, slot(skill))
	for direction in GridWorld.DIRECTIONS:
		var tile := world.player_tile + direction
		if world.is_open(tile) or (previous != null and previous.tile == tile):
			return tile
	return Vector2i(-1, -1)


static func summon(world: GridWorld, skill: SkillDefinition) -> void:
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
	actor.max_health = 5
	actor.health = actor.max_health
	actor.expires_turn = world.turn_count + 1 + skill.duration
	world.actors.append(actor)
	refresh_auras(world)
	world.add_message("%s summoned." % actor.title)


static func remove(world: GridWorld, actor: GridActor) -> void:
	actor.alive = false
	actor.health = 0
	actor.engaged = false
	actor.corpse_visible = false
	refresh_auras(world)


static func add_threat(world: GridWorld, target: GridActor, source: GridActor, amount: int) -> void:
	var key := str(-1 if source == null else world.actors.find(source))
	target.threat[key] = int(target.threat.get(key, 0)) + maxi(0, amount)


static func enemy_target(world: GridWorld, actor: GridActor) -> GridActor:
	var best: GridActor
	var score := int(actor.threat.get("-1", 0))
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
	if actor.summon_kind == "wolf":
		ClassToolkitRules.act_wolf(world, actor)


static func approach(world: GridWorld, actor: GridActor, destination: Vector2i, radius: int) -> void:
	if GridWorld.tile_distance(actor.tile, destination) <= radius and world.has_sight(actor.tile, destination):
		return
	var goals: Array[Vector2i] = []
	for direction in GridWorld.DIRECTIONS:
		if world._terrain_open(destination + direction):
			goals.append(destination + direction)
	world._step_toward(actor, goals, destination)


static func refresh_auras(world: GridWorld) -> void:
	world.hero.aura_strength = 0
	for actor in world.actors:
		if (not actor.alive or actor.summon_skill != &"strength_of_earth_totem_1"
			or world.turn_count >= actor.expires_turn):
			continue
		var skill := SkillDefinition.catalog(actor.summon_skill)
		if GridWorld.tile_distance(actor.tile, world.player_tile) <= skill.range_tiles:
			world.hero.aura_strength = floori(skill.minimum * (
				1.5 if ClassToolkitRules.has(world.hero, &"elemental_weapons_1") else 1.0))
	world.hero.refresh_stats()
