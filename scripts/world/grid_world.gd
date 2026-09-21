class_name GridWorld
extends RefCounted

signal message_added(message: String)

## Player-driven movement and combat: FR-007 through FR-027 (milestone subset).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const CHAT_LIMIT: int = 100

var hero: HeroState
var messages: PackedStringArray = []
var bounds: Rect2i
var blocked_tiles: Dictionary[Vector2i, bool] = {}
var sight_blockers: Dictionary[Vector2i, bool] = {}
var pending_melee: GridActor
var combat_random := RandomNumberGenerator.new()
var actors: Array[GridActor] = []
var player_tile: Vector2i
var movement_speed: float = 1.0
var movement_credit: float = 0.0
var turn_count: int = 0
var random := RandomNumberGenerator.new()
var pending_skill: SkillRank
var pending_target: GridActor
var cast_turns: int = 0
var cast_elapsed: int = 0
var global_cooldown_until: int = 0
var periodic_effects: Array[Dictionary] = []
var stalker_schedule: bool = false
var stalker_arrived: bool = false
var class_selected: bool = false
var ever_accepted_quest: bool = false
var hotbar: Array[StringName] = [&"", &"", &"", &"", &""]
var hotbar_locked: bool = false
var resolving_turn: bool = false


func _init(
	map_bounds: Rect2i, spawn: Vector2i, world_seed: int = 1,
	development_build: bool = OS.is_debug_build()
) -> void:
	hero = HeroState.new(development_build)
	bounds = map_bounds
	player_tile = spawn
	random.seed = world_seed
	combat_random.seed = world_seed ^ 15485863


func is_open(tile: Vector2i) -> bool:
	if not bounds.has_point(tile) or blocked_tiles.has(tile) or tile == player_tile:
		return false
	for actor in actors:
		if actor.alive and actor.tile == tile:
			return false
	return true


func move_player(direction: Vector2i) -> bool:
	if is_player_dead() or pending_melee != null or pending_skill != null:
		return false
	if not DIRECTIONS.has(direction) or movement_speed <= 0.0:
		return false
	var occupant := actor_at(player_tile + direction)
	if occupant != null and occupant.relationship == GridActor.Relationship.HOSTILE:
		return request_melee(occupant)
	# Reject before granting time or credit. Only the destination blocks a diagonal.
	if not is_open(player_tile + direction):
		return false
	resolving_turn = true
	movement_credit += movement_speed
	while movement_credit >= 1.0 and is_open(player_tile + direction):
		player_tile += direction
		hero.facing = direction
		movement_credit -= 1.0
		_acquire_hostiles()
	_finish_turn()
	return true


func wait_turn() -> void:
	if not is_player_dead() and pending_melee == null and pending_skill == null:
		_finish_turn()


func cast_skill(identifier: StringName, target: GridActor = null) -> bool:
	if is_player_dead() or pending_melee != null or pending_skill != null:
		return false
	var skill := hero.find_skill(identifier)
	if skill == null:
		add_message("Cannot cast: that rank is not learned.")
		return false
	if hero.mana < skill.mana_cost:
		add_message("Not enough mana for %s: requires %d, have %d." % [
			skill.title, skill.mana_cost, hero.mana])
		return false
	if global_cooldown_until > turn_count or not valid_spell_target(skill, target):
		add_message("Cannot cast: invalid target, range, sight, or cooldown.")
		return false
	pending_skill = skill
	pending_target = target
	cast_elapsed = 0
	cast_turns = maxi(1, ceili(maxf(1.0, skill.cast_seconds) - hero.casting_credit))
	global_cooldown_until = turn_count + 1
	if skill.target == SkillRank.Target.ENEMY:
		target.relationship = GridActor.Relationship.HOSTILE
		target.engaged = true
		target.returning_home = false
	if target != null:
		hero.facing = MeleeRules.facing_toward(target.tile - player_tile)
	continue_cast()
	return true


func continue_cast() -> bool:
	if pending_skill == null or is_player_dead():
		cancel_cast()
		return false
	resolving_turn = true
	cast_elapsed += 1
	if cast_elapsed >= cast_turns:
		var skill := pending_skill
		var target := pending_target
		cancel_cast()
		if hero.mana >= skill.mana_cost and valid_spell_target(skill, target):
			hero.casting_credit += cast_turns - maxf(1.0, skill.cast_seconds)
			hero.mana -= skill.mana_cost
			if skill.mana_cost > 0:
				hero.last_mana_turn = turn_count + 1
			_resolve_skill(skill, target)
		else:
			add_message("Cast failed at completion; no mana spent or credit gained.")
	_finish_turn()
	return true


