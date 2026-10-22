extends "res://bench/pull_sim.gd"

var restless_enabled: bool = true


func _initialize() -> void:
	build = "All"
	selected_class = &"Warrior"
	samples = 100
	if OS.get_cmdline_user_args().has("smoke"):
		smoke = true
		samples = 2
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	for weapon in range(3):
		for gear_quality in ["common", "uncommon"]:
			quality = gear_quality
			for enabled in [true, false]:
				restless_enabled = enabled
				var fights: Array[Dictionary] = []
				for index in range(samples):
					var fight := _battle({"count": 16}, weapon, true, false, "intent", 6400000 + index, true)
					if index < mini(3, samples):
						var plain := _battle({"count": 16}, weapon, true, false, "intent", 6400000 + index, false)
						for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
							assert(fight[key] == plain[key], "Restless pull replay: " + key)
						replayed += 1
					if index >= 3:
						fight.erase("timeline")
						fight.erase("decisions")
					fights.append(fight)
				rows.append({"case": "AoE16", "weapon": STYLES[weapon], "quality": quality,
					"policy": "intent", "restless": enabled, "initial_enemy_hp": 1120, "fights": fights})
	if not BenchIO.write_result({"setup": {"samples": samples, "seed_base": 6400000,
		"entry": "Live L4 hero versus sixteen L4 70-HP thugs, all four kits, complete common/uncommon gear. Live zero-rage maintenance preparation, no points/stacks banked. Open concentric rings, at most eight adjacent. No XP, potions or gifts.",
		"policy": "Existing coordinated intent policy, unchanged after removal: emergency defenses, full Lava/empowered Judgement/5CP finisher before ordinary cleave and other actions. Wolves and all defenses available. No Vanish strategy, kiting or policy optimization. Only Restless Blades is removed.",
		"checks": "Enemy and player HP/healing accounting every fight; first three seeds per cell replay on plain GridWorld including final combat RNG. Same 100 seed blocks across states/weapons/gear, not independent samples across strata."},
		"rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE Restless pulls: %d fights, %d replays" % [rows.size() * samples, replayed])
	quit()


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	if not restless_enabled:
		hero.learned_skills = hero.learned_skills.filter(func(skill: SkillDefinition) -> bool:
			return skill.id != &"restless_blades_1")
