extends SceneTree

const BenchIO = preload("res://bench/bench_io.gd")
const SEED_COUNT := 100000
const SAMPLE_SEEDS := [19, 97, 619, 819, 2026]
var _profiles: Dictionary = {}
var _hero := HeroState.new(false)
var seed_count: int = SEED_COUNT


func _init() -> void:
	if "smoke" in OS.get_cmdline_user_args():
		seed_count = 20
	call_deferred("_run")


func _run() -> void:
	var world := ValleyRoute.create_world(0, false)
	var sources: Array[GridActor] = []
	for actor in world.actors:
		if actor.loot_table > 0:
			sources.append(actor)
	_hero.level = 5
	_hero.refresh_stats()
	var histogram: Dictionary = {}
	var equipped_histogram: Dictionary = {}
	var full_seeds: Array[int] = []
	var examples: Dictionary = {}
	var patterns: Dictionary = {}
	var total_greens := 0
	for seed_value in range(seed_count):
		world.seed_value = seed_value
		var greens: Array[int] = []
		for source in sources:
			source.loot_assigned = false
			source.loot.clear()
			source.loot_copper = 0
			LootData.assign(world, source)
			for item in source.loot:
				if ItemData.get_item(int(item.id)).quality == 2:
					greens.append(int(item.id))
		total_greens += greens.size()
		histogram[greens.size()] = int(histogram.get(greens.size(), 0)) + 1
		var coverage := _coverage(greens)
		equipped_histogram[coverage] = int(equipped_histogram.get(coverage, 0)) + 1
		if coverage == 5:
			full_seeds.append(seed_value)
		greens.sort()
		var key := str(greens)
		if not patterns.has(key):
			patterns[key] = {"items": greens.duplicate(), "count": 0, "first_seed": seed_value}
		patterns[key].count += 1
		if seed_value in SAMPLE_SEEDS:
			examples[str(seed_value)] = {"greens": greens.duplicate(), "coverage": coverage}
		if seed_value > 0 and seed_value % 25000 == 0:
			print("Loot seeds completed: ", seed_value)
	var totals: Dictionary = {}
	var best_examples: Dictionary = {}
	var baseline: Dictionary = {}
	var theoretical: Dictionary = {}
	for style in ["two_hand", "shield_pair", "dual_wield"]:
		var common := _best([], style)
		baseline[style] = common
		theoretical[style] = _best([2572, 70011, 70012, 70012, 70013, 70013,
			70021, 70022, 70023], style)
		var sum_dps := 0.0
		var sum_ehp := 0.0
		var gains: Array[Dictionary] = []
		var best: Dictionary = {}
		for pattern in patterns.values():
			var loadout := _best(pattern.items, style)
			sum_dps += float(loadout.dps) * int(pattern.count)
			sum_ehp += float(loadout.physical_ehp) * int(pattern.count)
			gains.append({"gain": float(loadout.dps) / float(common.dps) - 1.0,
				"count": pattern.count})
			if best.is_empty() or float(loadout.dps) > float(best.dps):
				best = loadout.duplicate(true)
				best["seed"] = pattern.first_seed
		gains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gain < b.gain)
		totals[style] = {"average_dps": sum_dps / seed_count,
			"average_physical_ehp": sum_ehp / seed_count,
			"dps_gain_median": _quantile(gains, 0.5),
			"dps_gain_p90": _quantile(gains, 0.9), "dps_gain_p99": _quantile(gains, 0.99)}
		best_examples[style] = best
		for example: Dictionary in examples.values():
			example[style] = _best(example.greens, style)
	var starter := _profile([44, 0, 0, 0, 35])
	var single_upgrades: Dictionary = {}
	for identifier in [2572, 70011, 70012, 70013, 70021, 70022, 70023]:
		var style: String = ItemData.get_item(identifier).get("weapon_style", "two_hand")
		single_upgrades[str(identifier)] = {"style": style, "profile": _best([identifier], style),
			"baseline": baseline[style]}
	var result := {"seed_count": seed_count, "mob_count": sources.size() - 3,
		"chest_count": 3, "average_uncommon_drops": total_greens / float(seed_count),
		"drops_histogram": histogram, "equipped_histogram": equipped_histogram,
		"full_uncommon_seed_count": full_seeds.size(), "full_seed_examples": full_seeds.slice(0, 10),
		"sample_seeds": examples, "starter": starter, "best_common": baseline,
		"best_theoretical_uncommon": theoretical, "attainable_average": totals,
		"best_observed": best_examples, "single_upgrades": single_upgrades}
	if not BenchIO.write_result(result):
		world.discard()
		quit(1)
		return
	world.discard()
	print("Completed ", seed_count, " loot seeds.")
	quit()