func cancel_cast() -> void:
	pending_skill = null
	pending_target = null


func valid_spell_target(skill: SkillRank, target: GridActor) -> bool:
	if skill.target in [SkillRank.Target.NONE, SkillRank.Target.SELF]:
		return target == null
	if target == null:
		return skill.target == SkillRank.Target.ALLY
	if not actors.has(target) or not target.alive:
		return false
	if (tile_distance(player_tile, target.tile) > skill.range_tiles
		or not has_sight(player_tile, target.tile)):
		return false
	var friendly := target.relationship == GridActor.Relationship.FRIENDLY
	return friendly if skill.target == SkillRank.Target.ALLY else not friendly


func spell_candidates(skill: SkillRank) -> Array[GridActor]:
	var candidates: Array[GridActor] = []
	for actor in actors:
		if valid_spell_target(skill, actor):
			candidates.append(actor)
	candidates.sort_custom(func(a: GridActor, b: GridActor) -> bool:
		var first := tile_distance(player_tile, a.tile)
		var second := tile_distance(player_tile, b.tile)
		return actors.find(a) < actors.find(b) if first == second else first < second)
	return candidates


func in_combat() -> bool:
	if pending_skill != null and pending_skill.target == SkillRank.Target.ENEMY:
		return true
	if not periodic_effects.is_empty():
		return true
	for actor in actors:
		if actor.alive and actor.engaged:
			return true
	return false


func can_save() -> bool:
	return (not is_player_dead() and not in_combat() and not resolving_turn
		and pending_melee == null and pending_skill == null)


func train(category: StringName, identifier: StringName) -> bool:
	if hero.selected_class != category:
		return false
	for skill in SkillRank.trainer_skills(category):
		if skill.id == identifier and hero.learn_skill(skill):
			add_message("Learned %s rank %d (free starting training)." % [skill.title, skill.rank])
			return true
	return false


func _resolve_skill(skill: SkillRank, target: GridActor) -> void:
	match skill.effect:
		SkillRank.Effect.PRACTICE:
			add_message("Practice rank %d: cast complete (1 turn, 0 mana)." % skill.rank)
		SkillRank.Effect.EXPERIENCE:
			add_message("Gain 450 XP rank %d: gained 450 XP." % skill.rank)
			for gained_level in hero.add_experience(450):
				add_message("Level up! You are now level %d. Health and mana restored." % gained_level)
		SkillRank.Effect.DEATH_NOTICE:
			hero.health = 0
			add_message("Death trigger invoked. You died.")
		SkillRank.Effect.DAMAGE:
			var difference := target.melee.level - hero.level
			var hit_chance := 96.0 - difference if difference <= 2 else 94.0 - (difference - 2) * 11
			if combat_random.randf() * 100.0 >= clampf(hit_chance, 1.0, 99.0):
				add_message("%s -> %s: resisted." % [skill.title, target.title])
				return
			var amount := _spell_amount(skill)
			target.health = maxi(0, target.health - amount)
			add_message("%s -> %s: %d damage." % [skill.title, target.title, amount])
			_check_npc_death(target)
			if target.alive and skill.periodic_damage > 0:
				for index in range(periodic_effects.size() - 1, -1, -1):
					if periodic_effects[index].actor == actors.find(target):
						periodic_effects.remove_at(index)
				periodic_effects.append({"actor": actors.find(target),
					"next": turn_count + 3, "remaining": 2})
		SkillRank.Effect.HEAL:
			var amount := _spell_amount(skill)
			if target == null:
				hero.health = mini(hero.max_health, hero.health + amount)
			else:
				target.health = mini(target.max_health, target.health + amount)
			add_message("%s -> %s: %d healing." % [
				skill.title, "You" if target == null else target.title, amount])
		SkillRank.Effect.ARMOR:
			var buffs := hero.buffs if target == null else target.buffs
			if target != null and buffs.has(skill.id):
				target.melee.armor -= int(buffs[skill.id].armor)
			buffs[skill.id] = {"armor": skill.minimum, "until": turn_count + 1 + skill.duration}
			if target == null:
				hero.refresh_melee_stats()
			else:
				target.melee.armor += skill.minimum
			add_message("%s -> %s: +%d armor." % [
				skill.title, "You" if target == null else target.title, skill.minimum])


