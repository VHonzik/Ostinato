class_name GridWorld
extends RefCounted

signal message_added(message: String)
signal friendly_interaction_requested(actor: GridActor)

enum AttemptState { ACTIVE, PLAYER_DIED, COMPLETED, DISCARDED }

## Player-driven movement and combat.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const HOTBAR_SIZE: int = 20
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
var last_attacked_enemy: GridActor
var auto_attack_target: GridActor
var queued_strike: SkillRank
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
var holy_event_counted: bool = false
var combo_event_counted: bool = false
var queued_rage_cost: int = 0
var stalker_schedule: bool = false
var stalkers_arrived: int = 0
var stalker_deadlines: Array[int] = STALKER_DEADLINES.duplicate()
var class_selected: bool = false
var starter_gear_received: bool = false
var trainer_referral_received: bool = false
var ever_accepted_quest: bool = false
var hotbar: Array[StringName] = []
var hotbar_locked: bool = false
var resolving_turn: bool = false
var attempt_state: AttemptState = AttemptState.ACTIVE
var seed_value: int = 1
var loot_quests: Array[String] = []
var quests: Dictionary = {}
var population: Array[Dictionary] = []
var northshire: bool = false
var vendor_stock: Dictionary = {}
var indoor_tiles: Dictionary[Vector2i, bool] = {}
var valley_route: bool = false
var ground_tiles: Dictionary[Vector2i, StringName] = {}
var scenery_tiles: Dictionary[Vector2i, StringName] = {}

var _neutral_bump_target: GridActor
var _neutral_bump_tile: Vector2i


func _init(
	map_bounds: Rect2i, spawn: Vector2i, world_seed: int = 1,
	development_build: bool = OS.is_debug_build()
) -> void:
	hotbar.resize(HOTBAR_SIZE)
	hotbar.fill(&"")
	seed_value = world_seed
	hero = HeroState.new(development_build)
	bounds = map_bounds
	player_tile = spawn
	random.seed = world_seed
	combat_random.seed = world_seed ^ 15485863


func assign_hotbar(slot: int, identifier: StringName) -> bool:
	# Store an explicit learned rank; layout editing never spends time.
	if is_terminal() or hotbar_locked or slot < 0 or slot >= hotbar.size():
		return false
	if identifier != &"":
		var skill := hero.find_skill(identifier)
		if skill == null or skill.effect == SkillRank.Effect.PASSIVE:
			return false
	hotbar[slot] = identifier
	return true


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
	if occupant != null and occupant.relationship == GridActor.Relationship.FRIENDLY:
		_neutral_bump_target = null
		friendly_interaction_requested.emit(occupant)
		return false
	if occupant != null and occupant.relationship == GridActor.Relationship.NEUTRAL:
		if occupant == _neutral_bump_target and occupant.tile == _neutral_bump_tile:
			_neutral_bump_target = null
			return request_melee(occupant)
		_neutral_bump_target = occupant
		_neutral_bump_tile = occupant.tile
		add_message("Bump %s again to attack if it stays here." % occupant.title)
		return false
	_neutral_bump_target = null
	if occupant != null and occupant.relationship == GridActor.Relationship.HOSTILE:
		return request_melee(occupant)
	# Reject before granting time or credit. Only the destination blocks a diagonal.
	if not is_open(player_tile + direction):
		return false
	hero.restoration.clear()
	resolving_turn = true
	holy_event_counted = false
	movement_credit += movement_speed * (1.0 + ClassToolkitRules.magnitude(hero, &"pursuit_of_justice_1") / 100.0)
	while movement_credit >= 1.0 - 0.000001 and is_open(player_tile + direction):
		player_tile += direction
		QuestRules.visit(self)
		hero.facing = direction
		movement_credit = maxf(0.0, movement_credit - 1.0)
		_acquire_hostiles()
	_finish_turn()
	return true


