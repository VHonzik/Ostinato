extends "res://bench/priority_sim.gd"

const MechanicsWorld = preload("res://bench/stalker_mechanics_world.gd")
const ENCOUNTER: Dictionary = {
	"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1}
var tuning: Dictionary = {}
var confirm: bool = false
var configurations: Array[Dictionary] = []
var policies: Array[String] = ["ordinary", "react", "bank", "reserve", "spellbank"]


func _initialize() -> void:
	samples = 30
	case_id = "Stalker"
	selected_class = &"Warrior"
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
		elif arg == "confirm":
			confirm = true
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
	if confirm and not smoke:
		samples = 100
	builds = ["Warrior+Shaman+Paladin", "Warrior+Shaman+Rogue",
		"Warrior+Paladin+Rogue", "Shaman+Paladin+Rogue", "All"]
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	configurations = [
		{"id": "live", "enrage": false, "channel": false, "requirement": 0, "heal": 0},
		{"id": "enrage", "enrage": true, "channel": false, "requirement": 0, "heal": 0},
		{"id": "pause", "enrage": true, "channel": true, "requirement": 0, "heal": 0}]
	for requirement in [120, 150, 180]:
		for heal in [180, 240, 300]:
			if heal <= requirement:
				continue
			configurations.append({"id": "%d/%d" % [requirement, heal],
				"enrage": true, "channel": true, "requirement": requirement, "heal": heal})
	if confirm:
		configurations = configurations.filter(func(config: Dictionary) -> bool:
			return config.id in ["live", "150/180", "150/240"])
		policies.assign(["ordinary", "spellbank"])
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	if smoke:
		_check_channel_order()
	for category in builds:
		build = category
		for weapon in range(3):
			if shard >= 0 and weapon != shard:
				continue
			for config in configurations:
				tuning = config
				for policy in policies:
					if not config.channel and policy != "ordinary":
						continue
					var fights: Array[Dictionary] = []
					for index in range(samples):
						var seed_value := (4800000 if confirm else 4600000) + index
						var fight := _battle(ENCOUNTER, weapon, true, true, policy, seed_value, true)
						if index < 2:
							var replay := _battle(ENCOUNTER, weapon, true, true, policy, seed_value, false)
							for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random",
								"channel_started", "channel_damage", "channel_success", "boss_healing"]:
								assert(fight[key] == replay[key], "Mechanics replay mismatch: " + key)
							replayed += 1
						if index >= 2:
							fight.erase("decisions")
							fight.erase("channel_timeline")
						fights.append(fight)
					rows.append({"build": build, "weapon": STYLES[weapon], "config": config,
						"policy": policy, "runs": samples, "fights": fights})
			print("CELL %s %s: %d configurations complete" % [build, STYLES[weapon], configurations.size()])
	var policies_per_weapon := 0
	for config in configurations:
		policies_per_weapon += policies.size() if config.channel else 1
	var setup := {"samples": samples, "confirm": confirm, "configs": configurations,
		"builds": builds,
		"policies": policies, "policies_per_weapon": policies_per_weapon,
		"expected_cells": builds.size() * (3 if shard < 0 else 1) * policies_per_weapon,
		"entry": "Level 5, full named retained kits plus the guaranteed initial Warrior starters (MS/Whirlwind), common gear; real preparation from zero rage, six-tile approach with Charge only when learned, one minor potion. No trainer gifts or banked entry resources. The Shaman/Paladin/Rogue path has no purchased Warrior skills.",
		"mechanics": "Experiment-local: +30% melee damage at <=20% boss HP; once at <=50%, stop movement/melee for four full response turns, replacing the trigger boundary's NPC action too when crossed before NPC phase. Timers continue. All damage sources count after trigger boundary; check after fourth turn's summons; no early interruption. Failed check heals configured HP once, capped at max; never rearms. Death cancels heal. Cone omitted: cadence/geometry undecided.",
		"policy_detail": "Ordinary uses current intent. React has no prebanking but prioritizes first-response Judgement, MS, timely Lava and finisher during channel. Bank shares that response and holds burst/fillers from <=60%. Reserve also holds Lava, Judgement, finisher and Execute from <=70%, using MS above 60%. Spellbank holds only Lava/Judgement from <=70% and MS from <=60%, keeping finishers/Sudden Death/other spending active while preserving enough rage for the known MS/Judge/Lava costs below 60% (free uses and refunding 5-point finishers stay allowed); confirm compares it with ordinary on fresh 4800000+ seeds. All postpone potion during the safe channel; no assigned resources, guaranteed crits or forced hits.",
		"accounting": "Every fight reconciles boss HP including healing and player HP. First two per cell replay on unobserved experimental worlds. The live-labelled control preserves the pre-Fel-Breath baseline; all experimental worlds suppress the subsequently adopted production cone. Shared seeds across candidates; fresh seed range with Confirm.",
		"limits": "Fixed non-optimal bots, fully learned kits, common gear and isolated boss. No cone, route, reinforcement, trainer gifts, uncommon gear or human acceptance."}
	assert(rows.size() == int(setup.expected_cells))
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE stalker-mechanics: %d cells, %d fights, %d replays" % [rows.size(), rows.size() * samples, replayed])
	quit()