func _spell_amount(skill: SkillRank) -> int:
	# Base level-one rank data; innate rank scaling stops at the next rank's level.
	var rate := 0.4 if skill.id == &"wrath_1" else (0.8 if skill.effect == SkillRank.Effect.HEAL else 0.6)
	var scaling := clampi(hero.level - 1, 0, 4) * rate
	var amount := combat_random.randi_range(skill.minimum, skill.maximum) + int(scaling)
	var critical := 3.7 + hero.intellect / (14.77 + 0.65 * mini(hero.level, 60))
	if combat_random.randf() * 100.0 < critical:
		amount = int(amount * 1.5)
	return amount


func add_message(message: String) -> void:
	messages.append(message)
	if messages.size() > CHAT_LIMIT:
		messages.remove_at(0)
	message_added.emit(message)


func is_player_dead() -> bool:
	return hero.health <= 0


func actor_at(tile: Vector2i) -> GridActor:
	for actor in actors:
		if actor.alive and actor.tile == tile:
			return actor
	return null


static func tile_distance(first: Vector2i, second: Vector2i) -> int:
	var difference := (first - second).abs()
	return maxi(difference.x, difference.y)


func has_sight(start: Vector2i, end: Vector2i) -> bool:
	# Open rectangle intersection: merely touching a corner does not obstruct sight.
	var origin := Vector2(start) + Vector2.ONE * 0.5
	var offset := Vector2(end - start)
	for tile in sight_blockers:
		var entry := 0.0
		var leave := 1.0
		for axis in range(2):
			if is_zero_approx(offset[axis]):
				if origin[axis] <= tile[axis] or origin[axis] >= tile[axis] + 1:
					leave = -1.0
					break
			else:
				var first := (tile[axis] - origin[axis]) / offset[axis]
				var second := (tile[axis] + 1 - origin[axis]) / offset[axis]
				entry = maxf(entry, minf(first, second))
				leave = minf(leave, maxf(first, second))
		if entry < leave - 0.000001:
			return false
	return true


func interaction_candidates() -> Array[GridActor]:
	var candidates: Array[GridActor] = []
	for actor in actors:
		var distance := tile_distance(player_tile, actor.tile)
		if distance <= 1 and (actor.alive or actor.corpse_visible):
			candidates.append(actor)
	# Stable array identity breaks equal-distance ties.
	candidates.sort_custom(func(a: GridActor, b: GridActor) -> bool:
		var first := tile_distance(player_tile, a.tile)
		var second := tile_distance(player_tile, b.tile)
		return actors.find(a) < actors.find(b) if first == second else first < second
	)
	return candidates


func interact(actor: GridActor) -> String:
	if is_player_dead() or not interaction_candidates().has(actor):
		return "That target is no longer available."
	if not actor.alive:
		return "%s: no loot in this combat fixture. Loot arrives in milestone 5." % actor.title
	if actor.relationship == GridActor.Relationship.FRIENDLY:
		return "%s: Welcome to the training grounds. Wolves roam to the east. Stay alert!" % actor.title
	request_melee(actor)
	return ""


func request_melee(target: GridActor) -> bool:
	if is_player_dead() or pending_melee != null or pending_skill != null or not _valid_melee(target):
		return false
	target.relationship = GridActor.Relationship.HOSTILE
	target.engaged = true
	target.returning_home = false
	hero.facing = MeleeRules.facing_toward(target.tile - player_tile)
	pending_melee = target
	continue_melee()
	return true


func continue_melee() -> bool:
	if is_player_dead() or not _valid_melee(pending_melee):
		pending_melee = null
		return false
	resolving_turn = true
	var target := pending_melee
	var swings := hero.swing.advance(true, hero.melee.interval)
	for index in range(swings):
		if not _valid_melee(target) or is_player_dead():
			break
		_player_swing(target)
	if swings > 0:
		pending_melee = null
	_finish_turn(true)
	if is_player_dead() or not _valid_melee(pending_melee):
		pending_melee = null
	return true


func cancel_melee() -> void:
	pending_melee = null


func _valid_melee(target: GridActor) -> bool:
	return (target != null and actors.has(target) and target.alive
		and target.relationship != GridActor.Relationship.FRIENDLY
		and tile_distance(player_tile, target.tile) == 1
		and has_sight(player_tile, target.tile))


func _finish_turn(player_timer_advanced: bool = false) -> void:
	# Terminal player effects consume their turn but discard its remaining stages.
	turn_count += 1
	resolving_turn = true
	if is_player_dead():
		pending_melee = null
		cancel_cast()
		resolving_turn = false
		return
	if not player_timer_advanced:
		hero.swing.advance(false, hero.melee.interval)
	_acquire_hostiles()
	for actor in actors:
		if not actor.alive:
			continue
		_act_npc(actor)
		if is_player_dead():
			pending_melee = null
			cancel_cast()
			resolving_turn = false
			return
	_tick_effects()
	_regenerate()
	_arrive_stalker()
	resolving_turn = false
	for actor in actors:
		if not actor.alive and not actor.story_guard and actor.died_on_turn >= 0:
			if turn_count - actor.died_on_turn >= 300:
				actor.corpse_visible = false


