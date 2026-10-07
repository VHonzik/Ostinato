class_name GridWorld
extends RefCounted

signal message_added(message: String)

enum AttemptState { ACTIVE, PLAYER_DIED, COMPLETED, DISCARDED }

## Player-driven movement and combat: FR-007 through FR-027 (milestone subset).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const CHAT_LIMIT: int = 100
const STALKER_DEADLINES: Array[int] = [15, 215, 395, 555, 695]
const STALKER_ENTRIES: Array[Vector2i] = [
	Vector2i(54, 14), Vector2i(54, 13), Vector2i(54, 15),
	Vector2i(53, 13), Vector2i(53, 15),
]

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
var cast_duration: float = 1.0
var global_cooldown_until: int = 0
var periodic_effects: Array[Dictionary] = []
var stalker_schedule: bool = false
var stalkers_arrived: int = 0
var stalker_deadlines: Array[int] = STALKER_DEADLINES.duplicate()
var class_selected: bool = false
var ever_accepted_quest: bool = false
var hotbar: Array[StringName] = [&"", &"", &"", &"", &""]
var hotbar_locked: bool = false
var resolving_turn: bool = false
var attempt_state: AttemptState = AttemptState.ACTIVE
var seed_value: int = 1
var loot_quests: Array[String] = []
var quests: Dictionary = {}
var population: Array[Dictionary] = []
var northshire: bool = false
var vendor_stock: Dictionary = {"2139": -1, "2129": -1, "85": -1, "117": -1,
	"159": -1, "2455": 3}
var indoor_tiles: Dictionary[Vector2i, bool] = {}


func _init(
	map_bounds: Rect2i, spawn: Vector2i, world_seed: int = 1,
	development_build: bool = OS.is_debug_build()
) -> void:
	seed_value = world_seed
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
	if is_terminal() or pending_melee != null or pending_skill != null:
		return false
	if not DIRECTIONS.has(direction) or movement_speed <= 0.0:
		return false
	var occupant := actor_at(player_tile + direction)
	if occupant != null and occupant.relationship == GridActor.Relationship.HOSTILE:
		return request_melee(occupant)
	# Reject before granting time or credit. Only the destination blocks a diagonal.
	if not is_open(player_tile + direction):
		return false
	hero.restoration.clear()
	resolving_turn = true
	movement_credit += movement_speed
	while movement_credit >= 1.0 and is_open(player_tile + direction):
		player_tile += direction
		QuestRules.visit(self)
		hero.facing = direction
		movement_credit -= 1.0
		_acquire_hostiles()
	_finish_turn()
	return true


func wait_turn() -> void:
	if not is_terminal() and pending_melee == null and pending_skill == null:
		_finish_turn()