func _check_channel_order() -> void:
	# A verdict on the fourth response counts; healing cannot restart the check.
	var world := MechanicsWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), 4599999, false)
	world.tuning = {"channel": true, "enrage": true, "requirement": 42, "heal": 240}
	world.hero.learned_skills.append(SkillDefinition.catalog(&"judgement_1"))
	world._spawn_stalker(world.player_tile + Vector2i.UP)
	world.boss.health = 300
	world.last_boss_health = 300
	world.boss.engaged = true
	world.wait_turn()
	assert(world.channel_started and world.channel_active)
	var initial_hp := world.hero.health
	world.boss.debuffs[&"judgement_1"] = {"until": world.turn_count + 4,
		"damage": 42, "critical": 0}
	for response in range(3):
		world.wait_turn()
		assert(world.channel_active and world.boss_healing == 0)
		assert(world.hero.health == initial_hp)
	world.wait_turn()
	assert(not world.channel_active and world.channel_success)
	assert(world.channel_damage == 42 and world.boss_healing == 0)
	assert(world.hero.health == initial_hp)
	world.discard()
	var failed := MechanicsWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), 4599998, false)
	failed.tuning = {"channel": true, "enrage": true, "requirement": 150, "heal": 240}
	failed._spawn_stalker(failed.player_tile + Vector2i.UP)
	failed.boss.health = 300
	failed.last_boss_health = 300
	failed.wait_turn()
	for response in range(4):
		failed.wait_turn()
	assert(failed.boss_healing == 240 and failed.boss.health == 540)
	failed.boss.health = 200
	failed.last_boss_health = 200
	failed.wait_turn()
	assert(not failed.channel_active and failed.boss_healing == 240)
	failed.discard()


func _create_world(seed_value: int, _traced: bool) -> GridWorld:
	var world := MechanicsWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
	world.tuning = tuning.duplicate()
	return world


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	if hero.find_skill(&"mortal_strike_1") == null:
		hero.learned_skills.append_array(SkillDefinition.starting_skills(&"Warrior"))


