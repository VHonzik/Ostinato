extends "res://bench/stalker_balance_sim.gd"
## Compare health/melee tuning while retaining the complete live breath behavior.

const StatsWorld = preload("res://bench/stalker_stats_world.gd")
const StatsTrace = preload("res://bench/stalker_stats_trace.gd")
const STAT_PROFILES: Array[Dictionary] = [
	{"id": "600/14-18", "health": 600, "minimum": 14, "maximum": 18},
	{"id": "800/14-18", "health": 800, "minimum": 14, "maximum": 18},
	{"id": "600/20-26", "health": 600, "minimum": 20, "maximum": 26},
	{"id": "800/18-24", "health": 800, "minimum": 18, "maximum": 24},
	{"id": "900/18-24", "health": 900, "minimum": 18, "maximum": 24},
]
const STAT_BUILDS: Array[String] = [
	"WR missing 2", "Warrior+Rogue", "Warrior+Shaman+Paladin", "Warrior+Shaman+Rogue",
	"Warrior+Paladin+Rogue", "Shaman+Paladin+Rogue", "All"]

var profile: Dictionary = {}
var confirm: bool = false
var with_gifts: bool = false


func _initialize() -> void:
	samples = 30
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
		elif arg == "confirm":
			confirm = true
	samples = 100 if confirm else 30
	if smoke:
		samples = 2
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	selected_class = &"Warrior"
	case_id = "Stalker"
	call_deferred("_run")


func _run() -> void:
	var profiles: Array[Dictionary] = STAT_PROFILES.duplicate(true)
	if confirm:
		profiles = [{"id": "live", "health": NorthshireData.STALKER.health,
			"minimum": NorthshireData.STALKER.minimum, "maximum": NorthshireData.STALKER.maximum}]
	for candidate in profiles:
		profile = candidate
		print("PROFILE " + String(profile.id))
		for gifts in ([false, true] if confirm else [false]):
			with_gifts = gifts
			print("GIFTS " + str(with_gifts))
			for category in STAT_BUILDS:
				if with_gifts and category.begins_with("WR missing"):
					continue
				audit_build = category
				build = "Warrior+Rogue" if category.begins_with("WR missing") else category
				for weapon in range(3):
					_measure_audit(weapon)
					rows[-1]["profile"] = profile.duplicate()
					rows[-1]["gifts"] = with_gifts
	var expected_cells := 39 if confirm else profiles.size() * STAT_BUILDS.size() * 3
	var setup := {"samples": samples, "expected_cells": expected_cells,
		"confirm": confirm, "profiles": profiles, "builds": STAT_BUILDS,
		"entry": "Level 5, full HP, common gear and six-tile Charge where learned. "
			+ "Live maintenance from zero rage, one minor potion, no banked points/procs. "
			+ "No Vanish, route, XP or reinforcements. Initial Warrior starters retained.",
		"gifts": "Pilot omits gifts; confirmation pairs full builds with/without earned "
			+ "charm, totem and banner. Use totem then banner in melee. No gift is useful "
			+ "for the partial build. War Horn is unused against a single engaged enemy.",
		"policy": "Coordinated intent and five-point finishers. Sidestep live breath. "
			+ "Only boss HP and base melee damage vary; all breath behavior/timers remain live.",
		"seeds": "Pilot 5700000 + sample; confirmation 5800000 + sample. "
			+ "Paired across cells within each phase; confirmation does not reuse pilot seeds.",
		"checks": "Boss/player HP reconciliation on every fight, zero breath exposure, "
			+ "first three samples replay on plain GridWorld with identical declared stats.",
		"limits": "Fixed bot and common gear; missing-two omits Bandit's Guile/Precision. "
			+ "Fixed gift timing; no route, uncommon gear or human balance acceptance."}
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed}):
		quit(1)
		return
	print("COMPLETE Stalker stats: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	var world: GridWorld = (StatsTrace.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12),
		seed_value, false) if traced else StatsWorld.new(Rect2i(0, 0, 20, 20),
		Vector2i(10, 12), seed_value, false))
	world.set("profile", profile.duplicate())
	if with_gifts:
		var items: Array[int] = []
		if build == "All" or "Rogue" in build:
			items.append(ItemData.LUCKY_CHARM_ID)
		if build == "All" or "Shaman" in build:
			items.append(ItemData.ANCESTRAL_TOTEM_ID)
		if build == "All" or "Paladin" in build:
			items.append(ItemData.WAR_BANNER_ID)
		for index in range(items.size()):
			world.hero.inventory[index + 1] = ItemData.instance(items[index])
	return world


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	for skill in SkillDefinition.starting_skills(&"Warrior"):
		if hero.find_skill(skill.id) == null:
			hero.learned_skills.append(skill)


func _battle(encounter: Dictionary, weapon: int, prepared: bool, potion: bool,
	policy: String, seed_value: int, traced: bool) -> Dictionary:
	return super._battle(encounter, weapon, prepared, potion, policy,
		seed_value + (100000 if confirm else 0), traced)


func _try_item_action(world: GridWorld, target: GridActor) -> bool:
	if not with_gifts or GridWorld.tile_distance(world.player_tile, target.tile) > 1:
		return false
	if world.has_ancestral_totem():
		return world.use_ancestral_totem()
	if world.has_war_banner():
		return world.use_war_banner()
	return false
