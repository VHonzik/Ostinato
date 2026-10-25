extends "res://bench/paladin_sim.gd"

const HealthWorld = preload("res://bench/stalker_passive_world.gd")
const STALKER_CASE: Dictionary = {
	"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1}
const CATEGORIES: Array[String] = ["Warrior", "Shaman", "Paladin", "Rogue"]
const SKIPPED: Dictionary = {
	"anger_management_1": "Out-of-combat rage retention requires a route/between-fight trial.",
	"victory_rush_1": "Only enemy is the final Stalker; terminal victory stops kill healing.",
	"sweeping_strikes_1": "Requires a second enemy.",
	"pursuit_of_justice_1": "Travel value needs a route trial; Warrior uses Charge here.",
	"relentless_assault_1": "Core combo engine; removing it invalidates finisher dependencies."}

var disabled: Array[StringName] = []
var baseline_samples: int = 200
var ablation_samples: int = 100
var phase: String = "baseline"
var _passives: Array[Dictionary] = []
var _baseline_cells: Dictionary = {}


func _initialize() -> void:
	selected_class = &"Warrior"
	pilot_samples = 40
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			baseline_samples = 2
			ablation_samples = 2
			pilot_samples = 2
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
	for category in CATEGORIES:
		kit_skills[category] = SkillDefinition.trainer_skills(StringName(category))
		for skill: SkillDefinition in kit_skills[category]:
			if skill.effect == SkillDefinition.Effect.PASSIVE:
				_passives.append({"id": String(skill.id), "name": skill.title,
					"class": category, "skip": SKIPPED.get(String(skill.id), "")})
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	# All 15 nonempty retained-kit combinations, with common measured seeds.
	for mask in range(1, 16):
		var names: Array[String] = []
		for index in range(4):
			if mask & (1 << index):
				names.append(CATEGORIES[index])
		build = "All" if mask == 15 else "+".join(names)
		for weapon in range(3):
			if shard >= 0 and weapon != shard:
				continue
			for prepared in [false, true]:
				disabled.clear()
				var policy := _choose_stalker_policy(weapon, prepared)
				var cell := _measure_trial(weapon, prepared, policy, baseline_samples)
				_baseline_cells[_cell_key(build, weapon, prepared)] = cell
	phase = "ablation"
	for passive in _passives:
		if not String(passive.skip).is_empty():
			continue
		for context: String in [passive["class"], "All"]:
			build = context
			for weapon in range(3):
				if shard >= 0 and weapon != shard:
					continue
				# Off-hand-only passives are structurally inactive for the other weapons.
				if weapon != 2 and passive.id in ["ambidexterity_1", "combat_potency_1",
					"main_gauche_1", "catalytic_venom_1"]:
					continue
				for prepared in [false, true]:
					var baseline: Dictionary = _baseline_cells[_cell_key(build, weapon, prepared)]
					disabled.assign([StringName(passive.id)])
					var cell := _measure_trial(weapon, prepared, baseline.policy, ablation_samples)
					cell["removed"] = passive.name
	var setup := {"baseline_samples": baseline_samples, "ablation_samples": ablation_samples,
		"pilot_samples_per_policy": pilot_samples, "passives": _passives,
		"gear": {"armor": 85, "neck": 70001, "ring_1": 70002, "ring_2": 70003,
			"weapons": WEAPONS}, "stalker": NorthshireData.STALKER,
		"hero_level": 5, "entry_distance": 6,
		"entry": "Full HP. Cold: zero rage, no buffs. Prepared: rage set to 90 before fresh maintenance buffs (Battle Shout adds 10 if known), mixed poisons on unequal-speed DW, no points/procs/summons. Known Charge opens at six tiles; otherwise approach naturally.",
		"policies": "40 independent pilot seeds choose holy, physical, no_ground or spend. Existing Paladin priorities plus single-target Whirlwind (reserve 30 rage, or spend freely). Same selected policy for baseline/removal. Sidestep marked production Fel Breath with live movement before other actions; no general kiting. One Minor Healing Potion at 40 missing HP.",
		"seeds": "Pilot 1750000+index. Measurement 1760000+index, same seeds per cell and removal; ablations match the first baseline seeds. Combat streams may diverge after removal.",
		"metrics": "Effective boss HP removed, effective healing by source (overheal excluded), effective player HP lost and raw post-mitigation incoming damage including fatal overkill, turns, casts, damage sources. HP conservation checked every fight.",
		"limits": "Isolated production Stalker; common gear, full learned kits, no reinforcements/route, no kill XP/level healing. No retuning or reoptimizing the bot after removal. Effects are conditional and non-additive. No human balance acceptance."}
	if not BenchIO.write_result({"setup": setup, "pilots": pilots, "rows": rows,
		"replayed": replayed, "seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE Stalker passive trials: %d cells, %d plain replays, %.1fs" % [
		rows.size(), replayed, (Time.get_ticks_msec() - started) / 1000.0])
	quit()


func _cell_key(category: String, weapon: int, prepared: bool) -> String:
	return "%s/%d/%s" % [category, weapon, prepared]


func _choose_stalker_policy(weapon: int, prepared: bool) -> String:
	var chosen := "holy"
	var best := [-1, -100000000, -1]
	for policy in ["holy", "physical", "no_ground", "spend"]:
		var score := [0, 0, 0]
		for index in range(pilot_samples):
			var fight := _battle(STALKER_CASE, weapon, prepared, true, policy,
				1750000 + index, true)
			score[0] += int(fight.win)
			score[1] -= int(fight.enemy_hp)
			score[2] += int(fight.hp)
		pilots.append({"build": build, "weapon": STYLES[weapon],
			"prepared": prepared, "policy": policy, "score": score})
		if score[0] > best[0] or (score[0] == best[0] and (score[1] > best[1]
			or (score[1] == best[1] and score[2] > best[2]))):
			best = score
			chosen = policy
	return chosen


func _measure_trial(weapon: int, prepared: bool, policy: String, count: int) -> Dictionary:
	var fights: Array[Dictionary] = []
	for index in range(count):
		var fight := _battle(STALKER_CASE, weapon, prepared, true, policy, 1760000 + index, true)
		if index < mini(count, 3):
			var plain := _battle(STALKER_CASE, weapon, prepared, true, policy,
				1760000 + index, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				assert(fight[key] == plain[key], "Plain replay mismatch: " + key)
			replayed += 1
		fights.append(fight)
	var cell := {"build": build, "weapon": STYLES[weapon], "prepared": prepared,
		"phase": phase, "disabled": disabled.duplicate(), "policy": policy,
		"runs": count, "fights": fights}
	rows.append(cell)
	print("CELL %s %s %s prepared=%s disabled=%s n=%d" % [phase, build,
		STYLES[weapon], prepared, str(disabled), count])
	return cell


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	return (HealthWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
		if traced else GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false))


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	for index in range(hero.learned_skills.size() - 1, -1, -1):
		if hero.learned_skills[index].id in disabled:
			hero.learned_skills.remove_at(index)


func _prepare(world: GridWorld) -> void:
	super._prepare(world)
	# Removing the catalyst must not also change the initial coating choice.
	if world.hero.has_off_hand_weapon() and world.hero.find_skill(&"deadly_poison_1") != null:
		var weapon := ItemData.get_item(world.hero.weapon_id())
		var faster := PoisonRules.Hands.MAIN if weapon.interval < weapon.off_interval else PoisonRules.Hands.OFF
		PoisonRules.coat(world, world.hero.find_skill(&"instant_poison_1"), faster)
		PoisonRules.coat(world, world.hero.find_skill(&"deadly_poison_1"),
			PoisonRules.Hands.OFF if faster == PoisonRules.Hands.MAIN else PoisonRules.Hands.MAIN)


func _open_battle(world: GridWorld, enemies: Array[GridActor]) -> void:
	enemies[0].tile = world.player_tile + Vector2i(0, -6)
	enemies[0].home_tile = enemies[0].tile
	if world.hero.find_skill(&"charge_1") != null:
		assert(world.cast_skill(&"charge_1", enemies[0]))


func _additional_choices(world: GridWorld, policy: String) -> Array[StringName]:
	var whirlwind := world.hero.find_skill(&"whirlwind_1")
	if whirlwind != null and (policy == "spend" or whirlwind.cost(world.hero) == 0
		or world.hero.rage - whirlwind.cost(world.hero) >= 30):
		return [&"whirlwind_1"]
	return []


func _battle_metrics(world: GridWorld) -> Dictionary:
	return (world as HealthWorld).metrics() if world is HealthWorld else {}