func _battle_metrics(world: GridWorld) -> Dictionary:
	if world is MechanicsWorld and (world as MechanicsWorld).watched.is_empty():
		return {}
	return super._battle_metrics(world)


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	var choices := super._priority_choices(world, target, living, "intent")
	if policy == "ordinary":
		return choices
	var experiment := world as MechanicsWorld
	# The pre-breath control has no recovery mechanic to bank against.
	if experiment == null or not tuning.get("channel", false):
		return choices
	var burst: Array[StringName] = [&"mortal_strike_1", &"lava_burst_1", &"judgement_1",
		&"eviscerate_1", &"execute_1", &"whirlwind_1", &"consecration_1"]
	if policy == "spellbank" and not experiment.channel_started:
		var held: Array[StringName] = []
		if target.health * 10 <= target.max_health * 7:
			held.append_array([&"lava_burst_1", &"judgement_1"])
		if target.health * 10 <= target.max_health * 6:
			held.append(&"mortal_strike_1")
		choices = choices.filter(func(id: StringName) -> bool: return id not in held)
		if target.health * 10 <= target.max_health * 6:
			var reserve_rage := 0
			for id in [&"mortal_strike_1", &"judgement_1", &"lava_burst_1"]:
				var skill := world.hero.find_skill(id)
				if skill != null:
					reserve_rage += skill.rage_cost
			var affordable: Array[StringName] = []
			for id in choices:
				var skill := world.hero.find_skill(id)
				if skill == null:
					continue
				var cost := skill.cost(world.hero)
				if (cost == 0 or world.hero.rage - cost >= reserve_rage
					or (id == &"eviscerate_1" and world.hero.combo_points == 5)):
					affordable.append(id)
			choices = affordable
		return choices
	if policy == "reserve" and not experiment.channel_started and target.health * 10 <= target.max_health * 7:
		var held: Array[StringName] = [&"lava_burst_1", &"judgement_1", &"eviscerate_1", &"execute_1"]
		choices = choices.filter(func(id: StringName) -> bool: return id not in held)
	if policy in ["bank", "reserve"] and not experiment.channel_started and target.health * 10 <= target.max_health * 6:
		return choices.filter(func(id: StringName) -> bool: return id not in burst)
	if experiment.channel_active:
		choices = choices.filter(func(id: StringName) -> bool: return id not in burst)
		var payoffs: Array[StringName] = []
		if world.turn_count == experiment.channel_turn:
			payoffs.append(&"judgement_1")
		payoffs.append(&"mortal_strike_1")
		var lava := world.hero.find_skill(&"lava_burst_1")
		if lava != null and ClassToolkitRules.cast_duration(world.hero, lava) <= experiment.channel_deadline - world.turn_count:
			payoffs.append(&"lava_burst_1")
		if world.hero.combo_points == 5 or (world.hero.combo_points > 0 and experiment.channel_deadline - world.turn_count == 1):
			payoffs.append(&"eviscerate_1")
		payoffs.append(&"execute_1")
		if experiment.channel_deadline - world.turn_count > 3:
			payoffs.append(&"judgement_1")
		payoffs.append_array(choices)
		return payoffs
	return choices


