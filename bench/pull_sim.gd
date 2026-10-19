extends "res://bench/priority_sim.gd"

const PullWorld = preload("res://bench/pull_world.gd")
const COUNTS: Array[int] = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32]
const GREEN_WEAPONS: Array[int] = [70021, 70022, 70023]
var quality: String = "common"
var profile: String = "38"
var entry: String = "prepared"
var seed_base: int = 2300000


func _initialize() -> void:
	samples = 20
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
	build = "All"
	selected_class = &"Warrior"
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	for weapon in range(3):
		if shard >= 0 and weapon != shard:
			continue
		for gear_quality in ["common", "uncommon"]:
			quality = gear_quality
			for policy in ["intent", "aoe"]:
				for count in COUNTS:
					_measure_pull(weapon, count, policy)
		# Controls isolate level/profile, entry momentum and kill-healing dependency.
		quality = "common"
		for control in ["worker", "momentum", "no_victory_rush", "warrior"]:
			entry = control
			profile = "257" if control == "worker" else "38"
			for count in [4, 8, 16, 32]:
				_measure_pull(weapon, count, "aoe")
		entry = "prepared"
		profile = "38"
	if not BenchIO.write_result({"setup": {"samples": samples,
		"counts": COUNTS, "weapons": WEAPONS, "green_weapons": GREEN_WEAPONS,
		"rules": "All four kits retained, level equals real regular mob profile: L4 thug (70 HP, armor 85, 5-7 damage/2.4 turns), L3 worker control (60 HP, armor 65, 4-6/2 turns). Full common or uncommon gear, one strength and one agility ring. No XP, potions or trainer gifts. HP and buffs use live rules.",
		"entry": "Full HP, zero rage, no points/procs/stacks; live poison/Windfury/Shield/Shout preparation. Momentum adds 90 rage and 5 points/5 Maelstrom after prep, explicitly a banked prior-fight scenario. No-Victory-Rush removes only that passive. Warrior retains only full Warrior kit.",
		"geometry": "Open 12x12 arena. Concentric square rings, clockwise starting north; first eight adjacent, others queue outside. All already engaged, swing timers fresh. No kiting. Target lowest HP in melee, otherwise nearest.",
		"policies": "Intent inherits current coordinated bot. AoE: same emergency defenses, but Whirlwind then uncovered Consecration before single-target choices when 3+ adjacent. No policy optimization or claim of a theoretical optimum.",
		"checks": "Every fight reconciles effective enemy damage and player HP/healing. First three seeds per cell replay against plain GridWorld including combat RNG. Per-turn snapshots observe production turns only.",
		"limitations": "Isolated synthetic packs; no gathering cost, obstacles, route, XP/level-up healing, gifts or consumables. Full uncommon availability is an equipment ceiling, not a typical route. 32 is a tested bound, not a proven maximum."},
		"rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE pulls: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _measure_pull(weapon: int, count: int, policy: String) -> void:
	var fights: Array[Dictionary] = []
	for index in range(samples):
		var seed_value := seed_base + count * 1000 + index
		var encounter := {"count": count}
		var fight := _battle(encounter, weapon, true, false, policy, seed_value, true)
		if index < mini(samples, 3):
			var plain := _battle(encounter, weapon, true, false, policy, seed_value, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				assert(fight[key] == plain[key], "Pull replay mismatch: " + key)
			replayed += 1
		else:
			fight.erase("timeline")
			fight.erase("decisions")
		fights.append(fight)
	rows.append({"count": count, "weapon": STYLES[weapon], "quality": quality,
		"profile": profile, "entry": entry, "policy": policy, "fights": fights})
	var wins := 0
	var total_turns := 0
	for fight in fights:
		wins += int(fight.win)
		total_turns += int(fight.turns)
	print("CELL %s %s %s %s %s x%d: %d/%d wins, %.1f turns" % [
		STYLES[weapon], quality, profile, entry, policy, count, wins, samples,
		float(total_turns) / samples])


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	var choices := super._priority_choices(world, target, living, "intent")
	if policy != "aoe":
		return choices
	var adjacent := living.filter(func(enemy: GridActor) -> bool:
		return ClassToolkitRules.eligible(world, enemy, 1)).size()
	if adjacent < 3:
		return choices
	choices.erase(&"whirlwind_1")
	choices.erase(&"consecration_1")
	var position := 0
	while position < choices.size() and choices[position] in [&"divine_shield_1", &"evasion_1"]:
		position += 1
	choices.insert(position, &"whirlwind_1")
	if not PaladinRules.covers(world, world.player_tile):
		choices.insert(position + 1, &"consecration_1")
	return choices


func _battle(encounter: Dictionary, weapon: int, _prepared: bool, _potion: bool,
	policy: String, seed_value: int, traced: bool) -> Dictionary:
	var center := Vector2i(6, 6)
	var bounds := Rect2i(0, 0, 12, 12)
	var world: GridWorld = (PullWorld.new(bounds, center, seed_value, false)
		if traced else GridWorld.new(bounds, center, seed_value, false))
	var hero := world.hero
	var data: Dictionary = NorthshireData.CREATURES[profile]
	hero.level = int(data.level)
	hero.selected_class = selected_class
	build = "Warrior" if entry == "warrior" else "All"
	_learn_skills(hero)
	if entry == "no_victory_rush":
		hero.learned_skills = hero.learned_skills.filter(func(skill: SkillDefinition) -> bool:
			return skill.id != &"victory_rush_1")
	hero.equipment.clear()
	var ids: Array = ([85, 70001, 70002, 70003, WEAPONS[weapon]]
		if quality == "common" else [2572, 70011, 70012, 70013, GREEN_WEAPONS[weapon]])
	for index in range(ids.size()):
		hero.equipment[["armor", "neck", "ring_1", "ring_2", "weapons"][index]] = ItemData.instance(ids[index])
	hero.refresh_stats()
	hero.health = hero.max_health
	hero.rage = 0
	_prepare(world)
	if entry == "momentum":
		hero.rage = 90
		hero.combo_points = 5
		hero.buffs[&"maelstrom_weapon_1"] = {"armor": 0, "until": 0, "charges": 5}
	var entry_turn := world.turn_count
	var stats := {"hp": hero.max_health, "armor": hero.melee.armor,
		"dodge": hero.melee.dodge, "crit": hero.melee.critical,
		"haste": hero.attack_haste(), "weapon": MeleeRules.weapon_damage(hero.melee, 0.5),
		"rage": hero.rage}
	var tiles: Array[Vector2i] = []
	for radius in range(1, 5):
		# Clockwise around each ring, beginning directly north.
		for x in range(0, radius): tiles.append(center + Vector2i(x, -radius))
		for y in range(-radius, radius): tiles.append(center + Vector2i(radius, y))
		for x in range(radius, -radius, -1): tiles.append(center + Vector2i(x, radius))
		for y in range(radius, -radius, -1): tiles.append(center + Vector2i(-radius, y))
		for x in range(-radius, 0): tiles.append(center + Vector2i(x, -radius))
	var enemies: Array[GridActor] = []
	for index in range(int(encounter.count)):
		var enemy := GridActor.new(tiles[index])
		enemy.title = "Target %d" % index
		enemy.relationship = GridActor.Relationship.HOSTILE
		enemy.engaged = true
		enemy.awards_experience = false
		enemy.max_health = int(data.health)
		enemy.health = enemy.max_health
		enemy.melee.level = int(data.level)
		enemy.melee.armor = int(data.armor)
		enemy.melee.damage_min = float(data.minimum)
		enemy.melee.damage_max = float(data.maximum)
		enemy.melee.attack_power = int(data.power)
		enemy.melee.interval = float(data.interval)
		world.actors.append(enemy)
		enemies.append(enemy)
	if traced:
		(world as PullWorld).watch(enemies)
	while not world.is_terminal() and world.turn_count - entry_turn < 1000:
		var living := enemies.filter(func(enemy: GridActor) -> bool: return enemy.alive)
		if living.is_empty(): break
		if world.pending_skill != null:
			world.continue_cast()
			continue
		if world.pending_melee != null:
			world.continue_melee()
			continue
		living.sort_custom(func(a: GridActor, b: GridActor) -> bool:
			var da := GridWorld.tile_distance(world.player_tile, a.tile)
			var db := GridWorld.tile_distance(world.player_tile, b.tile)
			return a.health < b.health if da <= 1 and db <= 1 else da < db)
		var target: GridActor = living[0]
		var acted := false
		for id in _priority_choices(world, target, living, policy):
			var skill := hero.find_skill(id)
			if skill == null or skill.cost(hero) > hero.rage: continue
			if int(hero.cooldowns.get(String(world.cooldown_family(skill)), 0)) > world.turn_count: continue
			if id == &"feral_spirit_1" and world.actors.any(func(actor: GridActor) -> bool:
				return actor.alive and actor.summon_kind == "wolf"): continue
			var candidate: GridActor = target if skill.target == SkillDefinition.Target.ENEMY else null
			if not world.valid_spell_target(skill, candidate) or not SpellEffects.can_apply(world, skill, candidate): continue
			if world.cast_skill(id, candidate):
				acted = true
				break
		if not acted:
			if world.auto_attack_target != target and world.request_melee(target): continue
			var route := world.charge_route(target)
			if GridWorld.tile_distance(world.player_tile, target.tile) > 1 and route.size() > 1:
				assert(world.move_player(route[1] - world.player_tile))
			else:
				world.wait_turn()
	var enemy_hp := 0
	var kills := 0
	for enemy in enemies:
		enemy_hp += enemy.health
		kills += int(not enemy.alive)
	var result := {"seed": seed_value, "win": enemy_hp == 0, "hp": hero.health,
		"enemy_hp": enemy_hp, "kills": kills, "turns": world.turn_count - entry_turn,
		"preparation_turns": entry_turn, "rage": hero.rage, "stats": stats,
		"combat_random": str(world.combat_random.state)}
	assert(result.turns < 1000, "Pull timed out")
	if traced:
		var observer := world as PullWorld
		assert(observer.valid_accounting)
		assert(observer.damage_total == int(data.health) * int(encounter.count) - enemy_hp)
		result.merge(observer.metrics())
		result.merge({"damage": observer.damage, "damage_total": observer.damage_total,
			"casts": observer.casts, "decisions": observer.decision_log,
			"timeline": observer.timeline})
		var previous := 0
		var peak := 0
		var minimum_hp := hero.max_health
		for tick in observer.timeline:
			peak = maxi(peak, int(tick.taken) - previous)
			previous = int(tick.taken)
			minimum_hp = mini(minimum_hp, int(tick.hp))
		result.merge({"peak_taken": peak, "minimum_hp": minimum_hp})
	world.discard()
	return result