func cast_skill(identifier: StringName, target: GridActor = null) -> bool:
	if is_terminal() or pending_melee != null or pending_skill != null:
		return false
	var skill := hero.find_skill(identifier)
	if skill == null:
		add_message("Cannot cast: that rank is not learned.")
		return false
	if skill.effect == SkillRank.Effect.KILL_STALKER and _first_living_stalker() == null:
		add_message("Kill stalker: no living stalker has arrived. No turn spent.")
		return false
	if skill.effect == SkillRank.Effect.PET_COMMAND:
		return SummonRules.command(self, identifier, target)
	if hero.mana < skill.cost(hero):
		add_message("Not enough mana for %s: requires %d, have %d." % [
			skill.title, skill.cost(hero), hero.mana])
		return false
	if ((not skill.free_instant and global_cooldown_until > turn_count)
		or int(hero.cooldowns.get(String(cooldown_family(skill)), 0)) > turn_count
		or not valid_spell_target(skill, target) or not SpellEffects.can_apply(self, skill, target)):
		add_message("Cannot cast: invalid target, range, sight, or cooldown.")
		return false
	if skill.free_instant:
		hero.mana -= skill.cost(hero)
		if skill.cost(hero) > 0:
			hero.last_mana_turn = turn_count
		hero.cooldowns[String(cooldown_family(skill))] = turn_count + skill.cooldown_seconds
		if target != null:
			target.relationship = GridActor.Relationship.HOSTILE
			target.engaged = true
			target.returning_home = false
			hero.facing = MeleeRules.facing_toward(target.tile - player_tile)
		_resolve_skill(skill, target)
		return true
	hero.restoration.clear()
	pending_skill = skill
	pending_target = target
	cast_elapsed = 0
	cast_duration = maxf(1.0, skill.cast_seconds / hero.haste)
	cast_turns = maxi(1, ceili(cast_duration - hero.casting_credit))
	if skill.effect == SkillRank.Effect.CHANNEL:
		cast_turns = skill.duration
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
	if pending_skill == null or is_terminal():
		cancel_cast()
		return false
	resolving_turn = true
	cast_elapsed += 1
	if pending_skill.effect == SkillRank.Effect.CHANNEL:
		var channel := pending_skill
		var target := pending_target
		if not valid_spell_target(channel, target) or (cast_elapsed == 1 and hero.mana < channel.cost(hero)):
			cancel_cast()
			add_message("Channel interrupted; delivered ticks and costs remain.")
		else:
			if cast_elapsed == 1:
				hero.mana -= channel.cost(hero)
				hero.last_mana_turn = turn_count + 1
			if cast_elapsed % maxi(1, channel.tick_seconds) == 0:
				SpellEffects.resolve(self, channel, target)
			if cast_elapsed >= cast_turns or not target.alive:
				cancel_cast()
		_finish_turn()
		return true
	if cast_elapsed >= cast_turns:
		var skill := pending_skill
		var target := pending_target
		cancel_cast()
		if (hero.mana >= skill.cost(hero) and valid_spell_target(skill, target)
			and SpellEffects.can_apply(self, skill, target)):
			hero.casting_credit += cast_turns - cast_duration
			hero.mana -= skill.cost(hero)
			if skill.cost(hero) > 0:
				hero.last_mana_turn = turn_count + 1
			if skill.cooldown_seconds > 0:
				hero.cooldowns[String(cooldown_family(skill))] = turn_count + 1 + skill.cooldown_seconds
			_resolve_skill(skill, target)
		else:
			add_message("Cast failed at completion; no mana spent or credit gained.")
	_finish_turn()
	return true


func cancel_cast() -> void:
	pending_skill = null
	pending_target = null


func cooldown_family(skill: SkillRank) -> StringName:
	return &"shock" if skill.family in [&"earth_shock", &"flame_shock"] else skill.family


func valid_spell_target(skill: SkillRank, target: GridActor) -> bool:
	if skill.effect == SkillRank.Effect.KILL_STALKER:
		return target == null and _first_living_stalker() != null
	if skill.effect == SkillRank.Effect.RESURRECT:
		return (target != null and actors.has(target) and not target.alive
			and not target.story_guard and not target.chest and target.summon_kind == ""
			and target.relationship == GridActor.Relationship.FRIENDLY
			and tile_distance(player_tile, target.tile) <= skill.range_tiles
			and has_sight(player_tile, target.tile))
	if skill.effect == SkillRank.Effect.POLYMORPH and target != null:
		if target.creature_type not in ["beast", "humanoid", "critter"]:
			return false
	if skill.target in [SkillRank.Target.NONE, SkillRank.Target.SELF]:
		return target == null
	if target == null:
		return skill.target == SkillRank.Target.ALLY
	if not actors.has(target) or not target.alive:
		return false
	if (tile_distance(player_tile, target.tile) > skill.range_tiles
		or not has_sight(player_tile, target.tile)):
		return false
	if skill.target == SkillRank.Target.ALLY and target.summon_kind in ["earth", "fire"]:
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
	for effect in periodic_effects:
		var skill := SkillRank.catalog(StringName(effect.get("skill", "fireball_1")))
		if skill.effect != SkillRank.Effect.HEAL_OVER_TIME:
			return true
	for actor in actors:
		if actor.alive and actor.summon_kind == "pet" and actor.summon_target >= 0:
			if actors[actor.summon_target].alive:
				return true
		if actor.alive and actor.engaged:
			return true
	return false