func wait_turn() -> void:
	if not is_terminal() and pending_melee == null and pending_skill == null:
		holy_event_counted = false
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
	if (skill.effect in [SkillRank.Effect.MORTAL_STRIKE, SkillRank.Effect.HEROIC_STRIKE,
		SkillRank.Effect.EXECUTE, SkillRank.Effect.TOOLKIT]
		and skill.target == SkillRank.Target.ENEMY and target == null and in_combat()):
		target = last_attacked_enemy
	if skill.effect == SkillRank.Effect.PASSIVE:
		return false
	if skill.available_resource(hero) < skill.cost(hero):
		add_message("Not enough %s for %s: requires %d, have %d." % [
			skill.resource_name(), skill.title, skill.cost(hero), skill.available_resource(hero)])
		return false
	if (skill.effect == SkillRank.Effect.EXECUTE and target != null and target.alive
		and not skill.execute_eligible(target) and not hero.buffs.has(&"sudden_death_1")):
		add_message("Cannot Execute: target must be at or below %d%% health. No turn spent." %
			skill.execute_health_percent)
		return false
	if ((global_cooldown_until > turn_count)
		or int(hero.cooldowns.get(String(cooldown_family(skill)), 0)) > turn_count
		or not valid_spell_target(skill, target) or not SpellEffects.can_apply(self, skill, target)):
		add_message("Cannot cast: invalid target, range, sight, or cooldown.")
		return false
	if skill.effect == SkillRank.Effect.CHARGE and charge_route(target).is_empty():
		add_message("Cannot Charge: no reachable empty melee tile.")
		return false
	if skill.effect == SkillRank.Effect.HEROIC_STRIKE:
		if not _valid_melee(target):
			add_message("Cannot queue Heroic Strike: no valid melee target.")
			return false
		queued_rage_cost = skill.cost(hero)
		skill.spend_resource(hero)
		ClassToolkitRules.consume_cost_proc(hero, skill)
		queued_strike = skill
		add_message("Heroic Strike queued on %s; %d rage reserved. Esc refunds it." % [
			target.title, queued_rage_cost])
		return request_melee(target)
	hero.restoration.clear()
	pending_skill = skill
	pending_target = target
	cast_elapsed = 0
	cast_duration = skill.cast_seconds
	cast_turns = maxi(1, ceili(cast_duration - hero.casting_credit))
	global_cooldown_until = turn_count + 1
	if skill.target == SkillRank.Target.ENEMY:
		target.relationship = GridActor.Relationship.HOSTILE
		target.engaged = true
		target.returning_home = false
		if skill.effect in [SkillRank.Effect.MORTAL_STRIKE, SkillRank.Effect.EXECUTE, SkillRank.Effect.TOOLKIT]:
			auto_attack_target = target
	if target != null:
		hero.facing = MeleeRules.facing_toward(target.tile - player_tile)
	continue_cast()
	return true


func continue_cast() -> bool:
	if pending_skill == null or is_terminal():
		cancel_cast(true)
		return false
	holy_event_counted = false
	resolving_turn = true
	cast_elapsed += 1
	if is_charging():
		return _continue_charge()
	if cast_elapsed >= cast_turns:
		var skill := pending_skill
		var target := pending_target
		cancel_cast()
		if (skill.available_resource(hero) >= skill.cost(hero) and valid_spell_target(skill, target)
			and SpellEffects.can_apply(self, skill, target)):
			hero.casting_credit += cast_turns - cast_duration
			var resource_spent := skill.cost(hero)
			skill.spend_resource(hero)
			ClassToolkitRules.consume_cost_proc(hero, skill)
			if skill.cooldown_seconds > 0:
				hero.cooldowns[String(cooldown_family(skill))] = turn_count + 1 + ClassToolkitRules.cooldown(hero, skill)
			_resolve_skill(skill, target, resource_spent)
		else:
			add_message("Cast failed at completion; no resource spent or credit gained.")
	_finish_turn()
	return true


func is_charging() -> bool:
	return pending_skill != null and pending_skill.effect == SkillRank.Effect.CHARGE


