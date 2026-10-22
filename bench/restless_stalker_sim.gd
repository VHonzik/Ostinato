extends "res://bench/stalker_full_sim.gd"
## Only Restless Blades learning differs between each matched pair.

const TraceWorld = preload("res://bench/restless_trace_world.gd")


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	return (TraceWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
		if traced else GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false))


func _initialize() -> void:
	build = "All"
	selected_class = &"Warrior"
	case_id = "Stalker"
	gifts = false
	samples = 100
	if OS.get_cmdline_user_args().has("smoke"):
		smoke = true
		samples = 2
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	if smoke: StalkerDodge.check_live_response()
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	for weapon in range(3):
		for enabled in [true, false]:
			disabled.clear()
			if not enabled: disabled.append(&"restless_blades_1")
			var fights: Array[Dictionary] = []
			for index in range(samples):
				var fight := _battle(STALKER, weapon, true, true, "intent", 6300000 + index, true)
				assert(int(fight.breath_exposures) == 0, "Normal Stalker bot must leave every breath cone")
				if index < mini(3, samples):
					var plain := _battle(STALKER, weapon, true, true, "intent", 6300000 + index, false)
					for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
						assert(fight[key] == plain[key], "Restless Stalker replay: " + key)
					replayed += 1
				if index >= 3: fight.erase("decisions")
				fights.append(fight)
			rows.append({"case": "Stalker", "weapon": STYLES[weapon], "quality": "common",
				"policy": "intent", "restless": enabled, "initial_enemy_hp": 600, "fights": fights})
	if not BenchIO.write_result({"setup": {"samples": samples, "seed_base": 6300000,
		"breath_response": "sidestep",
		"entry": "Live L5 hero against production L8 Stalker, all four kits, complete common gear, live zero-rage preparation, Charge from six tiles. One minor healing potion; no gifts, banked points/stacks or XP.",
		"policy": "Priority intent bot, unchanged for removal. React to a marked Fel Breath cone immediately with one live movement action, preferring a lateral landing in melee. Respect movement credit; cancel interruptible casts/attack commitments to dodge, and never walk back into a pending cone. No Vanish or general kiting. Emergency Divine Shield/Evasion and wolves remain available. This measures total passive contribution to the fixed rotation, not optimal play.",
		"checks": "Enemy and player HP/healing accounting every fight; first three seeds per cell replay on plain GridWorld including final combat RNG. Same 100 seed blocks across states and weapons; streams can diverge after removal."},
		"rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE Restless Stalker: %d fights, %d replays" % [rows.size() * samples, replayed])
	quit()
