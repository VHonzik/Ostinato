extends "res://bench/pull_sim.gd"
## Candidate numbers live only on this experiment's learned skill instances.

const CANDIDATES: Array[Dictionary] = [
	{"id": "split_cd3", "whirlwind": 35, "ground": 7.5, "healing": 10, "cooldown": 3},
	{"id": "split_cd4", "whirlwind": 35, "ground": 7.5, "healing": 10, "cooldown": 4},
	{"id": "split_cd5", "whirlwind": 35, "ground": 7.5, "healing": 10, "cooldown": 5},
	{"id": "split_cd6", "whirlwind": 35, "ground": 7.5, "healing": 10, "cooldown": 6},
	{"id": "split_cd8", "whirlwind": 35, "ground": 7.5, "healing": 10, "cooldown": 8},
	{"id": "more_ground_cd5", "whirlwind": 25, "ground": 9.0, "healing": 10, "cooldown": 5},
	{"id": "more_ground_cd6", "whirlwind": 25, "ground": 9.0, "healing": 10, "cooldown": 6},
	{"id": "more_ground_cd8", "whirlwind": 25, "ground": 9.0, "healing": 10, "cooldown": 8},
]
var candidate: Dictionary = {}
var defense: String = "emergency"
var confirm: bool = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "confirm": confirm = true
		elif arg == "smoke": smoke = true
		elif arg.begins_with("shard="): shard = int(arg.trim_prefix("shard="))
	samples = 40 if confirm else 10
	if smoke: samples = 2
	seed_base = 2800000 if confirm else 2700000
	selected_class = &"Warrior"
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	var variants: Array = [{"id": "live"}] if confirm else CANDIDATES
	var policies: Array = ["none", "emergency", "proactive"] if confirm else ["emergency"]
	for variant in variants:
		candidate = variant
		print("CANDIDATE ", candidate.id)
		for weapon in range(3):
			if shard >= 0 and weapon != shard: continue
			for gear_quality in ["common", "uncommon"]:
				quality = gear_quality
				for defense_policy in policies:
					defense = defense_policy
					for count in [8, 16, 32]:
						_measure_pull(weapon, count, "aoe")
						rows[-1].candidate = candidate.id
						rows[-1].defense = defense
				if confirm and weapon == 0:
					defense = "proactive"
					_measure_pull(weapon, 64, "aoe")
					rows[-1].candidate = candidate.id
					rows[-1].defense = defense
	if not BenchIO.write_result({"setup": {"samples": samples,
		"expected_cells": rows.size(),
		"confirm": confirm, "seed_base": seed_base, "candidates": variants,
		"rules": "Same prepared L4 regular-thug arena and gear as pulls. No cold entries. Whirlwind cannot trigger Sweeping Strikes. Candidate values modify learned definitions only; confirm uses actual game data. Wrecking Crew's new Whirlwind bonus applies only while its crit buff is active. No gifts, potions or XP.",
		"defenses": "Emergency inherits the prior policy. None removes Divine Shield/Evasion choices. Proactive prioritizes Evasion whenever available, with Divine Shield below half HP; avoids overlapping either defense. Other rotation unchanged.",
		"accounting": "Effective damage and HP/healing reconciled each fight; first three seeds per cell replay on plain GridWorld. Pilot and confirmation seeds are separate. Fixed bots do not establish an optimal or universal pull limit."},
		"rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE pull-tuning: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	if not confirm:
		hero.find_skill(&"wrecking_crew_1").whirlwind_percent = int(candidate.whirlwind)
		hero.find_skill(&"consecration_1").periodic_damage = float(candidate.ground)
		hero.find_skill(&"victory_rush_1").minimum = int(candidate.healing)
		hero.find_skill(&"victory_rush_1").cooldown_seconds = int(candidate.cooldown)


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	var choices := super._priority_choices(world, target, living, policy)
	if defense == "emergency": return choices
	choices.erase(&"evasion_1")
	choices.erase(&"divine_shield_1")
	if defense == "proactive" and living.size() >= 3 \
		and not world.hero.buffs.has(&"evasion_1") \
		and not world.hero.buffs.has(&"divine_shield_1"):
		choices.push_front(&"evasion_1")
		if world.hero.health * 2 < world.hero.max_health:
			choices.push_front(&"divine_shield_1")
	return choices