func can_save() -> bool:
	return (not is_terminal() and not in_combat() and not resolving_turn
		and pending_melee == null and pending_skill == null)


func training_failure(category: StringName, skill: SkillRank) -> String:
	if is_terminal():
		return "This attempt has ended."
	if skill == null or skill.class_tab != category or hero.selected_class != category:
		return "Requires the matching selected class."
	if hero.find_skill(skill.id) != null:
		return "Already learned."
	if hero.level < skill.training_level:
		return "Requires level %d." % skill.training_level
	if skill.prerequisite != &"" and hero.find_skill(skill.prerequisite) == null:
		return "Learn the preceding rank first."
	if hero.copper < skill.training_cost:
		return "Not enough money."
	return ""


func train(category: StringName, identifier: StringName) -> bool:
	var skill := SkillRank.catalog(identifier)
	var failure := training_failure(category, skill)
	if failure != "":
		add_message(failure)
		return false
	if not hero.learn_skill(skill):
		return false
	hero.copper -= skill.training_cost
	add_message("Learned %s rank %d for %s." % [
		skill.title, skill.rank, InventoryRules.money(skill.training_cost)])
	return true


func _first_living_stalker() -> GridActor:
	for actor in actors:
		if actor.alive and actor.stalker:
			return actor
	return null


func _resolve_skill(skill: SkillRank, target: GridActor) -> void:
	match skill.effect:
		SkillRank.Effect.PRACTICE:
			add_message("Practice rank %d: cast complete (1 turn, 0 mana)." % skill.rank)
		SkillRank.Effect.EXPERIENCE:
			add_message("Gain 450 XP rank %d: gained 450 XP." % skill.rank)
			for gained_level in hero.add_experience(450):
				add_message("Level up! You are now level %d. Health and mana restored." % gained_level)
		SkillRank.Effect.GOLD:
			hero.copper += 10000
			add_message("Gain 1 gold: gained %s." % InventoryRules.money(10000))
		SkillRank.Effect.KILL_STALKER:
			var stalker := _first_living_stalker()
			if stalker != null:
				var lethal_damage := stalker.health
				# Guarantee the QA kill while still exercising normal damage/death processing.
				for buff in stalker.buffs.values():
					lethal_damage += int(buff.get("absorb", 0))
				SpellEffects.damage(self, stalker, lethal_damage, "Kill stalker")
		SkillRank.Effect.DEATH_NOTICE:
			hero.health = 0
			add_message("Death trigger invoked. You died.")
		_:
			SpellEffects.resolve(self, skill, target)
	check_terminal()


func add_message(message: String) -> void:
	messages.append(message)
	if messages.size() > CHAT_LIMIT:
		messages.remove_at(0)
	message_added.emit(message)


func is_player_dead() -> bool:
	return hero.health <= 0


func is_terminal() -> bool:
	return attempt_state != AttemptState.ACTIVE or is_player_dead()


## FR-006/013: latch the first terminal effect; victory wins simultaneous deaths.
func check_terminal() -> bool:
	if attempt_state != AttemptState.ACTIVE:
		return true
	for actor in actors:
		if actor.stalker and actor.health <= 0:
			attempt_state = AttemptState.COMPLETED
			break
	if attempt_state == AttemptState.ACTIVE and is_player_dead():
		attempt_state = AttemptState.PLAYER_DIED
	if attempt_state == AttemptState.ACTIVE:
		return false
	cancel_melee()
	cancel_cast()
	return true