func _battle(encounter: Dictionary, weapon: int, prepared: bool, potion: bool,
	policy: String, seed_value: int, traced: bool) -> Dictionary:
	var world := _create_world(seed_value, traced)
	var hero := world.hero
	hero.level = int(encounter.hero_level)
	hero.selected_class = selected_class
	_learn_skills(hero)
	hero.equipment.clear()
	var gear := {"armor": 85, "neck": 70001, "ring_1": 70002,
		"ring_2": 70003, "weapons": WEAPONS[weapon]}
	for slot: String in gear:
		hero.equipment[slot] = ItemData.instance(int(gear[slot]))
	hero.refresh_stats()
	hero.health = hero.max_health
	hero.rage = 0
	hero.inventory[0] = ItemData.instance(118, 1) if potion else {}
	if prepared:
		_prepare(world)
	var entry_turn := world.turn_count
	var enemies: Array[GridActor] = []
	if encounter.profile == "stalker":
		world._spawn_stalker(world.player_tile + Vector2i.UP)
		enemies.append(world.actors[0])
	else:
		var data: Dictionary = NorthshireData.CREATURES[encounter.profile]
		for index in range(int(encounter.count)):
			var enemy := GridActor.new(world.player_tile + GridWorld.DIRECTIONS[index * 2])
			enemy.relationship = GridActor.Relationship.HOSTILE
			enemy.engaged = true
			enemy.max_health = int(data.health) * int(encounter.get("health_scale", 1))
			enemy.health = enemy.max_health
			enemy.melee.level = int(data.level)
			enemy.melee.armor = int(data.armor)
			enemy.melee.damage_min = float(data.minimum)
			enemy.melee.damage_max = float(data.maximum)
			enemy.melee.attack_power = int(data.power)
			enemy.melee.interval = float(data.interval)
			world.actors.append(enemy)
			enemies.append(enemy)
	var initial_hp := 0
	for index in range(enemies.size()):
		enemies[index].title = "Target %d" % index
		enemies[index].awards_experience = false
		initial_hp += enemies[index].health
	if traced:
		(world as PaladinWorld).watch(enemies)
	if encounter.id in ["Pull", "BankedPull"]:
		enemies[0].tile = world.player_tile + Vector2i(0, -6)
		enemies[0].home_tile = enemies[0].tile
		hero.cooldowns["charge"] = 999
		if encounter.id == "BankedPull":
			if hero.find_skill(&"maelstrom_weapon_1") != null:
				hero.buffs[&"maelstrom_weapon_1"] = {"armor": 0, "until": 0, "charges": 5}
	else:
		_open_battle(world, enemies)
	while not world.is_terminal() and world.turn_count < 300:
		var living := enemies.filter(func(enemy: GridActor) -> bool: return enemy.alive)
		if living.is_empty():
			break
		if _try_encounter_action(world, living[0], policy):
			continue
		if world.pending_skill != null:
			world.continue_cast()
			continue
		if world.pending_melee != null:
			world.continue_melee()
			continue
		if (potion and not hero.inventory[0].is_empty() and hero.max_health - hero.health >= 40
			and not (world is MechanicsWorld and (world as MechanicsWorld).channel_active)):
			assert(world.consume_item(0))
			continue
		var target: GridActor = living[0]
		if _try_item_action(world, target):
			continue
		var choices := _priority_choices(world, target, living, policy)
		var acted := false
		for id in choices:
			var skill := hero.find_skill(id)
			if skill == null or skill.cost(hero) > hero.rage:
				continue
			if int(hero.cooldowns.get(String(world.cooldown_family(skill)), 0)) > world.turn_count:
				continue
			if id == &"feral_spirit_1" and world.actors.any(
				func(actor: GridActor) -> bool: return actor.alive and actor.summon_kind == "wolf"):
				continue
			var candidate: GridActor = target if skill.target == SkillDefinition.Target.ENEMY else null
			if not world.valid_spell_target(skill, candidate) or not SpellEffects.can_apply(world, skill, candidate):
				continue
			if world.cast_skill(id, candidate):
				acted = true
				break
		if not acted:
			if world.auto_attack_target != target:
				if not world.request_melee(target):
					var route := world.charge_route(target)
					if route.size() > 1:
						assert(world.move_player(route[1] - world.player_tile))
					else:
						world.wait_turn()
			else:
				var route := world.charge_route(target)
				if GridWorld.tile_distance(world.player_tile, target.tile) > 1 and route.size() > 1:
					assert(world.move_player(route[1] - world.player_tile))
				else:
					world.wait_turn()
	var enemy_hp := 0
	for enemy in enemies:
		enemy_hp += enemy.health
	assert(world.turn_count < 300 or enemy_hp == 0 or hero.health == 0)
	var result := {"seed": seed_value, "win": enemy_hp == 0, "hp": hero.health,
		"enemy_hp": enemy_hp, "turns": world.turn_count - entry_turn,
		"preparation_turns": entry_turn, "rage": hero.rage,
		"combat_random": str(world.combat_random.state)}
	if traced:
		var trace := world as PaladinWorld
		assert(trace.valid_accounting and trace.damage_total == initial_hp + (world as MechanicsWorld).boss_healing - enemy_hp)
		result.merge({"damage": trace.damage.duplicate(true), "damage_total": trace.damage_total,
			"casts": trace.casts.duplicate(), "activations": trace.activations.duplicate()})
	if traced and world is PriorityWorld:
		var observer := world as PriorityWorld
		result.merge({"stack_gains": observer.stack_gains, "full_lava": observer.full_lava,
			"decisions": observer.decision_log, "remaining_stacks": ClassToolkitRules.maelstrom_stacks(hero)})
	result.merge(_battle_metrics(world))
	result.merge((world as MechanicsWorld).encounter_metrics() if world is MechanicsWorld else {"boss_healing": 0, "channel_started": false, "channel_damage": 0, "channel_success": false})
	world.discard()
	return result


func _try_encounter_action(_world: GridWorld, _target: GridActor, _policy: String) -> bool:
	return false
