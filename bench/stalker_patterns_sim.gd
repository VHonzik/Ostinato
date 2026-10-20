extends "res://bench/stalker_mechanics_sim.gd"

const PatternWorld = preload("res://bench/stalker_patterns_world.gd")
const PATTERN_POLICIES: Array[String] = ["spend", "late", "finish", "defense", "ranged", "shield", "ignore"]
var after_breath_only: bool = false


func _initialize() -> void:
	samples = 20
	case_id = "Stalker"
	selected_class = &"Warrior"
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
		elif arg == "confirm":
			confirm = true
		elif arg == "policy=after-breath":
			after_breath_only = true
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
	if confirm and not smoke:
		samples = 60
	builds = ["Warrior+Shaman+Paladin", "Warrior+Shaman+Rogue",
		"Warrior+Paladin+Rogue", "Shaman+Paladin+Rogue"]
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	configurations = [
		{"id": "live", "enrage": false, "channel": false, "cone": false},
		{"id": "enrage", "enrage": true, "channel": false, "cone": false},
		{"id": "cone", "enrage": false, "channel": false, "cone": true},
		{"id": "enrage-cone", "enrage": true, "channel": false, "cone": true},
		{"id": "full", "enrage": true, "channel": true, "cone": true,
			"requirement": 150, "heal": 180}]
	if not confirm:
		for gap in [8, 12]:
			configurations.append({"id": "gap-%d" % gap, "enrage": true,
				"channel": false, "cone": true, "cone_gap": gap})
	if after_breath_only:
		configurations = configurations.filter(func(config: Dictionary) -> bool:
			return config.id in ["enrage-cone", "full"])
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _cell_policies(config: Dictionary) -> Array[String]:
	if after_breath_only:
		return ["spend", "after-breath"] if config.id == "full" else ["after-breath"]
	if config.id in ["live", "enrage"]:
		return ["spend", "finish", "defense"]
	if config.id == "cone":
		return ["spend", "late"]
	if config.id == "full":
		return ["late", "recovery"]
	if String(config.id).begins_with("gap-"):
		return ["late"]
	return PATTERN_POLICIES