func discard() -> void:
	if attempt_state == AttemptState.ACTIVE:
		attempt_state = AttemptState.DISCARDED
	cancel_melee()
	cancel_cast()


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
	if is_terminal() or not interaction_candidates().has(actor):
		return "That target is no longer available."
	if not actor.alive:
		return "%s: no loot remains." % actor.title
	if actor.relationship == GridActor.Relationship.FRIENDLY:
		QuestRules.event(self, "talk", str(actor.npc_id))
		if northshire:
			return actor.title + ": " + NorthshireZone.greeting(actor.npc_id)
		return ("%s: Welcome. The Legion is invading. The cities are besieged, and the gate is unsafe. " +
			"Some here still think this is only a bandit raid.") % actor.title
	request_melee(actor)
	return ""


func request_melee(target: GridActor) -> bool:
	if is_terminal() or pending_melee != null or pending_skill != null or not _valid_melee(target):
		return false
	target.relationship = GridActor.Relationship.HOSTILE
	target.engaged = true
	target.returning_home = false
	hero.facing = MeleeRules.facing_toward(target.tile - player_tile)
	hero.restoration.clear()
	pending_melee = target
	continue_melee()
	return true


func continue_melee() -> bool:
	if is_terminal() or not _valid_melee(pending_melee):
		pending_melee = null
		return false
	resolving_turn = true
	var target := pending_melee
	var swings := hero.swing.advance(true, hero.melee.interval / hero.haste)
	for index in range(swings):
		if not _valid_melee(target) or is_terminal():
			break
		_player_swing(target)
	if swings > 0:
		pending_melee = null
	_finish_turn(true)
	if is_terminal() or not _valid_melee(pending_melee):
		pending_melee = null
	return true


func cancel_melee() -> void:
	pending_melee = null


func _valid_melee(target: GridActor) -> bool:
	return (target != null and actors.has(target) and target.alive
		and target.relationship != GridActor.Relationship.FRIENDLY
		and not ClassSpellEffects.immune(hero.buffs)
		and tile_distance(player_tile, target.tile) == 1
		and has_sight(player_tile, target.tile))


func _finish_turn(player_timer_advanced: bool = false) -> void:
	# A committed terminal player effect still consumes its boundary, exactly once.
	if is_terminal() and not resolving_turn:
		return
	turn_count += 1
	resolving_turn = true
	if check_terminal():
		pending_melee = null
		cancel_cast()
		resolving_turn = false
		return
	if not player_timer_advanced:
		hero.swing.advance(false, hero.melee.interval / hero.haste)
	for actor in actors:
		if actor.alive and actor.expires_turn > 0 and turn_count >= actor.expires_turn:
			SummonRules.remove(self, actor)
	SummonRules.refresh_auras(self)
	_acquire_hostiles()
	for actor in actors:
		if not actor.alive:
			continue
		if actor.summon_kind != "":
			SummonRules.act(self, actor)
		else:
			_act_npc(actor)
		if check_terminal():
			pending_melee = null
			cancel_cast()
			resolving_turn = false
			return
	_tick_effects()
	if check_terminal():
		resolving_turn = false
		return
	_regenerate()
	_tick_restoration()
	_arrive_stalker()
	NorthshireZone.tick_population(self)
	_respawn_friendlies()
	_acquire_hostiles()
	resolving_turn = false
	for actor in actors:
		if not actor.alive and not actor.chest and not actor.story_guard and actor.died_on_turn >= 0:
			if turn_count - actor.died_on_turn >= 300:
				actor.corpse_visible = false


