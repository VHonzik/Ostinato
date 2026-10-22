extends "res://bench/pull_sim.gd"

const InteractionWorld = preload("res://bench/aoe_interactions_world.gd")
const OFFENSE: Array[String] = ["ground_ww", "burst", "shelter", "burst_no_rb",
	"shelter_no_rb", "burst_no_seal"]
const DEFENSE: Array[String] = ["neither", "block", "evasion", "both", "both_no_rb"]
var variant: String = ""
var suite: String = ""
var health_scale: int = 1
var retained: String = "Warrior+Paladin+Rogue"
var focused_cooldowns: bool = false


func _initialize() -> void:
	samples = 20
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
		elif arg.begins_with("shard="): shard = int(arg.trim_prefix("shard="))
		elif arg == "policy=cooldowns": focused_cooldowns = true
	selected_class = &"Warrior"
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	for weapon in range(3):
		if shard >= 0 and shard != weapon: continue
		for gear_quality in ["common", "uncommon"]:
			quality = gear_quality
			for scale in ([10] if focused_cooldowns else [1, 10]):
				health_scale = scale
				var counts: Array = ([1, 3] if focused_cooldowns else
					([1, 8, 16, 32] if scale == 1 else [8]))
				for count in counts:
					suite = "offense"
					for policy in OFFENSE:
						variant = policy
						_measure_interaction(weapon, count)
					if weapon == 1:
						suite = "defense"
						for policy in DEFENSE:
							variant = policy
							_measure_interaction(weapon, count)
			if focused_cooldowns: continue
			# Complete retained-kit control at the intended large-pull size.
			health_scale = 1
			retained = "All"
			suite = "offense"
			for policy in OFFENSE:
				variant = policy
				_measure_interaction(weapon, 16)
			retained = "Warrior+Paladin+Rogue"
	if not BenchIO.write_result({"setup": {"samples": samples, "seed_base": 6100000,
		"focused_cooldowns": focused_cooldowns,
		"expected_cells": rows.size(), "offense": OFFENSE, "defense": DEFENSE,
		"rules": "Live L4 hero vs L4 70-HP thugs. Common/uncommon complete gear, open concentric rings, eight adjacent maximum. All Warrior/Paladin/Rogue learning; All-kit control adds Shaman. Zero rage/points, live maintenance preparation. No XP, potions, gifts, kiting or summons. Stress changes only enemy HP to 700, not damage/speed/armor.",
		"offense_policy": "Ground before Whirlwind; Eviscerate at 5CP before ordinary cleave. Burst adds Vanish immediately before affordable WW. Shelter uses the same Vanish opportunities but waits until one hidden boundary remains before empowered WW; existing ground keeps ticking. Both may re-Vanish whenever ready. No Evasion or Divine Shield. Remove Restless Blades or Seal Fate as labelled. Auto-attack fallback uses real target commitment.",
		"defense_policy": "Ground/5CP finisher/WW rotation, proactive Evasion whenever ready. Neither removes Shield Block and Evasion; block retains only Block; evasion retains only Evasion; both retains both; both_no_rb removes Restless Blades. No Vanish or Divine Shield.",
		"checks": "Each fight reconciles enemy damage and hero HP/healing. Three seeds per cell replay on plain GridWorld including final combat RNG. Cells reuse seed blocks; 20 seeds per cell, not independent across cells.",
		"limits": "Fixed exploratory bots, full learned kits and full gear; no route costs or learning path. 700-HP packs are synthetic cooldown stress only. No game tuning changes; no balance or human acceptance claim."},
		"rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE aoe-interactions: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _measure_interaction(weapon: int, count: int) -> void:
	var fights: Array[Dictionary] = []
	for index in range(samples):
		var seed_value := 6100000 + count * 1000 + health_scale * 100 + index
		var encounter := {"count": count, "health_scale": health_scale}
		var fight := _battle(encounter, weapon, true, false, variant, seed_value, true)
		if index < mini(3, samples):
			var plain := _battle(encounter, weapon, true, false, variant, seed_value, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				assert(fight[key] == plain[key], "Interaction replay mismatch: " + key)
			replayed += 1
		else:
			fight.erase("timeline")
			fight.erase("decisions")
		fights.append(fight)
	rows.append({"count": count, "health_scale": health_scale, "weapon": STYLES[weapon],
		"quality": quality, "build": retained, "suite": suite, "policy": variant,
		"fights": fights})
	print("CELL %s %s %s %s x%d hp%d %s" % [STYLES[weapon], quality,
		retained, suite, count, health_scale, variant])


func _create_pull_world(bounds: Rect2i, center: Vector2i, seed_value: int,
	traced: bool) -> GridWorld:
	return (InteractionWorld.new(bounds, center, seed_value, false)
		if traced else GridWorld.new(bounds, center, seed_value, false))


func _learn_skills(hero: HeroState) -> void:
	build = retained
	super._learn_skills(hero)
	var removed: Array[StringName] = []
	if variant.ends_with("no_rb"): removed.append(&"restless_blades_1")
	if variant.ends_with("no_seal"): removed.append(&"seal_fate_1")
	if suite == "defense" and variant in ["neither", "evasion"]:
		removed.append(&"shield_block_1")
	hero.learned_skills = hero.learned_skills.filter(func(skill: SkillDefinition) -> bool:
		return skill.id not in removed)


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	_policy: String) -> Array[StringName]:
	var hero := world.hero
	var choices: Array[StringName] = []
	var ww := hero.find_skill(&"whirlwind_1")
	if VanishRules.active(world):
		var remaining := int(hero.buffs[&"vanish_1"].until) - world.turn_count
		if variant.begins_with("shelter") and remaining > 1:
			# Empty choices normally trigger a deliberate bump. Explicitly wait instead.
			return []
		return [&"whirlwind_1"]
	if suite == "defense" and variant in ["evasion", "both", "both_no_rb"] \
		and not hero.buffs.has(&"evasion_1"):
		choices.append(&"evasion_1")
	if not PaladinRules.covers(world, world.player_tile): choices.append(&"consecration_1")
	if hero.combo_points == 5: choices.append(&"eviscerate_1")
	if suite == "offense" and variant != "ground_ww" \
		and ww.cost(hero) <= hero.rage:
		choices.append(&"vanish_1")
	choices.append(&"whirlwind_1")
	if hero.rage < ww.cost(hero): choices.append(&"battle_shout_1")
	return choices