func charge_route(target: GridActor) -> Array[Vector2i]:
	if (target == null or not actors.has(target) or not target.alive
		or target.relationship == GridActor.Relationship.FRIENDLY):
		return []
	if tile_distance(player_tile, target.tile) == 1 and has_sight(player_tile, target.tile):
		return [player_tile]
	var goals: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var tile := target.tile + direction
		if is_open(tile) and has_sight(tile, target.tile):
			goals.append(tile)
	if goals.is_empty():
		return []
	var route := _route(player_tile, goals, true, target.tile)
	return route if not route.is_empty() and goals.has(route[-1]) else []


func _continue_charge() -> bool:
	var skill := pending_skill
	var target := pending_target
	var route := charge_route(target)
	if route.is_empty():
		cancel_cast(true)
		add_message("Charge stopped: target or melee route is no longer available.")
	elif cast_elapsed > cast_turns or route.size() == 1:
		# The wind-up is followed by automatic travel using its own speed, not movement credit.
		var steps := mini(skill.travel_speed, route.size() - 1)
		for index in range(1, steps + 1):
			hero.facing = MeleeRules.facing_toward(route[index] - player_tile)
			player_tile = route[index]
			QuestRules.visit(self)
			_acquire_hostiles()
		if steps == route.size() - 1:
			cancel_cast(true)
			hero.cooldowns[String(cooldown_family(skill))] = turn_count + 1 + ClassToolkitRules.cooldown(hero, skill)
			_resolve_skill(skill, target)
	_finish_turn()
	return true


func cancel_cast(force: bool = false) -> void:
	if is_charging() and not force:
		return
	pending_skill = null
	pending_target = null


func cooldown_family(skill: SkillRank) -> StringName:
	return &"shock" if skill.family == &"earth_shock" else skill.family