func _acquire_hostiles() -> void:
	for actor in actors:
		if not actor.alive or actor.relationship != GridActor.Relationship.HOSTILE or actor.returning_home or actor.engaged:
			continue
		if tile_distance(actor.tile, player_tile) <= actor.aggro_range and has_sight(actor.tile, player_tile):
			actor.engaged = true
			SummonRules.add_threat(self, actor, null, 1)
			add_message("%s engages you." % actor.title)
		else:
			for ally in actors:
				if (ally.alive and ally.summon_kind != "" and tile_distance(actor.tile, ally.tile) <= actor.aggro_range
					and has_sight(actor.tile, ally.tile)):
					actor.engaged = true
					SummonRules.add_threat(self, actor, ally, 1)
					break


func _act_npc(actor: GridActor) -> void:
	if actor.stunned_until > turn_count:
		actor.swing.advance(false, actor.melee.interval)
		return
	if actor.feared_until > turn_count:
		actor.swing.advance(false, actor.melee.interval)
		var best := actor.tile
		for direction in DIRECTIONS:
			var next := actor.tile + direction
			if is_open(next) and (next - player_tile).length_squared() > (best - player_tile).length_squared():
				best = next
		if best != actor.tile and actor.rooted_until <= turn_count:
			_move_actor(actor, best)
		return
	var target := SummonRules.enemy_target(self, actor)
	var target_tile := player_tile if target == null else target.tile
	if actor.polymorphed_until > turn_count:
		actor.swing.advance(false, actor.melee.interval)
		if turn_count > actor.polymorphed_on_turn:
			actor.health = mini(actor.max_health, actor.health + maxi(1, actor.max_health / 10))
		var steps: Array[Vector2i] = []
		for direction in DIRECTIONS:
			if is_open(actor.tile + direction):
				steps.append(actor.tile + direction)
		if not steps.is_empty() and actor.rooted_until <= turn_count:
			_move_actor(actor, steps[random.randi_range(0, steps.size() - 1)])
		return
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
			var tile := target_tile + direction
			if _terrain_open(tile) and has_sight(tile, target_tile):
				goals.append(tile)
		var static_path := _route(actor.tile, goals, false, target_tile)
		if static_path.is_empty():
			actor.blocked_turns += 1
			if actor.blocked_turns >= 5:
				actor.engaged = false
				actor.threat.clear()
				actor.returning_home = true
				add_message("%s cannot reach you and returns home." % actor.title)
		else:
			actor.blocked_turns = 0
			_step_toward(actor, goals, target_tile, static_path)
	else:
		_wander(actor)
	var in_melee := (actor.engaged and tile_distance(actor.tile, target_tile) == 1
		and has_sight(actor.tile, target_tile))
	var interval := actor.melee.interval * (1.25 if actor.chilled_until > turn_count else 1.0)
	var swings := actor.swing.advance(in_melee, interval)
	for index in range(swings):
		if is_terminal():
			return
		actor.facing = MeleeRules.facing_toward(target_tile - actor.tile)
		var result := MeleeRules.outcome(actor.melee, hero.melee if target == null else target.melee,
			MeleeRules.is_behind(hero.facing if target == null else target.facing, actor.tile - target_tile),
			combat_random.randf() * 100.0)
		var amount := MeleeRules.damage(actor.melee, hero.melee if target == null else target.melee, result,
			combat_random.randf(), combat_random.randf())
		if actor.debuffs.has("weakness"):
			amount = maxi(0, amount - int(actor.debuffs.weakness.reduction))
		amount = ClassSpellEffects.absorb(self, target, amount, true)
		if target == null:
			hero.health = maxi(0, hero.health - amount)
		else:
			target.health = maxi(0, target.health - amount)
			_check_npc_death(target, turn_count)
		var buffs := hero.buffs if target == null else target.buffs
		if amount > 0 and (buffs.has(&"frost_armor_1") or buffs.has(&"frost_armor_2")):
			actor.chilled_until = turn_count + 5
		add_message("%s -> %s: %s, %d damage." % [actor.title, "You" if target == null else target.title, result, amount])
		# Retaliation is a subsequent effect, so a lethal incoming hit ends first.
		if check_terminal():
			add_message("You died.")
			return
		if target != null and not target.alive:
			return
		if amount > 0 and buffs.has(&"thorns_1"):
			SpellEffects.damage(self, actor, int(buffs[&"thorns_1"].thorns), "Thorns", turn_count)
		if check_terminal():
			return
		ClassSpellEffects.retaliate(self, actor, target, amount)
		if not actor.alive:
			return