func _acquire_hostiles() -> void:
	for actor in actors:
		if (actor.alive and actor.relationship == GridActor.Relationship.HOSTILE
			and not actor.returning_home and not actor.engaged
			and tile_distance(actor.tile, player_tile) <= actor.aggro_range
			and has_sight(actor.tile, player_tile)):
			actor.engaged = true
			add_message("%s engages you." % actor.title)


func _act_npc(actor: GridActor) -> void:
	if actor.returning_home:
		if not _route(actor.tile, [actor.home_tile], false, actor.home_tile).is_empty():
			_step_toward(actor, [actor.home_tile], actor.home_tile)
		if actor.tile == actor.home_tile:
			actor.returning_home = false
			actor.health = actor.max_health
			actor.blocked_turns = 0
	elif actor.engaged:
		var goals: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var tile := player_tile + direction
			if _terrain_open(tile) and has_sight(tile, player_tile):
				goals.append(tile)
		var static_path := _route(actor.tile, goals, false, player_tile)
		if static_path.is_empty():
			actor.blocked_turns += 1
			if actor.blocked_turns >= 5:
				actor.engaged = false
				actor.returning_home = true
				add_message("%s cannot reach you and returns home." % actor.title)
		else:
			actor.blocked_turns = 0
			_step_toward(actor, goals, player_tile, static_path)
	else:
		_wander(actor)
	var in_melee := (actor.engaged and tile_distance(actor.tile, player_tile) == 1
		and has_sight(actor.tile, player_tile))
	var interval := actor.melee.interval * (1.25 if actor.chilled_until > turn_count else 1.0)
	var swings := actor.swing.advance(in_melee, interval)
	for index in range(swings):
		if is_player_dead():
			return
		actor.facing = MeleeRules.facing_toward(player_tile - actor.tile)
		var result := MeleeRules.outcome(actor.melee, hero.melee,
			MeleeRules.is_behind(hero.facing, actor.tile - player_tile),
			combat_random.randf() * 100.0)
		var amount := MeleeRules.damage(actor.melee, hero.melee, result,
			combat_random.randf(), combat_random.randf())
		hero.health = maxi(0, hero.health - amount)
		if amount > 0 and hero.buffs.has(&"frost_armor_1"):
			actor.chilled_until = turn_count + 5
		add_message("%s -> You: %s, %d damage." % [actor.title, result, amount])
		if is_player_dead():
			add_message("You died.")


func _player_swing(target: GridActor) -> void:
	var result := MeleeRules.outcome(hero.melee, target.melee,
		MeleeRules.is_behind(target.facing, player_tile - target.tile),
		combat_random.randf() * 100.0)
	var amount := MeleeRules.damage(hero.melee, target.melee, result,
		combat_random.randf(), combat_random.randf())
	target.health = maxi(0, target.health - amount)
	add_message("You -> %s: %s, %d damage." % [target.title, result, amount])
	_check_npc_death(target)


func _check_npc_death(target: GridActor, death_turn: int = -1) -> void:
	if target.health == 0 and target.alive:
		target.alive = false
		target.engaged = false
		target.returning_home = false
		target.died_on_turn = turn_count + 1 if death_turn == -1 else death_turn
		var xp := MeleeRules.kill_experience(hero.level, target.melee.level)
		if not target.awards_experience:
			xp = 0
		add_message("%s dies. Gained %d XP." % [target.title, xp])
		for gained_level in hero.add_experience(xp):
			add_message("Level up! You are now level %d. Health and mana restored." % gained_level)


func _wander(actor: GridActor) -> void:
	if not actor.wander_area.has_area():
		return
	var candidates: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var destination := actor.tile + direction
		if actor.wander_area.has_point(destination) and is_open(destination):
			candidates.append(destination)
	if not candidates.is_empty():
		_move_actor(actor, candidates[random.randi_range(0, candidates.size() - 1)])


func _terrain_open(tile: Vector2i) -> bool:
	return bounds.has_point(tile) and not blocked_tiles.has(tile) and tile != player_tile