func _run() -> void:
	if smoke:
		_check_channel_order()
		_check_cone()
	for category in builds:
		build = category
		for weapon in range(3):
			if shard >= 0 and weapon != shard:
				continue
			for config in configurations:
				tuning = config
				for policy in _cell_policies(config):
					var fights: Array[Dictionary] = []
					for index in range(samples):
						var seed_value := (5100000 if confirm else 5000000) + index
						var fight := _battle(ENCOUNTER, weapon, true, true, policy, seed_value, true)
						if index < 2:
							var replay := _battle(ENCOUNTER, weapon, true, true, policy, seed_value, false)
							for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random",
								"boss_healing", "channel_damage"]:
								assert(fight[key] == replay[key], "Pattern replay mismatch: " + key)
							if config.id != "live":
								for key in ["cone_casts", "cone_hits", "cone_pet_kills"]:
									assert(fight[key] == replay[key], "Cone replay mismatch: " + key)
							replayed += 1
						if index >= 2:
							fight.erase("decisions")
							fight.erase("channel_timeline")
							fight.erase("cone_trace")
						fights.append(fight)
					rows.append({"build": build, "weapon": STYLES[weapon], "config": config,
						"policy": policy, "runs": samples, "fights": fights})
			print("CELL %s %s complete" % [build, STYLES[weapon]])
	var policies_per_weapon := 0
	for config in configurations:
		policies_per_weapon += _cell_policies(config).size()
	var setup := {"samples": samples, "builds": builds, "configs": configurations,
		"baseline_policy": "spend",
		"policies_per_weapon": policies_per_weapon,
		"expected_cells": builds.size() * (3 if shard < 0 else 1) * policies_per_weapon,
		"entry": "Level 5, common gear, all four fully learned three-kit combinations plus retained Warrior starters. Live zero-rage preparation, six-tile approach/Charge if learned, one potion. No gifts, assigned procs or banked entry resources.",
		"cone": "Locked 90-degree cone, Chebyshev range 3, sight blocked by terrain. Two full player response turns. Boss stops movement/melee on announcement and both responses; weapon timer resets to a full interval and pauses until release. First after four eligible normal boss turns, then ten normal turns between casts; wind-up, recovery, Vanish and Charge-held turns do not count. No overlapping casts. Fixed 60 Fire damage with level scaling, Enrage and live defenses; no crit/dodge. Hits friendly summons too; player at full common-geared level-5 HP survives even during Enrage.",
		"policies": "Spend sidesteps immediately and uses ordinary priorities. Late spends the first warning action, dodging on the final response; long casts are cancelled if needed. Finish saves Lava from 35% and MS from 30% until <=20%, keeping Judgement/finishers going. Defense saves Shield/Evasion/wolves for <=20% unless player HP<20%. Ranged saves full Lava briefly when cone is close, takes a second safe step out of melee, then releases ranged burst. Shield saves Divine Shield to stand in a cone if ready; otherwise dodges. Ignore never dodges. Full/recovery uses the earlier spellbank policy; full/late does not bank for healing. After-breath sidesteps immediately, delays wolves until the first breath resolves, prioritizes them just after later breaths if available, and avoids using Shield/Evasion during a safe cone wind-up or recovery channel. All use real movement, casts and timers; invalid options fall back normally.",
		"limits": "Open arena, fixed non-optimal bots; no route, uncommon gear, trainer gifts, Earth Elemental or Vanish strategy. Seed blocks shared across builds/weapons; paired comparisons are exploratory. Timing/geometry tests verify behavior, not readability or human balance."}
	assert(rows.size() == int(setup.expected_cells))
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE stalker-patterns: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _create_world(seed_value: int, _traced: bool) -> GridWorld:
	var world := PatternWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
	world.tuning = tuning.duplicate()
	return world


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	var choices := super._priority_choices(world, target, living,
		"spellbank" if policy == "recovery" else "ordinary")
	var experiment := world as PatternWorld
	if policy == "after-breath" and experiment != null:
		if experiment.cone_impacts == 0 or experiment.cone_active:
			choices.erase(&"feral_spirit_1")
		elif experiment.normal_turns <= 2:
			choices.erase(&"feral_spirit_1")
			choices.push_front(&"feral_spirit_1")
		if experiment.cone_active or experiment.channel_active:
			choices.erase(&"divine_shield_1")
			choices.erase(&"evasion_1")
	if policy == "finish" and target.health * 5 > target.max_health:
		if target.health * 100 <= target.max_health * 35:
			choices.erase(&"lava_burst_1")
		if target.health * 10 <= target.max_health * 3:
			choices.erase(&"mortal_strike_1")
	elif policy == "finish":
		choices.erase(&"lava_burst_1")
		choices.erase(&"mortal_strike_1")
		choices.erase(&"execute_1")
		choices.push_front(&"mortal_strike_1")
		choices.push_front(&"execute_1")
		if ClassToolkitRules.maelstrom_stacks(world.hero) == 5:
			choices.push_front(&"lava_burst_1")
	if policy == "defense" and target.health * 5 > target.max_health and world.hero.health * 5 >= world.hero.max_health:
		for id in [&"divine_shield_1", &"evasion_1", &"feral_spirit_1"]:
			choices.erase(id)
	elif policy == "defense" and target.health * 5 <= target.max_health:
		choices.erase(&"feral_spirit_1")
		choices.push_front(&"feral_spirit_1")
		choices.push_front(&"evasion_1")
		choices.push_front(&"divine_shield_1")
	if world.hero.buffs.has(&"divine_shield_1"):
		choices.erase(&"evasion_1")
	if world.hero.buffs.has(&"evasion_1"):
		choices.erase(&"divine_shield_1")
	for id in [&"divine_shield_1", &"evasion_1"]:
		if world.hero.buffs.has(id):
			choices.erase(id)
	if policy == "shield":
		choices.erase(&"divine_shield_1")
	if policy == "ranged" and experiment != null:
		if not experiment.cone_active and experiment.normal_turns >= 7:
			choices.erase(&"lava_burst_1")
		if GridWorld.tile_distance(world.player_tile, target.tile) > 1 and ClassToolkitRules.maelstrom_stacks(world.hero) == 5:
			choices.push_front(&"lava_burst_1")
	if (experiment != null and experiment.cone_active and policy != "ignore"
		and experiment.threatens(world.player_tile) and not world.hero.buffs.has(&"divine_shield_1")):
		var remaining := experiment.cone_deadline - world.turn_count
		choices = choices.filter(func(id: StringName) -> bool:
			var skill := world.hero.find_skill(id)
			return skill == null or ClassToolkitRules.cast_duration(world.hero, skill) < remaining)
	return choices