func _player_swing(target: GridActor) -> void:
	var result := MeleeRules.outcome(hero.melee, target.melee,
		MeleeRules.is_behind(target.facing, player_tile - target.tile),
		combat_random.randf() * 100.0)
	var amount := MeleeRules.damage(hero.melee, target.melee, result,
		combat_random.randf(), combat_random.randf())
	if hero.buffs.has(&"seal_of_the_crusader_1"):
		amount = int(amount / 1.4)
	SpellEffects.damage(self, target, amount, "You (%s)" % result)
	ClassSpellEffects.on_melee(self, target, amount)


func _check_npc_death(target: GridActor, death_turn: int = -1) -> void:
	if attempt_state != AttemptState.ACTIVE:
		return
	if target.health == 0 and target.alive:
		if target.summon_kind != "":
			SummonRules.remove(self, target)
			add_message(target.title + " dies.")
			return
		target.alive = false
		target.engaged = false
		target.returning_home = false
		if check_terminal():
			return
		LootData.assign(self, target)
		target.died_on_turn = turn_count + 1 if death_turn == -1 else death_turn
		NorthshireZone.died(self, target)
		if target.relationship != GridActor.Relationship.FRIENDLY:
			QuestRules.event(self, "kill", str(target.npc_id))
		var xp := MeleeRules.kill_experience(hero.level, target.melee.level)
		if not target.awards_experience:
			xp = 0
		add_message("%s dies. Gained %d XP." % [target.title, xp])
		for gained_level in hero.add_experience(xp):
			add_message("Level up! You are now level %d. Health and mana restored." % gained_level)


func _wander(actor: GridActor) -> void:
	if actor.rooted_until > turn_count:
		return
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
	if actor.rooted_until > turn_count:
		return
	var route := terrain_route
	if route.is_empty():
		route = _route(actor.tile, goals, false, toward)
	if route.size() <= 1:
		return
	# Follow the terrain route until its next step is physically occupied.
	if not is_open(route[1]):
		route = _route(actor.tile, goals, true, toward)
	if route.size() > 1:
		var speed := 0.7 if actor.chilled_until > turn_count else 1.0
		if actor.slowed_until > turn_count:
			speed = minf(speed, 0.6)
		if actor.debuffs.has("earthbind"):
			speed = minf(speed, 0.5)
		actor.movement_credit += speed
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
	SpellEffects.tick(self)
	if check_terminal():
		return
	ClassSpellEffects.tick(self)
	for key in hero.buffs.keys():
		if int(hero.buffs[key].until) <= turn_count:
			hero.buffs.erase(key)
			hero.refresh_stats()
	for actor in actors:
		for key in actor.buffs.keys():
			if int(actor.buffs[key].until) <= turn_count:
				if actor.summon_kind != "pet":
					actor.melee.armor -= int(actor.buffs[key].get("armor", 0))
					actor.melee.attack_power -= int(actor.buffs[key].get("attack_power", 0))
					if actor.buffs[key].has("stamina"):
						actor.max_health -= int(actor.buffs[key].stamina) * 10
						actor.health = mini(actor.health, actor.max_health)
				actor.buffs.erase(key)

	SummonRules.refresh_auras(self)


func _regenerate() -> void:
	if turn_count % 2 != 0:
		return
	if not in_combat():
		hero.health = mini(hero.max_health, hero.health + int((hero.spirit * 0.11 + 1) * 2))
	if turn_count - hero.last_mana_turn >= 5:
		hero.mana = mini(hero.max_mana, hero.mana + int(hero.spirit / 4.0 + 12.5))