func _step_toward(
	actor: GridActor, goals: Array[Vector2i], toward: Vector2i,
	terrain_route: Array[Vector2i] = []
) -> void:
	var route := terrain_route
	if route.is_empty():
		route = _route(actor.tile, goals, false, toward)
	if route.size() <= 1:
		return
	# Follow the terrain route until its next step is physically occupied.
	if not is_open(route[1]):
		route = _route(actor.tile, goals, true, toward)
	if route.size() > 1:
		actor.movement_credit += 0.7 if actor.chilled_until > turn_count else 1.0
		if actor.movement_credit >= 1.0:
			actor.movement_credit -= 1.0
			_move_actor(actor, route[1])


func _move_actor(actor: GridActor, tile: Vector2i) -> void:
	actor.facing = MeleeRules.facing_toward(tile - actor.tile)
	actor.tile = tile


func _route(
	start: Vector2i, goals: Array[Vector2i], avoid_actors: bool, toward: Vector2i
) -> Array[Vector2i]:
	# Breadth-first search separates static failure from temporary actor congestion.
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary[Vector2i, Vector2i] = {start: start}
	var cursor := 0
	var best := start
	var best_distance := _distance_to_goals(start, goals)
	var reached := false
	while cursor < queue.size():
		var tile := queue[cursor]
		cursor += 1
		if goals.has(tile):
			best = tile
			reached = true
			break
		var distance := _distance_to_goals(tile, goals)
		if distance < best_distance:
			best = tile
			best_distance = distance
		var directions: Array[Vector2i] = DIRECTIONS.duplicate()
		directions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var first := (tile + a - toward).length_squared()
			var second := (tile + b - toward).length_squared()
			return DIRECTIONS.find(a) < DIRECTIONS.find(b) if first == second else first < second
		)
		for direction in directions:
			var next := tile + direction
			if parents.has(next) or not _terrain_open(next):
				continue
			if avoid_actors and not is_open(next):
				continue
			parents[next] = tile
			queue.append(next)
	if not reached and not avoid_actors:
		return []
	var route: Array[Vector2i] = [best]
	while route[-1] != start:
		route.append(parents[route[-1]])
	route.reverse()
	return route


func _distance_to_goals(tile: Vector2i, goals: Array[Vector2i]) -> int:
	var distance := 2147483647
	for goal in goals:
		distance = mini(distance, tile_distance(tile, goal))
	return distance


func _tick_effects() -> void:
	for effect in periodic_effects.duplicate():
		var actor := actors[int(effect.actor)]
		if not actor.alive:
			periodic_effects.erase(effect)
			continue
		if turn_count >= int(effect.next):
			actor.health = maxi(0, actor.health - 1)
			add_message("Fireball -> %s: 1 periodic damage." % actor.title)
			_check_npc_death(actor, turn_count)
			effect.remaining -= 1
			effect.next += 2
			if effect.remaining == 0 or not actor.alive:
				periodic_effects.erase(effect)
	for key in hero.buffs.keys():
		if int(hero.buffs[key].until) <= turn_count:
			hero.buffs.erase(key)
			hero.refresh_melee_stats()
	for actor in actors:
		for key in actor.buffs.keys():
			if int(actor.buffs[key].until) <= turn_count:
				actor.melee.armor -= int(actor.buffs[key].armor)
				actor.buffs.erase(key)


func _regenerate() -> void:
	if turn_count % 2 != 0:
		return
	if not in_combat():
		hero.health = mini(hero.max_health, hero.health + int((hero.spirit * 0.11 + 1) * 2))
	if turn_count - hero.last_mana_turn >= 5:
		hero.mana = mini(hero.max_mana, hero.mana + int(hero.spirit / 4.0 + 12.5))


func _arrive_stalker() -> void:
	if not stalker_schedule or stalker_arrived or turn_count < 15:
		return
	var entry := Vector2i(54, 14)
	if not is_open(entry):
		return
	var stalker := GridActor.new(entry)
	stalker.title = "Demon stalker"
	stalker.stalker = true
	stalker.relationship = GridActor.Relationship.HOSTILE
	# Ordinary level-20 Wildthorn Stalker profile, DATA-002 M4 adaptation.
	stalker.max_health = 494
	stalker.health = 494
	stalker.melee.level = 20
	stalker.melee.armor = 888
	stalker.melee.damage_min = 31.0
	stalker.melee.damage_max = 38.0
	stalker.melee.attack_power = 16
	actors.append(stalker)
	stalker_arrived = true
	for actor in actors:
		if actor.story_guard:
			actor.health = 0
			actor.alive = false
			actor.engaged = false
			actor.died_on_turn = turn_count
	add_message("A demon stalker enters the gate, kills the guard, and begins to feast!")
	_acquire_hostiles()