func valid_spell_target(skill: SkillRank, target: GridActor) -> bool:
	if skill.effect == SkillRank.Effect.KILL_STALKER:
		return target == null and _first_living_stalker() != null
	if skill.target in [SkillRank.Target.NONE, SkillRank.Target.SELF]:
		return target == null
	if target == null:
		return skill.target == SkillRank.Target.ALLY
	if not actors.has(target) or not target.alive:
		return false
	if (skill.effect == SkillRank.Effect.EXECUTE and not skill.execute_eligible(target)
		and not hero.buffs.has(&"sudden_death_1")):
		return false
	var distance := tile_distance(player_tile, target.tile)
	if (distance < skill.minimum_range_tiles or distance > skill.range_tiles
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
	for actor in actors:
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
	if (category in ClassSkillData.PLAYABLE_CLASSES
		and not ClassSkillData.is_playable_rank(skill.id)):
		return "This ability is not available in the current class slice."
	if hero.find_skill(skill.id) != null:
		return "Already learned."
	if hero.progression_points(category) < skill.progress_required:
		return "Requires %d %s progression points." % [
			skill.progress_required, String(category).to_lower()]
	if hero.level < skill.training_level:
		return "Requires level %d." % skill.training_level
	return ""


func train(category: StringName, identifier: StringName) -> bool:
	var skill := SkillRank.catalog(identifier)
	var failure := training_failure(category, skill)
	if failure != "":
		add_message(failure)
		return false
	if not hero.learn_skill(skill):
		return false
	if skill.effect != SkillRank.Effect.PASSIVE and not hotbar.has(skill.id):
		var empty_slot := hotbar.find(&"")
		if empty_slot >= 0:
			hotbar[empty_slot] = skill.id
	if skill.progress_required > 0:
		add_message("Learned %s. Your %s progression points remain at %d." % [
			skill.title, String(category).to_lower(), hero.progression_points(category)])
	else:
		add_message("Learned %s rank %d for %s." % [
			skill.title, skill.rank, "free"])
	return true


func _first_living_stalker() -> GridActor:
	for actor in actors:
		if actor.alive and actor.stalker:
			return actor
	return null


func _resolve_skill(skill: SkillRank, target: GridActor, resource_spent: int = 0) -> void:
	_award_ability_use(skill)
	match skill.effect:
		SkillRank.Effect.MORTAL_STRIKE, SkillRank.Effect.EXECUTE:
			var flat_bonus := skill.minimum
			if skill.effect == SkillRank.Effect.EXECUTE:
				flat_bonus += maxi(0, resource_spent - skill.rage_cost) * skill.execute_damage_per_rage
				add_message("Execute: spent %d rage." % resource_spent)
			ClassToolkitRules.physical_attack(self, target, skill, flat_bonus)
		SkillRank.Effect.TOOLKIT:
			ClassToolkitRules.resolve(self, skill, target)
		SkillRank.Effect.BATTLE_SHOUT:
			hero.gain_rage(skill.rage_generated)
			hero.buffs[skill.id] = {"armor": 0, "physical_percent": skill.physical_percent,
				"until": turn_count + 1 + skill.duration}
			hero.refresh_stats()
			add_message("Battle Shout: physical damage increased; gained %d rage." % skill.rage_generated)
		SkillRank.Effect.CHARGE:
			last_attacked_enemy = target
			auto_attack_target = target
			hero.gain_rage(skill.rage_generated)
			add_message("Charge: reached %s; gained %d rage." % [target.title, skill.rage_generated])
			ClassToolkitRules.apply(self, &"juggernaut_1", {"charges": 1})
		SkillRank.Effect.CLASS_POINTS:
			add_class_progress(hero.selected_class, 30)
			add_message("Gained 30 %s progression points." % String(hero.selected_class).to_lower())
		SkillRank.Effect.PRACTICE:
			add_message("Practice rank %d: cast complete (1 turn, 0 rage)." % skill.rank)
		SkillRank.Effect.EXPERIENCE:
			add_message("Gain 450 XP rank %d: gained 450 XP." % skill.rank)
			for gained_level in hero.add_experience(450):
				add_message("Level up! You are now level %d. Health restored." % gained_level)
		SkillRank.Effect.GOLD:
			hero.copper += 10000
			add_message("Gain 1 gold: gained %s." % InventoryRules.money(10000))
		SkillRank.Effect.KILL_STALKER:
			var stalker := _first_living_stalker()
			if stalker != null:
				var lethal_damage := stalker.health
				SpellEffects.damage(self, stalker, lethal_damage, "Kill stalker")
		SkillRank.Effect.DEATH_NOTICE:
			hero.health = 0
			add_message("Death trigger invoked. You died.")
		_:
			SpellEffects.resolve(self, skill, target)
	check_terminal()


func _award_ability_use(skill: SkillRank) -> void:
	if not skill.development_only and skill.class_tab == hero.selected_class:
		add_class_progress(skill.class_tab, 1)


func add_class_progress(category: StringName, amount: int) -> void:
	var previous := hero.progression_points(category)
	hero.class_progress[category] = previous + amount
	for skill in SkillRank.trainer_skills(category):
		if previous < skill.progress_required and hero.progression_points(category) >= skill.progress_required:
			var trainer := "Llane Beshere, the warrior trainer," if category == &"Warrior" else (
				"the %s trainer" % String(category).to_lower())
			add_message("%d %s progression points! Visit %s to learn %s." % [
				skill.progress_required, String(category).to_lower(), trainer, skill.title])


func add_message(message: String) -> void:
	messages.append(message)
	if messages.size() > CHAT_LIMIT:
		messages.remove_at(0)
	message_added.emit(message)


func is_player_dead() -> bool:
	return hero.health <= 0


func is_terminal() -> bool:
	return attempt_state != AttemptState.ACTIVE or is_player_dead()


## Latch the first terminal effect; victory wins simultaneous deaths.
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
	cancel_cast(true)
	return true


func discard() -> void:
	if attempt_state == AttemptState.ACTIVE:
		attempt_state = AttemptState.DISCARDED
	cancel_melee()
	cancel_cast(true)


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
			return actor.title + ": " + ValleyRoute.greeting(actor.npc_id)
		return ("%s: Welcome. The Legion is invading. The cities are besieged, and the gate is unsafe. " +
			"Some here still think this is only a bandit raid.") % actor.title
	request_melee(actor)
	return ""


func request_melee(target: GridActor) -> bool:
	if is_terminal() or pending_melee != null or pending_skill != null or not _valid_melee(target):
		return false
	_neutral_bump_target = null
	target.relationship = GridActor.Relationship.HOSTILE
	target.engaged = true
	target.returning_home = false
	hero.facing = MeleeRules.facing_toward(target.tile - player_tile)
	hero.restoration.clear()
	pending_melee = target
	auto_attack_target = target
	continue_melee()
	return true


func continue_melee() -> bool:
	if is_terminal() or not _valid_melee(pending_melee):
		cancel_melee()
		return false
	holy_event_counted = false
	resolving_turn = true
	_finish_turn()
	if pending_melee != null and not _valid_melee(pending_melee):
		cancel_melee()
	return true


func cancel_melee() -> void:
	pending_melee = null
	auto_attack_target = null
	if queued_strike != null:
		var reserved := queued_rage_cost
		queued_rage_cost = 0
		queued_strike = null
		hero.gain_rage(reserved)
		add_message("Heroic Strike cancelled; %d reserved rage refunded." % reserved)


func _advance_player_weapon() -> void:
	if queued_strike != null and not _valid_melee(pending_melee):
		cancel_melee()
	if (auto_attack_target != null and (not auto_attack_target.alive
		or not actors.has(auto_attack_target)
		or auto_attack_target.relationship == GridActor.Relationship.FRIENDLY)):
		auto_attack_target = null
	var target := auto_attack_target
	var haste := hero.attack_haste()
	var interval := hero.melee.interval / haste
	var swings := hero.swing.advance(_valid_melee(target), interval)
	var off_weapon := hero.off_hand_melee()
	var off_interval := off_weapon.interval / haste
	var off_swings := hero.off_hand_swing.advance(hero.has_off_hand_weapon() and _valid_melee(target), off_interval)
	var due: Array[Dictionary] = []
	for index in range(swings):
		due.append({"offset": hero.swing.remaining - interval * (swings - index), "off_hand": false})
	for index in range(off_swings):
		due.append({"offset": hero.off_hand_swing.remaining - off_interval * (off_swings - index), "off_hand": true})
	due.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if is_equal_approx(first.offset, second.offset):
			return not first.off_hand and second.off_hand
		return first.offset < second.offset)
	for attack in due:
		if not _valid_melee(target) or is_terminal():
			break
		if attack.off_hand:
			_player_off_hand_swing(target, off_weapon)
		else:
			_player_swing(target)
	if queued_strike != null and not _valid_melee(pending_melee):
		cancel_melee()
	if swings > 0:
		pending_melee = null