func _arrive_stalker() -> void:
	if is_terminal() or not stalker_schedule:
		return
	# FR-033: overdue identities enter in order; blocking never moves a deadline.
	while stalkers_arrived < stalker_deadlines.size():
		if turn_count < stalker_deadlines[stalkers_arrived]:
			break
		var entry := Vector2i(-1, -1)
		for tile in STALKER_ENTRIES:
			if is_open(tile):
				entry = tile
				break
		if entry == Vector2i(-1, -1):
			break
		_spawn_stalker(entry)
	_acquire_hostiles()


func _spawn_stalker(entry: Vector2i) -> void:
	var stalker := GridActor.new(entry)
	stalker.title = "Demon stalker"
	stalker.stalker = true
	stalker.creature_type = "demon"
	stalker.spawn_id = "gate/stalker/%d" % stalkers_arrived
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
	stalkers_arrived += 1
	if stalkers_arrived == 1:
		for actor in actors:
			if actor.story_guard:
				actor.health = 0
				actor.alive = false
				actor.engaged = false
				actor.died_on_turn = turn_count
		add_message("A demon stalker enters the gate, kills the guard, and begins to feast!")
	else:
		add_message("A demon stalker reinforcement enters the gate (%d of 5)!" % stalkers_arrived)


func item_action_ready() -> bool:
	return not is_terminal() and pending_melee == null and pending_skill == null and not resolving_turn


func equip_item(index: int, slot: String = "") -> bool:
	if not item_action_ready() or not InventoryRules.equip(hero, index, slot):
		add_message("Cannot equip: check level, slot, hands, or inventory space.")
		return false
	hero.restoration.clear()
	_finish_turn()
	return true


func unequip_item(slot: String) -> bool:
	if not item_action_ready() or not InventoryRules.unequip(hero, slot):
		add_message("Cannot unequip: make inventory space first.")
		return false
	hero.restoration.clear()
	_finish_turn()
	return true


func open_loot(source: GridActor) -> bool:
	if not item_action_ready() or not interaction_candidates().has(source) or source.alive:
		return false
	LootData.assign(self, source)
	return true


func loot_item(source: GridActor, index: int) -> bool:
	if not open_loot(source) or index < 0 or index >= source.loot.size():
		return false
	var item := source.loot[index]
	if not LootData.collectable(self, item):
		add_message("That quest item is no longer eligible.")
		return false
	if not InventoryRules.add(hero.inventory, item):
		add_message("Inventory full. Loot remains at its source.")
		return false
	add_message("Looted %s x%d." % [ItemData.get_item(int(item.id)).title, item.quantity])
	source.loot.remove_at(index)
	_hide_empty_corpse(source)
	return true


func loot_money(source: GridActor) -> bool:
	if not open_loot(source) or source.loot_copper <= 0:
		return false
	hero.copper += source.loot_copper
	add_message("Collected %s." % InventoryRules.money(source.loot_copper))
	source.loot_copper = 0
	_hide_empty_corpse(source)
	return true


func _hide_empty_corpse(source: GridActor) -> void:
	if source.loot.is_empty() and source.loot_copper == 0 and not source.story_guard:
		source.corpse_visible = false


func trader_in_range() -> bool:
	for actor in interaction_candidates():
		if actor.alive and actor.service == &"Trader":
			return true
	return false


func buy_item(identifier: int, quantity: int) -> bool:
	var key := str(identifier)
	if not item_action_ready() or not trader_in_range() or not vendor_stock.has(key) or quantity < 1:
		return false
	var data := ItemData.get_item(identifier)
	var cost := int(data.buy) * quantity
	if (quantity > 1000 or cost > hero.copper
		or (int(vendor_stock[key]) >= 0 and quantity > int(vendor_stock[key]))):
		add_message("Purchase rejected: insufficient money or stock.")
		return false
	if not InventoryRules.add(hero.inventory, ItemData.instance(identifier, quantity)):
		add_message("Purchase rejected: inventory full.")
		return false
	hero.copper -= cost
	if int(vendor_stock[key]) >= 0:
		vendor_stock[key] -= quantity
	add_message("Bought %s x%d for %s." % [data.title, quantity, InventoryRules.money(cost)])
	return true