func _coverage(items: Array[int]) -> int:
	var slots: Dictionary = {}
	var rings := 0
	for identifier in items:
		var slot: String = ItemData.get_item(identifier).slot
		if slot == "ring":
			rings += 1
		else:
			slots[slot] = true
	return slots.size() + mini(2, rings)


func _best(greens: Array, style: String) -> Dictionary:
	var armors: Array[int] = [85]
	var necks: Array[int] = [70001]
	# Quest ring plus one vendor replacement: both common haste rings are affordable.
	var rings: Array[int] = [70002, 70003]
	var weapons: Array[int] = []
	weapons.assign({"two_hand": [5579], "shield_pair": [5580], "dual_wield": [2224, 2139]}[style])
	var counts: Dictionary = {70002: 2, 70003: 2}
	for identifier in greens:
		var data := ItemData.get_item(int(identifier))
		match String(data.slot):
			"armor":
				if not armors.has(2572): armors.append(2572)
			"neck":
				if not necks.has(int(identifier)): necks.append(int(identifier))
			"ring":
				if not rings.has(int(identifier)): rings.append(int(identifier))
				counts[identifier] = int(counts.get(identifier, 0)) + 1
			"weapons":
				if data.weapon_style == style and not weapons.has(int(identifier)):
					weapons.append(int(identifier))
	var best: Dictionary = {}
	for armor in armors:
		for neck in necks:
			for first_index in range(rings.size()):
				for second_index in range(first_index, rings.size()):
					if first_index == second_index and int(counts.get(rings[first_index], 0)) < 2:
						continue
					for weapon in weapons:
						var profile := _profile([armor, neck, rings[first_index], rings[second_index], weapon])
						if (best.is_empty() or float(profile.dps) > float(best.dps)
							or (is_equal_approx(profile.dps, best.dps)
							and float(profile.physical_ehp) > float(best.physical_ehp))):
							best = profile
	return best


func _profile(identifiers: Array) -> Dictionary:
	var key := str(identifiers)
	if _profiles.has(key): return _profiles[key]
	_hero.equipment.clear()
	var slots := ["armor", "neck", "ring_1", "ring_2", "weapons"]
	for index in range(identifiers.size()):
		if int(identifiers[index]) > 0:
			_hero.equipment[slots[index]] = ItemData.instance(int(identifiers[index]))
	_hero.refresh_stats()
	var target := MeleeProfile.new()
	target.level = 5
	target.armor = 105
	target.dodge = 5
	var main_dps := _swing_expectation(_hero.melee, target) * _hero.attack_haste() / _hero.melee.interval
	var off_dps := 0.0
	var trained_off_dps := 0.0
	if _hero.has_off_hand_weapon():
		var off := _hero.off_hand_melee()
		off_dps = _swing_expectation(off, target) * _hero.attack_haste() / off.interval
		off.damage_multiplier = _hero.melee.damage_multiplier * 0.75
		trained_off_dps = _swing_expectation(off, target) * _hero.attack_haste() / off.interval
	var reduction := minf(0.75, _hero.melee.armor / (_hero.melee.armor + 825.0))
	var physical_ehp := _hero.max_health / ((1.0 - reduction) * (1.0 - _hero.melee.dodge / 100.0))
	var result := {"items": identifiers.duplicate(), "strength": _hero.strength,
		"agility": _hero.agility, "stamina": _hero.stamina, "health": _hero.max_health,
		"armor": _hero.melee.armor, "crit": _hero.melee.critical,
		"haste_percent": (_hero.attack_haste() - 1.0) * 100.0, "dodge": _hero.melee.dodge,
		"weapon_damage": [_hero.melee.damage_min, _hero.melee.damage_max],
		"weapon_interval": _hero.melee.interval, "dps": main_dps + off_dps,
		"trained_dps": main_dps + trained_off_dps, "physical_ehp": physical_ehp}
	_profiles[key] = result
	return result


func _swing_expectation(attacker: MeleeProfile, defender: MeleeProfile) -> float:
	var probabilities: Dictionary = {}
	for index in range(10000):
		var outcome := MeleeRules.outcome(attacker, defender, false, (index + 0.5) / 100.0)
		probabilities[outcome] = float(probabilities.get(outcome, 0.0)) + 0.0001
	var bonus := attacker.attack_power / 14.0 * attacker.interval
	var minimum := floori(attacker.damage_min + bonus)
	var maximum := floori(attacker.damage_max + bonus)
	var total := 0.0
	for outcome in probabilities:
		var damage := 0.0
		for index in range(maximum - minimum + 1):
			damage += MeleeRules.damage(attacker, defender, outcome,
				(index + 0.5) / (maximum - minimum + 1))
		total += probabilities[outcome] * damage / (maximum - minimum + 1)
	return total


func _quantile(values: Array[Dictionary], quantile: float) -> float:
	var seen := 0
	for value in values:
		seen += int(value.count)
		if seen >= seed_count * quantile: return float(value.gain)
	return float(values[-1].gain)