func _valid_melee(target: GridActor) -> bool:
	return (target != null and actors.has(target) and target.alive
		and target.relationship != GridActor.Relationship.FRIENDLY
		and tile_distance(player_tile, target.tile) == 1
		and has_sight(player_tile, target.tile))


func _finish_turn() -> void:
	# A committed terminal player effect still consumes its boundary, exactly once.
	if is_terminal() and not resolving_turn:
		return
	turn_count += 1
	resolving_turn = true
	if check_terminal():
		pending_melee = null
		cancel_cast(true)
		resolving_turn = false
		return
	_expire_hero_buffs()
	# The action effect precedes player swings; enemies respond after those swings.
	_advance_player_weapon()
	if check_terminal():
		resolving_turn = false
		return
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
			cancel_cast(true)
			resolving_turn = false
			return
	_tick_effects()
	if check_terminal():
		resolving_turn = false
		return
	_regenerate()
	_tick_restoration()
	_arrive_stalker()
	_acquire_hostiles()
	resolving_turn = false
	combo_event_counted = false
	for actor in actors:
		_hide_empty_corpse(actor)
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
	var target := SummonRules.enemy_target(self, actor)
	var target_tile := player_tile if target == null else target.tile
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
	var interval := actor.melee.interval
	var swings := actor.swing.advance(in_melee, interval)
	for index in range(swings):
		if is_terminal():
			return
		actor.facing = MeleeRules.facing_toward(target_tile - actor.tile)
		var result := MeleeRules.outcome(actor.melee, hero.melee if target == null else target.melee,
			MeleeRules.is_behind(hero.facing if target == null else target.facing, actor.tile - target_tile)
				and not (target == null and hero.buffs.has(&"evasion_1")),
			combat_random.randf() * 100.0)
		var amount := MeleeRules.damage(actor.melee, hero.melee if target == null else target.melee, result,
			combat_random.randf())
		amount = ClassSpellEffects.absorb(self, target, amount, true)
		if target == null:
			hero.health = maxi(0, hero.health - amount)
			if amount > 0 and hero.last_hit_rage_turn != turn_count:
				hero.gain_rage(HeroState.INCOMING_RAGE_PER_TURN)
				hero.last_hit_rage_turn = turn_count
		else:
			target.health = maxi(0, target.health - amount)
			_check_npc_death(target, turn_count)
		add_message("%s -> %s: %s, %d damage." % [actor.title, "You" if target == null else target.title, result, amount])
		# Retaliation is a subsequent effect, so a lethal incoming hit ends first.
		if check_terminal():
			add_message("You died.")
			return
		if target != null and not target.alive:
			return
		ClassSpellEffects.retaliate(self, actor, target, amount)
		if target == null:
			ClassToolkitRules.incoming(self, actor, amount, result == &"critical")
		if not actor.alive:
			return