func sell_item(index: int, quantity: int) -> bool:
	if (not item_action_ready() or not trader_in_range() or index < 0 or index >= 40
		or hero.inventory[index].is_empty() or quantity < 1):
		return false
	var item := hero.inventory[index]
	var data := ItemData.get_item(int(item.id))
	if quantity > int(item.quantity) or not data.tradable:
		return false
	hero.copper += int(data.sell) * quantity
	item.quantity -= quantity
	if item.quantity == 0:
		hero.inventory[index] = {}
	add_message("Sold %s x%d for %s." % [data.title, quantity,
		InventoryRules.money(int(data.sell) * quantity)])
	return true


func consume_item(index: int) -> bool:
	if not item_action_ready() or index < 0 or index >= 40 or hero.inventory[index].is_empty():
		return false
	var item := hero.inventory[index]
	var data := ItemData.get_item(int(item.id))
	if data.use == "" or hero.level < int(data.level):
		add_message("Cannot use that item at this level.")
		return false
	var potion: bool = data.use in ["health", "mana", "healthstone"]
	var ready := hero.healthstone_ready_turn if data.use == "healthstone" else hero.potion_ready_turn
	if (potion and turn_count < ready) or (not potion and in_combat()):
		add_message("Cannot use: potion cooldown or food/drink during combat.")
		return false
	resolving_turn = true
	if potion:
		var amount := combat_random.randi_range(int(data.restore_min), int(data.restore_max))
		if data.use in ["health", "healthstone"]:
			hero.health = mini(hero.max_health, hero.health + amount)
		else:
			hero.mana = mini(hero.max_mana, hero.mana + amount)
		if data.use == "healthstone":
			hero.healthstone_ready_turn = turn_count + 1 + int(data.cooldown)
		else:
			hero.potion_ready_turn = turn_count + 1 + int(data.cooldown)
	else:
		hero.restoration[data.use] = {"total": int(data.restore), "duration": int(data.duration),
			"started": turn_count + 1, "delivered": 0}
	item.quantity -= 1
	if item.quantity == 0:
		hero.inventory[index] = {}
	add_message("Used %s." % data.title)
	_finish_turn()
	return true


func _tick_restoration() -> void:
	if in_combat():
		hero.restoration.clear()
		return
	for kind in hero.restoration.keys():
		var effect: Dictionary = hero.restoration[kind]
		var elapsed := mini(turn_count - int(effect.started), int(effect.duration))
		# Source food/drink restore over their full duration, only on simulation boundaries.
		var delivered := floori(float(effect.total) * elapsed / int(effect.duration))
		var amount := delivered - int(effect.delivered)
		effect.delivered = delivered
		if kind == "food":
			hero.health = mini(hero.max_health, hero.health + amount)
		else:
			hero.mana = mini(hero.max_mana, hero.mana + amount)
		if elapsed >= int(effect.duration):
			hero.restoration.erase(kind)


func _respawn_friendlies() -> void:
	for actor in actors:
		if (actor.alive or actor.chest or actor.story_guard or actor.summon_kind != ""
			or actor.relationship != GridActor.Relationship.FRIENDLY
			or actor.died_on_turn < 0 or turn_count < actor.died_on_turn + 30):
			continue
		if not is_open(actor.home_tile):
			continue
		actor.tile = actor.home_tile
		actor.health = actor.max_health
		actor.alive = true
		actor.corpse_visible = true
		actor.died_on_turn = -1
		actor.buffs.clear()
		actor.swing = SwingTimer.new()
