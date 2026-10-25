extends "res://bench/priority_sim.gd"
## Read-only rage pressure with retained learning and live actions.

const RageTrace = preload("res://bench/rage_trace.gd")
const RageHero = preload("res://bench/rage_hero.gd")
const RAGE_BUILDS: Array[String] = ["Warrior", "WR partial", "Warrior+Rogue",
	"Warrior+Shaman+Rogue", "Warrior+Paladin+Rogue", "All"]
const RAGE_CASES: Array[Dictionary] = [
	{"id": "1xL4", "hero_level": 4, "profile": "38", "count": 1},
	{"id": "3xL4", "hero_level": 4, "profile": "38", "count": 3},
	{"id": "4xL4", "hero_level": 4, "profile": "38", "count": 4},
	{"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1}]

var rage_build: String = ""
var banked: bool = false
var spend_policy: String = "reserve"
var confirm: bool = false


func _initialize() -> void:
	samples = 100
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
		elif arg.begins_with("policy="):
			spend_policy = arg.trim_prefix("policy=")
		elif arg == "confirm":
			confirm = true
	assert(spend_policy in ["reserve", "spend"])
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	selected_class = &"Warrior"
	call_deferred("_run")


func _run() -> void:
	StalkerDodge.check_live_response()
	for category in RAGE_BUILDS:
		rage_build = category
		build = "Warrior+Rogue" if category == "WR partial" else category
		for weapon in range(3):
			if shard >= 0 and weapon != shard:
				continue
			for entry in [false, true]:
				banked = entry
				if banked and category not in ["WR partial", "All"]:
					continue
				for encounter in RAGE_CASES:
					if banked and encounter.id not in ["4xL4", "Stalker"]:
						continue
					case_id = encounter.id
					_measure_rage(encounter, weapon)
	var setup := {"samples": samples,
		"expected_cells": 28 * (3 if shard < 0 else 1),
		"policy": spend_policy, "confirm": confirm, "builds": RAGE_BUILDS, "cases": RAGE_CASES,
		"variants": ["live"], "stalker": NorthshireData.STALKER,
		"entry": "Common gear; live maintenance from zero rage, no health refill. "
			+ "Banked cells set 90 rage after preparation. No banked points/procs/stacks. "
			+ "Stalker: six-tile Charge, one minor potion, real breath sidesteps. "
			+ "No gifts, Vanish, route, reinforcements or XP.",
		"partial": "Full Warrior and Rogue without Bandit's Guile and Precision.",
		"rotation": "Production intent at five points; reserve only uses single-target "
			+ "WW at 45+ rage. Spend allows it whenever affordable. Other priorities fixed.",
		"metrics": "Decision blocking counts only skills otherwise ready and valid, "
			+ "before filtering affordability. Counts any blocked option and zero affordable "
			+ "options separately. Turn samples include charge, dodge and potion actions. "
			+ "Cap loss includes fractional credit discarded at the cap; sources are "
			+ "accepted integer rage. Every fight reconciles resources and both sides' HP.",
		"seeds": "%d + sample, paired across cells; paths/RNG can diverge."
			% _seed_base(),
		"checks": "First three seeds/cell replay on plain production GridWorld. "
			+ "Compare HP, rage, turns, outcome, RNG.",
		"limits": "Fixed bots and isolated encounters; exploratory, not optimal play "
			+ "or human balance acceptance. No production mechanics changed."}
	assert(rows.size() == int(setup.expected_cells))
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed}):
		quit(1)
		return
	print("COMPLETE rage: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _seed_base() -> int:
	return 7400000 if confirm else 7300000


func _measure_rage(encounter: Dictionary, weapon: int) -> void:
	var fights: Array[Dictionary] = []
	var wins := 0
	for index in range(samples):
		var seed_number := _seed_base() + index
		var fight := _battle(encounter, weapon, true, case_id == "Stalker", "intent",
			seed_number, true)
		assert(fight.breath_exposures == 0)
		if index < mini(3, samples):
			var plain := _battle(encounter, weapon, true, case_id == "Stalker", "intent",
				seed_number, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				assert(fight[key] == plain[key], "Rage replay mismatch: " + key)
			replayed += 1
		wins += int(fight.win)
		fights.append(fight)
	rows.append({"build": rage_build, "weapon": STYLES[weapon], "case": case_id,
		"variant": "live", "banked": banked, "runs": samples, "wins": wins,
		"fights": fights})
	print("CELL %s %s %s banked=%s: %d/%d" % [
		rage_build, STYLES[weapon], case_id, banked, wins, samples])


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	if rage_build == "WR partial":
		for index in range(hero.learned_skills.size() - 1, -1, -1):
			if hero.learned_skills[index].id in [&"bandits_guile_1", &"precision_1"]:
				hero.learned_skills.remove_at(index)


func _create_world(seed_number: int, traced: bool) -> GridWorld:
	if not traced:
		return GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_number, false)
	var world := RageTrace.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_number, false)
	world.hero = RageHero.new(false)
	return world


func _prepare(world: GridWorld) -> void:
	super._prepare(world)
	if banked:
		world.hero.rage = 90
		world.hero.rage_credit = 0.0


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	var choices := super._priority_choices(world, target, living, policy)
	if spend_policy == "spend" and not choices.has(&"whirlwind_1"):
		choices.append(&"whirlwind_1")
	var filtered: Array[StringName] = []
	var seen: Array[StringName] = []
	var ready := 0
	var affordable := 0
	var blocked := 0
	var first_blocked := false
	for id in choices:
		var skill := world.hero.find_skill(id)
		if skill == null or id in seen:
			continue
		seen.append(id)
		var cost := skill.cost(world.hero)
		if cost <= world.hero.rage:
			filtered.append(id)
		if int(world.hero.cooldowns.get(String(world.cooldown_family(skill)), 0)) > world.turn_count:
			continue
		if id == &"feral_spirit_1" and world.actors.any(func(actor: GridActor) -> bool:
			return actor.alive and actor.summon_kind == "wolf"):
			continue
		var candidate: GridActor = target if skill.target == SkillDefinition.Target.ENEMY else null
		if not world.valid_spell_target(skill, candidate) or not SpellEffects.can_apply(world, skill, candidate):
			continue
		if ready == 0:
			first_blocked = cost > world.hero.rage
		ready += 1
		if cost > world.hero.rage:
			blocked += 1
		else:
			affordable += 1
	if world is RageTrace:
		world.decision_samples.append({"rage": world.hero.rage, "ready": ready,
			"affordable": affordable, "blocked": blocked, "first_blocked": first_blocked})
	return filtered


func _battle_metrics(world: GridWorld) -> Dictionary:
	return (world as RageTrace).metrics() if world is RageTrace else {}
