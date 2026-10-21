extends SceneTree

const BenchIO = preload("res://bench/bench_io.gd")
const PACKAGES: Dictionary = {
	"trained": [&"enrage_1", &"battle_shout_1", &"recklessness_1", &"weapon_mastery_1",
		&"charge_1", &"execute_1"],
	"playtest": [&"battle_shout_1", &"weapon_mastery_1", &"charge_1", &"execute_1"],
}
var samples: int = 100
var confirm_tuning: bool = false


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("smoke"):
		samples = 3
	confirm_tuning = OS.get_cmdline_user_args().has("confirm")
	if confirm_tuning and not OS.get_cmdline_user_args().has("smoke"):
		samples = 300
	call_deferred("_run")


func _run() -> void:
	var profiles: Array[Dictionary] = [{"name": "current", "data": NorthshireData.CREATURES["103"]}]
	for health in [200, 220, 240]:
		if confirm_tuning:
			break
		var profile: Dictionary = NorthshireData.CREATURES["103"].duplicate()
		profile.merge({"health": health, "minimum": 10, "maximum": 13, "interval": 2.6}, true)
		profiles.append({"name": "hp%d" % health, "data": profile})
	var rows: Array[Dictionary] = []
	for profile in profiles:
		for level in [3, 4, 5]:
			for gear in ["common", "green_shield_strength", "green_shield_agility"]:
				for package: String in PACKAGES:
					var wins := 0
					var health: Array[int] = []
					var max_health := 0
					var remaining_total := 0
					for index in range(samples):
						var fight := _fight(profile.data, level, gear, package,
							(7310000 if confirm_tuning else 7210000) + index)
						wins += int(fight.win)
						max_health = fight.max_health
						remaining_total += maxi(0, int(fight.hp))
						if fight.win:
							health.append(fight.hp)
					health.sort()
					rows.append({"profile": profile.name, "enemy": profile.data, "level": level,
						"gear": gear, "package": package, "samples": samples, "wins": wins,
						"win_percent": 100.0 * wins / samples, "max_health": max_health,
						"mean_remaining_hp": float(remaining_total) / samples,
						"mean_win_hp": float(remaining_total) / wins if wins > 0 else 0.0,
						"median_win_hp": 0 if health.is_empty() else health[health.size() / 2]})
		print("Measured %s" % profile.name)
	var setup := {"skills": PACKAGES, "samples": samples, "confirm": confirm_tuning,
		"policy": "Full HP, zero rage; live Battle Shout preparation, Charge, Execute then Mortal Strike then Whirlwind, otherwise wait. No potions, kiting, route damage or XP heals. Common is vendor shield/armor/neck/two rings. Green variants replace the weapon setup with Sentinel Sword and Shield and one ring with Wolfstone or Leafstone. Playtest package retains the owner's four purchases (Cruelty renamed Weapon Mastery); trained also adds Enrage and Death Wish.",
		"seeds": "%d + sample index, paired across profiles and preparations; isolated live GridWorld fights." % (7310000 if confirm_tuning else 7210000)}
	quit(0 if BenchIO.write_result({"setup": setup, "rows": rows}) else 1)


func _fight(profile: Dictionary, level: int, gear: String, package: String, seed_value: int) -> Dictionary:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
	var hero := world.hero
	hero.level = level
	if gear != "travel":
		StarterGear.equip_outfit(hero)
	if gear in ["common", "green_shield_strength", "green_shield_agility"]:
		var identifiers := {"armor": 85, "weapons": 2129, "neck": 70001, "ring_1": 70002, "ring_2": 70003}
		for slot: String in identifiers:
			hero.equipment[slot] = ItemData.instance(identifiers[slot])
		if gear.begins_with("green_shield"):
			hero.equipment.weapons = ItemData.instance(70022)
			hero.equipment.ring_1 = ItemData.instance(70012 if gear.ends_with("strength") else 70013)
	for identifier: StringName in PACKAGES[package]:
		hero.learn_skill(SkillDefinition.catalog(identifier))
	hero.refresh_stats()
	hero.health = hero.max_health
	if hero.find_skill(&"battle_shout_1") != null:
		assert(world.cast_skill(&"battle_shout_1"))
	var enemy := GridActor.new(Vector2i.DOWN + world.player_tile)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.awards_experience = false
	enemy.max_health = profile.health
	enemy.health = enemy.max_health
	enemy.melee.level = profile.level
	enemy.melee.armor = profile.armor
	enemy.melee.damage_min = profile.minimum
	enemy.melee.damage_max = profile.maximum
	enemy.melee.attack_power = profile.power
	enemy.melee.interval = profile.interval
	world.actors.append(enemy)
	if hero.find_skill(&"charge_1") != null:
		enemy.tile += Vector2i.DOWN * 4
		enemy.home_tile = enemy.tile
		assert(world.cast_skill(&"charge_1", enemy))
	else:
		assert(world.request_melee(enemy))
	while hero.health > 0 and enemy.alive and world.turn_count < 200:
		if world.pending_skill != null:
			world.continue_cast()
		elif world.pending_melee != null:
			world.continue_melee()
		else:
			var acted := false
			for identifier: StringName in [&"execute_1", &"mortal_strike_1", &"whirlwind_1"]:
				var skill := hero.find_skill(identifier)
				if (skill != null and skill.cost(hero) <= hero.rage
					and world.turn_count >= int(hero.cooldowns.get(String(skill.family), 0))
					and world.valid_spell_target(skill, enemy)):
					assert(world.cast_skill(identifier, enemy))
					acted = true
					break
			if not acted:
				world.wait_turn()
	var result := {"win": not enemy.alive and hero.health > 0, "hp": hero.health,
		"max_health": hero.max_health}
	world.discard()
	return result
