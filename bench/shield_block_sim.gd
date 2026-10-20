extends "res://bench/stalker_full_sim.gd"
## Keep the separate block stream for paired candidate comparisons after the live unlock.

const BlockWorld = preload("res://bench/shield_block_world.gd")
const BLOCK_CASES: Array[Dictionary] = [
	{"id": "3xL4", "hero_level": 3, "profile": "38", "count": 3},
	{"id": "2xL5", "hero_level": 3, "profile": "103", "count": 2},
	{"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1},
]
var trial_block: bool = false


func _initialize() -> void:
	samples = 400
	if OS.get_cmdline_user_args().has("smoke"):
		smoke = true
		samples = 3
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	selected_class = &"Warrior"
	gifts = false
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	for category in ["Warrior", "All"]:
		build = category
		for encounter in BLOCK_CASES:
			if build == "Warrior" and encounter.id == "Stalker":
				continue
			if build == "All" and encounter.id != "Stalker":
				continue
			case_id = encounter.id
			for prepared in [false, true]:
				for weapon in range(3):
					for enabled in [false, true]:
						if enabled and weapon != 1:
							continue
						trial_block = enabled
						_measure_block(encounter, weapon, prepared)
	var setup := {"samples": samples, "cases": BLOCK_CASES,
		"rule": "Shield equipped: independent 30% roll per positive physical NPC hit after current mitigation; remove 70%, ceil remaining HP. No facing restriction or per-turn cap; no summon protection or magic block.",
		"rng": "Combat seed 3100000 + encounter_index*10000 + sample. Independent block-only stream seeded combat_seed + 9100000. Baseline consumes no extra combat RNG; disabled first three seeds replay exactly on plain GridWorld. Block runs first three seeds replay deterministically in experiment world.",
		"entry": "Common quest weapons and armor/accessories, native full Warrior or all four fully learned kits except the live Shield Block passive, which is removed to prevent double application. Cold/live prepared entry, no banked rage/points/procs. Warrior uses its native spend rotation and opening attack bump; all kits use coordinated intent. One potion against Stalker; no trainer gifts, XP, route or reinforcements.",
		"limits": "Controlled candidate comparison with an independent block stream. Fixed bot; not unlock pacing or human balance acceptance. Experiment copies production turn/NPC attack paths to insert block before lethal damage. No game data is changed by the experiment."}
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE shield-block: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _measure_block(encounter: Dictionary, weapon: int, prepared: bool) -> void:
	var fights: Array[Dictionary] = []
	for index in range(samples):
		var seed_value := 3100000 + BLOCK_CASES.find(encounter) * 10000 + index
		var fight := _battle(encounter, weapon, prepared, case_id == "Stalker",
			"intent", seed_value, true)
		if index < 3:
			var replay := _battle(encounter, weapon, prepared, case_id == "Stalker",
				"intent", seed_value, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				assert(fight[key] == replay[key], "Block experiment replay mismatch: " + key)
			replayed += 1
		if index >= 3:
			fight.erase("decisions")
		fights.append(fight)
	rows.append({"build": build, "case": case_id, "weapon": STYLES[weapon],
		"prepared": prepared, "block": trial_block, "runs": samples, "fights": fights})
	var wins := fights.filter(func(fight: Dictionary) -> bool: return fight.win).size()
	print("CELL %s %s %s prepared=%s block=%s: %d/%d wins" % [
		build, case_id, STYLES[weapon], prepared, trial_block, wins, samples])


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	if not traced and not trial_block:
		return GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
	var world := BlockWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
	world.block_enabled = trial_block
	world.block_random.seed = seed_value + 9100000
	return world


func _battle_metrics(world: GridWorld) -> Dictionary:
	# Active replays need the experiment world but deliberately omit health observation.
	if world is BlockWorld and (world as BlockWorld).watched.is_empty():
		return {}
	return super._battle_metrics(world)


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	hero.learned_skills = hero.learned_skills.filter(func(skill: SkillDefinition) -> bool:
		return skill.id != &"shield_block_1")


func _open_battle(world: GridWorld, enemies: Array[GridActor]) -> void:
	if build == "Warrior" and case_id != "Stalker":
		assert(world.request_melee(enemies[0]))
	else:
		super._open_battle(world, enemies)


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	if build != "Warrior":
		return super._priority_choices(world, target, living, policy)
	var choices: Array[StringName] = [&"execute_1"]
	if not world.hero.buffs.has(&"battle_shout_1"):
		choices.append(&"battle_shout_1")
	if world.hero.buffs.has(&"juggernaut_1"):
		choices.append(&"mortal_strike_1")
	if living.size() > 1:
		choices.append(&"whirlwind_1")
	choices.append_array([&"mortal_strike_1", &"whirlwind_1"])
	if world.auto_attack_target != target:
		choices = [&"execute_1", &"mortal_strike_1"]
	return choices