func _try_encounter_action(world: GridWorld, target: GridActor, policy: String) -> bool:
	var experiment := world as PatternWorld
	if experiment == null or not experiment.cone_active or policy == "ignore":
		return false
	var remaining := experiment.cone_deadline - world.turn_count
	if policy == "shield" and remaining == 1 and experiment.threatens(world.player_tile):
		var shield := world.hero.find_skill(&"divine_shield_1")
		if (shield != null and shield.cost(world.hero) <= world.hero.rage
			and int(world.hero.cooldowns.get("divine_shield", 0)) <= world.turn_count):
			_cancel_for_dodge(experiment)
			return world.cast_skill(shield.id)
	if policy == "shield" and world.hero.buffs.has(&"divine_shield_1"):
		return false
	var wide := policy == "ranged"
	var unsafe := experiment.threatens(world.player_tile)
	if not unsafe and (not wide or GridWorld.tile_distance(world.player_tile, target.tile) > 1):
		return false
	if policy in ["late", "finish", "defense", "shield", "recovery"] and remaining > 1:
		# Wait only if a one-action escape is currently available; pets can block it.
		if _safe_step(experiment, false, 1) != Vector2i.ZERO:
			return false
	if world.is_charging():
		return false
	var direction := _safe_step(experiment, wide and not unsafe, remaining)
	if direction == Vector2i.ZERO:
		return false
	_cancel_for_dodge(experiment)
	experiment.dodge_steps += 1
	return world.move_player(direction)


func _cancel_for_dodge(world: GridWorld) -> void:
	if world.pending_melee != null:
		world.cancel_melee()
	if world.pending_skill != null:
		(world as PatternWorld).cancelled_casts += 1
		world.cancel_cast()


func _safe_step(world: GridWorld, wide: bool, remaining: int = 2) -> Vector2i:
	var experiment := world as PatternWorld
	var best := Vector2i.ZERO
	var score := -100000
	for direction in GridWorld.DIRECTIONS:
		var tile := world.player_tile + direction
		if not world.is_open(tile) or experiment.threatens(tile):
			continue
		var distance := GridWorld.tile_distance(tile, experiment.boss.tile)
		var candidate := distance if wide else -absi(distance - 1)
		if candidate > score:
			score = candidate
			best = direction
	if best == Vector2i.ZERO and remaining > 1:
		for first in GridWorld.DIRECTIONS:
			var intermediate := world.player_tile + first
			if not world.is_open(intermediate):
				continue
			for second in GridWorld.DIRECTIONS:
				var destination := intermediate + second
				if world.is_open(destination) and not experiment.threatens(destination):
					return first
	return best


func _check_cone() -> void:
	var world := PatternWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), 4999999, false)
	world.tuning = {"cone": true, "enrage": true}
	world._spawn_stalker(world.player_tile + Vector2i.UP)
	world.boss.engaged = true
	world.boss.melee.damage_min = 0
	world.boss.melee.damage_max = 0
	world.boss.melee.attack_power = 0
	for turn in range(5):
		world.wait_turn()
	assert(world.cone_active and world.cone_deadline == world.turn_count + 2)
	assert(world.threatens(world.player_tile))
	assert(not world.threatens(world.cone_origin - world.cone_direction))
	assert(not world.threatens(world.cone_origin + world.cone_direction * 4))
	var health := world.hero.health
	var direction := _safe_step(world, false)
	assert(direction != Vector2i.ZERO and world.move_player(direction))
	assert(world.cone_active and world.cone_impacts == 0)
	world.wait_turn()
	assert(not world.cone_active and world.cone_impacts == 1 and world.cone_hits == 0)
	assert(world.hero.health == health)
	for turn in range(10):
		world.wait_turn()
	assert(world.cone_casts == 1, "Ten full normal turns separate wind-ups.")
	world.wait_turn()
	assert(world.cone_casts == 2)
	world.discard()
	var hit := PatternWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), 4999998, false)
	hit.tuning = {"cone": true, "enrage": true}
	hit.hero.level = 5
	hit.hero.equipment["armor"] = ItemData.instance(85)
	hit.hero.equipment["neck"] = ItemData.instance(70001)
	hit.hero.equipment["ring_1"] = ItemData.instance(70002)
	hit.hero.equipment["ring_2"] = ItemData.instance(70003)
	hit.hero.refresh_stats()
	hit.hero.health = hit.hero.max_health
	hit._spawn_stalker(hit.player_tile + Vector2i.UP)
	hit.boss.health = 120
	hit.boss.engaged = true
	hit.normal_turns = 4
	hit.add_message("Fixture: begin enraged cone.")
	hit.wait_turn()
	hit.wait_turn()
	hit.wait_turn()
	assert(hit.cone_hits == 1 and hit.hero.health > 0)
	assert(hit.cone_damage > hit.hero.max_health / 2)
	hit.discard()
