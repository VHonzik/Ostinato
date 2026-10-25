extends "res://bench/priority_sim.gd"
## Partial-learning audit with live preparation, movement and cooldowns.

const BalanceTrace = preload("res://bench/restless_trace_world.gd")
const LATE_ROGUE: Array[StringName] = [
	&"catalytic_venom_1", &"bandits_guile_1", &"precision_1"]
const AUDIT_BUILDS: Array[String] = [
	"Warrior", "WR missing 3", "WR missing 2", "WR missing 1", "Warrior+Rogue",
	"Warrior+Shaman+Rogue", "Warrior+Paladin+Rogue", "All"]

var audit_build: String = ""
var control: String = "live"
var point_threshold: int = 5


func _initialize() -> void:
	samples = 200
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	selected_class = &"Warrior"
	case_id = "Stalker"
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	StalkerDodge.check_live_response()
	for category in AUDIT_BUILDS:
		audit_build = category
		build = "Warrior+Rogue" if category.begins_with("WR missing") else category
		for weapon in range(3):
			_measure_audit(weapon)
	# Paired diagnostic controls for the middle of the reported missing-skill range.
	audit_build = "WR missing 2"
	build = "Warrior+Rogue"
	for variant in ["no evasion", "no potion", "no breath", "no restless", "one point"]:
		control = variant
		point_threshold = 1 if control == "one point" else 5
		_measure_audit(2)
	var setup := {
		"samples": samples, "expected_cells": AUDIT_BUILDS.size() * 3 + 5,
		"hero_level": 5, "weapons": WEAPONS, "stalker": NorthshireData.STALKER,
		"late_rogue": LATE_ROGUE,
		"entry": "Full health, common armor 85, neck 70001, rings 70002/70003. "
			+ "Live maintenance preparation from zero rage; no banked points/procs. "
			+ "Charge from six tiles. One minor potion at 40 missing HP. "
			+ "No gifts, Vanish, route, XP or reinforcements.",
		"learning": "Full named kits; WR missing N omits the last N Rogue abilities "
			+ "by learning level/cost: Catalytic Venom, Bandit's Guile, Precision. "
			+ "Other kits fully learned.",
		"policy": "Production coordinated intent, Eviscerate at five points. "
			+ "Real sidestep before other actions; no general kiting. "
			+ "One-point control changes only finisher threshold.",
		"controls": "DW missing-two setup: remove Evasion, potion or Restless Blades; "
			+ "postpone first breath past the fight (ordinary melee continues); "
			+ "spend finishers at one point. No production tuning changes.",
		"seeds": "5700000 + sample, paired across all cells. "
			+ "Combat streams can diverge after interventions.",
		"checks": "Every traced fight reconciles boss and player HP; no breath exposure. "
			+ "First three seeds per cell replay on plain GridWorld with the same declared "
			+ "control, checking outcome, HP, turns, rage and RNG.",
		"limits": "Fixed bot and common gear, partial learning inferred from reported "
			+ "last purchases. Isolated fights do not establish human balance acceptance. "
			+ "Controls are conditional, non-additive effects."
	}
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed}):
		quit(1)
		return
	print("COMPLETE Stalker balance: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _measure_audit(weapon: int) -> void:
	var encounter := {"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1}
	var fights: Array[Dictionary] = []
	var wins := 0
	for index in range(samples):
		var fight := _battle(encounter, weapon, true, control != "no potion", "intent",
			5700000 + index, true)
		assert(fight.breath_exposures == 0)
		if index < mini(3, samples):
			var plain := _battle(encounter, weapon, true, control != "no potion", "intent",
				5700000 + index, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				assert(fight[key] == plain[key], "Plain replay mismatch: " + key)
			replayed += 1
		wins += int(fight.win)
		fights.append(fight)
	rows.append({"build": audit_build, "weapon": STYLES[weapon], "control": control,
		"runs": samples, "wins": wins, "fights": fights})
	print("CELL %s %s %s: %d/%d wins" % [audit_build, STYLES[weapon], control, wins, samples])


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	var omitted: Array[StringName] = []
	if audit_build.begins_with("WR missing"):
		var count := int(audit_build.get_slice(" ", 2))
		omitted.assign(LATE_ROGUE.slice(LATE_ROGUE.size() - count))
	if control == "no evasion":
		omitted.append(&"evasion_1")
	if control == "no restless":
		omitted.append(&"restless_blades_1")
	for index in range(hero.learned_skills.size() - 1, -1, -1):
		if hero.learned_skills[index].id in omitted:
			hero.learned_skills.remove_at(index)


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	return (BalanceTrace.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
		if traced else GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false))


func _open_battle(world: GridWorld, enemies: Array[GridActor]) -> void:
	if control == "no breath":
		enemies[0].breath_normal_turns = -1000
	super._open_battle(world, enemies)


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	var choices := super._priority_choices(world, target, living, policy)
	if (world.hero.combo_points >= point_threshold
		and not choices.has(&"eviscerate_1")):
		choices.insert(choices.find(&"execute_1"), &"eviscerate_1")
	return choices


func _battle_metrics(world: GridWorld) -> Dictionary:
	return (world as BalanceTrace).metrics() if world is BalanceTrace else {}