func _player_swing(target: GridActor) -> void:
	last_attacked_enemy = target
	var strike := queued_strike
	queued_strike = null
	queued_rage_cost = 0
	if strike == null:
		hero.gain_rage(HeroState.SWING_RAGE_PER_BASE_TURN * hero.melee.interval)
	else:
		_award_ability_use(strike)
	ClassToolkitRules.consume_flurry(hero)
	var outcome := ClassToolkitRules.weapon_outcome(self, target, strike, hero.melee)
	var result: StringName = outcome.result
	var amount := MeleeRules.damage(hero.melee, target.melee, result,
		combat_random.randf(),
		1.0 if strike == null else strike.weapon_multiplier,
		0 if strike == null else strike.minimum)
	amount = floori(amount * ClassToolkitRules.damage_multiplier(hero))
	SpellEffects.damage(self, target, amount, "%s (%s)" % [
		"You" if strike == null else strike.title, result], turn_count, null, true)
	var landed := result not in [&"miss", &"dodge"]
	ClassSpellEffects.on_melee(self, target, amount, landed)
	ClassToolkitRules.on_attack(self, target, strike, landed, outcome.critical, amount, true)


func _player_off_hand_swing(target: GridActor, weapon: MeleeProfile) -> void:
	ClassToolkitRules.consume_flurry(hero)
	var outcome := ClassToolkitRules.weapon_outcome(self, target, null, weapon)
	var value := MeleeRules.damage(weapon, target.melee, outcome.result,
		combat_random.randf())
	value = floori(value * ClassToolkitRules.damage_multiplier(hero))
	SpellEffects.damage(self, target, value, "Off-hand (%s)" % outcome.result, turn_count, null, true)
	ClassToolkitRules.on_attack(self, target, null, outcome.landed, outcome.critical, value, true, true)


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
			_hide_empty_corpse(target)
			return
		if target.relationship != GridActor.Relationship.FRIENDLY and ClassToolkitRules.has(hero, &"victory_rush_1"):
			SpellEffects.heal(self, null, floori(hero.max_health * ClassToolkitRules.magnitude(hero, &"victory_rush_1") / 100.0), "Victory Rush")
		LootData.assign(self, target)
		_hide_empty_corpse(target)
		target.died_on_turn = turn_count + 1 if death_turn == -1 else death_turn
		if target.relationship != GridActor.Relationship.FRIENDLY:
			QuestRules.event(self, "kill", str(target.npc_id))
		var xp := MeleeRules.kill_experience(hero.level, target.melee.level)
		if not target.awards_experience:
			xp = 0
		add_message("%s dies. Gained %d XP." % [target.title, xp])
		for gained_level in hero.add_experience(xp):
			add_message("Level up! You are now level %d. Health restored." % gained_level)


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
	if _held_by_charge(actor):
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
		actor.movement_credit += 1.0
		if actor.movement_credit >= 1.0:
			actor.movement_credit -= 1.0
			_move_actor(actor, route[1])


