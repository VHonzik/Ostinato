extends SceneTree

const BenchIO = preload("res://bench/bench_io.gd")

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var results: Dictionary = {}
	for style in ["two_hand", "shield_pair", "dual_wield"]:
		var weapon: int = {"two_hand": 5579, "shield_pair": 5580, "dual_wield": 2224}[style]
		var best: Dictionary = {}
		for first in [70002, 70003]:
			for second in [70002, 70003]:
				var profile := _profile([85, 70001, first, second, weapon])
				if best.is_empty() or float(profile.dps) > float(best.dps): best = profile
		var upgrades: Dictionary = {}
		for identifier in [70011, 70012, 70013, 2572]:
			var items: Array = best.items.duplicate()
			var slot: String = ItemData.get_item(identifier).slot
			if slot == "neck": items[1] = identifier
			elif slot == "armor": items[0] = identifier
			else:
				var first := items.duplicate()
				var second := items.duplicate()
				first[2] = identifier
				second[3] = identifier
				items = first if _profile(first).dps > _profile(second).dps else second
			var profile := _profile(items)
			profile["damage_gain_percent"] = (float(profile.dps) / float(best.dps) - 1.0) * 100.0
			profile["physical_ehp_gain_percent"] = (float(profile.ehp) / float(best.ehp) - 1.0) * 100.0
			upgrades[str(identifier)] = profile
		var primary_gains: Dictionary = {}
		for stat in ["strength", "agility", "stamina"]:
			var baseline := _profile(best.items)
			var boosted := _profile(best.items, stat)
			primary_gains[stat] = {"dps_percent": (boosted.dps / baseline.dps - 1.0) * 100.0,
				"ehp_percent": (boosted.ehp / baseline.ehp - 1.0) * 100.0,
				"health_gain": boosted.health - baseline.health,
				"crit_gain": boosted.crit - baseline.crit, "dodge_gain": boosted.dodge - baseline.dodge}
		var full_green: Dictionary = {}
		var green_weapon: int = {"two_hand": 70021, "shield_pair": 70022, "dual_wield": 70023}[style]
		for first in [70012, 70013]:
			for second in [70012, 70013]:
				var profile := _profile([2572, 70011, first, second, green_weapon])
				if full_green.is_empty() or float(profile.dps) > float(full_green.dps): full_green = profile
		full_green["damage_gain_percent"] = (full_green.dps / best.dps - 1.0) * 100.0
		results[style] = {"common": best, "upgrades": upgrades, "primary_plus_two": primary_gains,
			"best_full_green": full_green}
	if not BenchIO.write_result(results):
		quit(1)
		return
	for style in results:
		print(style, " +2 primary: ", JSON.stringify(results[style].primary_plus_two))
		for identifier in results[style].upgrades:
			var upgrade: Dictionary = results[style].upgrades[identifier]
			print("  ", identifier, ": damage +", snappedf(upgrade.damage_gain_percent, 0.1),
				"%, physical EHP +", snappedf(upgrade.physical_ehp_gain_percent, 0.1), "%")
	quit()


func _profile(items: Array, bonus_stat: String = "") -> Dictionary:
	var hero := HeroState.new(false)
	hero.level = 5
	hero.equipment.clear()
	for index in range(items.size()):
		hero.equipment[["armor", "neck", "ring_1", "ring_2", "weapons"][index]] = ItemData.instance(int(items[index]))
	if bonus_stat != "": hero.buffs[&"simulation_bonus"] = {bonus_stat: 2}
	hero.refresh_stats()
	var defender := MeleeProfile.new()
	defender.level = 5
	defender.armor = 105
	var dps := _average(hero.melee, defender) * hero.attack_haste() / hero.melee.interval
	if hero.has_off_hand_weapon():
		var off := hero.off_hand_melee()
		dps += _average(off, defender) * hero.attack_haste() / off.interval
	var reduction := hero.melee.armor / (hero.melee.armor + 825.0)
	return {"items": items.duplicate(), "strength": hero.strength, "agility": hero.agility,
		"stamina": hero.stamina, "health": hero.max_health, "armor": hero.melee.armor,
		"crit": hero.melee.critical, "dodge": hero.melee.dodge, "haste": hero.attack_haste(),
		"dps": dps, "ehp": hero.max_health / ((1.0 - reduction) * (1.0 - hero.melee.dodge / 100.0))}


func _average(attacker: MeleeProfile, defender: MeleeProfile) -> float:
	var critical := MeleeRules.critical_chance(attacker, defender) / 100.0
	var hit := 1.0 - MeleeRules.miss_chance(attacker, defender) / 100.0 - defender.dodge / 100.0 - critical
	var total := 0.0
	for index in range(12000):
		var roll := (index + 0.5) / 12000.0
		total += MeleeRules.damage(attacker, defender, &"hit", roll) * hit
		total += MeleeRules.damage(attacker, defender, &"critical", roll) * critical
	return total / 12000.0