func _move_actor(actor: GridActor, tile: Vector2i) -> void:
	if _held_by_charge(actor):
		return
	if actor == _neutral_bump_target and tile != actor.tile:
		_neutral_bump_target = null
	actor.facing = MeleeRules.facing_toward(tile - actor.tile)
	actor.tile = tile


func _held_by_charge(actor: GridActor) -> bool:
	# Movement only: nearby summons may still be attacked during wind-up and travel.
	return is_charging() and pending_target == actor and not _valid_melee(actor)


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
	ClassSpellEffects.tick(self)
	_expire_hero_buffs()

	SummonRules.refresh_auras(self)


func _expire_hero_buffs() -> void:
	var changed := false
	for key in hero.buffs.keys():
		if int(hero.buffs[key].until) <= turn_count:
			hero.buffs.erase(key)
			changed = true
	if changed:
		hero.refresh_stats()


func _regenerate() -> void:
	if not in_combat():
		last_attacked_enemy = null
		auto_attack_target = null
		hero.decay_rage()
	if turn_count % 2 != 0:
		return
	if not in_combat():
		hero.health = mini(hero.max_health, hero.health + 6)


func _arrive_stalker() -> void:
	if is_terminal() or not stalker_schedule:
		return
	# Overdue identities enter in order; blocking never moves a deadline.
	while stalkers_arrived < stalker_deadlines.size():
		if turn_count < stalker_deadlines[stalkers_arrived]:
			break
		var entry := Vector2i(-1, -1)
		for tile in (ValleyRoute.STALKER_ENTRIES if valley_route else STALKER_ENTRIES):
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
	var profile := NorthshireData.STALKER
	stalker.max_health = int(profile.health)
	stalker.health = stalker.max_health
	stalker.melee.level = int(profile.level)
	stalker.melee.armor = int(profile.armor)
	stalker.melee.damage_min = float(profile.minimum)
	stalker.melee.damage_max = float(profile.maximum)
	stalker.melee.attack_power = int(profile.power)
	stalker.melee.interval = float(profile.interval)
	actors.append(stalker)
	stalkers_arrived += 1
	if stalkers_arrived == 1:
		for actor in actors:
			if actor.story_guard:
				actor.health = 0
				actor.alive = false
				actor.engaged = false
				actor.died_on_turn = turn_count
				LootData.assign(self, actor)
				_hide_empty_corpse(actor)
		add_message("A demon stalker enters the gate, kills the guard, and begins to feast!")
	else:
		add_message("A demon stalker reinforcement enters the gate (%d of 5)!" % stalkers_arrived)


func item_action_ready() -> bool:
	return not is_terminal() and pending_melee == null and pending_skill == null and not resolving_turn


func equip_item(index: int, slot: String = "") -> bool:
	if not item_action_ready() or not InventoryRules.equip(hero, index, slot):
		add_message("Cannot equip: check the slot or inventory space.")
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
	_hide_empty_corpse(source)
	return source.corpse_visible


func loot_item(source: GridActor, index: int) -> bool:
	if not open_loot(source) or index < 0 or index >= source.loot.size():
		return false
	var item := source.loot[index]
	if not LootData.collectable(self, item):
		add_message("That quest item is no longer eligible.")
		return false
	if not InventoryRules.receive(hero, item):
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


## Best effort, preserving every stack that cannot currently be collected.
func loot_all(source: GridActor) -> bool:
	if not open_loot(source):
		return false
	var collected := loot_money(source)
	var index := 0
	while index < source.loot.size():
		if LootData.collectable(self, source.loot[index]) and loot_item(source, index):
			collected = true
		else:
			index += 1
	return collected


func _hide_empty_corpse(source: GridActor) -> void:
	if source.alive or (source.chest and not source.loot_assigned):
		return
	if source.loot.is_empty() and source.loot_copper == 0:
		source.corpse_visible = false


func receive_starter_gear(merchant: GridActor) -> bool:
	if (starter_gear_received or hero.selected_class != &"Warrior"
		or not valley_route or not QuestRules.in_range(self, merchant, 900003)
		or not trader_in_range(merchant)):
		return false
	if not StarterGear.exchange(hero, &"Warrior"):
		return false
	starter_gear_received = true
	return true


func trader_in_range(merchant: GridActor) -> bool:
	return (merchant != null and actors.has(merchant) and merchant.alive
		and merchant.relationship == GridActor.Relationship.FRIENDLY
		and merchant.service == &"Trader" and interaction_candidates().has(merchant)
		and vendor_stock.has(merchant.spawn_id)
		and not MerchantData.catalog(merchant.npc_id).is_empty())


func buy_item(merchant: GridActor, identifier: int, quantity: int) -> bool:
	if not item_action_ready() or not trader_in_range(merchant) or quantity < 1 or quantity > 1000:
		return false
	var key := str(identifier)
	var catalog := MerchantData.catalog(merchant.npc_id)
	if not catalog.has(key):
		return false
	var stock: Dictionary = vendor_stock[merchant.spawn_id]
	var cost := MerchantData.unit_price(merchant.npc_id, identifier) * quantity
	if cost > hero.copper or (int(stock[key]) >= 0 and quantity > int(stock[key])):
		add_message("Purchase rejected: insufficient money or stock.")
		return false
	if not InventoryRules.receive(hero, ItemData.instance(identifier, quantity)):
		add_message("Purchase rejected: inventory full.")
		return false
	hero.copper -= cost
	if int(stock[key]) >= 0:
		stock[key] -= quantity
	add_message("Bought %s x%d from %s for %s." % [ItemData.get_item(identifier).title,
		quantity, merchant.title, InventoryRules.money(cost)])
	return true


func sell_item(merchant: GridActor, index: int, quantity: int) -> bool:
	if (not item_action_ready() or not trader_in_range(merchant) or index < 0 or index >= 40
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
	add_message("Sold %s x%d to %s for %s." % [data.title, quantity, merchant.title,
		InventoryRules.money(int(data.sell) * quantity)])
	return true


func sell_all_grey(merchant: GridActor) -> bool:
	if not item_action_ready() or not trader_in_range(merchant):
		return false
	var sold := false
	for index in range(hero.inventory.size()):
		var item := hero.inventory[index]
		if item.is_empty():
			continue
		var data := ItemData.get_item(int(item.id))
		if int(data.quality) == 0 and data.tradable:
			if sell_item(merchant, index, int(item.quantity)):
				sold = true
	if not sold:
		add_message("No grey items to sell.")
	return sold


func consume_item(index: int) -> bool:
	if not item_action_ready() or index < 0 or index >= 40 or hero.inventory[index].is_empty():
		return false
	var item := hero.inventory[index]
	var data := ItemData.get_item(int(item.id))
	if data.use == "" or hero.level < int(data.level):
		add_message("Cannot use that item at this level.")
		return false
	var potion: bool = data.use == "health"
	var ready := hero.potion_ready_turn
	if (potion and turn_count < ready) or (not potion and in_combat()):
		add_message("Cannot use: potion cooldown or food/drink during combat.")
		return false
	resolving_turn = true
	if potion:
		var amount := combat_random.randi_range(int(data.restore_min), int(data.restore_max))
		hero.health = mini(hero.max_health, hero.health + amount)
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
		hero.health = mini(hero.max_health, hero.health + amount)
		if elapsed >= int(effect.duration):
			hero.restoration.erase(kind)
