extends "res://bench/paladin_sim.gd"

const FeedbackWorld = preload("res://bench/rogue_feedback_world.gd")
var point_threshold: int = 5
var control_finisher: bool = false


func _initialize() -> void:
	builds = ["Rogue", "Warrior+Rogue", "All"]
	selected_class = &"Rogue"
	control_finisher = OS.get_cmdline_user_args().has("confirm")
	super._initialize()


func _run() -> void:
	for category in builds:
		build = category
		for weapon in range(3):
			if shard >= 0 and weapon != shard:
				continue
			for threshold in [1, 3, 5]:
				point_threshold = threshold
				_measure(ENCOUNTERS[2], 2, weapon, true, true, "physical")
				rows[-1].build = build
				rows[-1].point_threshold = threshold
				rows[-1].control_finisher = control_finisher
				rows[-1].weapon_damage_per_point = (0.5 if control_finisher
					else SkillDefinition.catalog(&"eviscerate_1").weapon_multiplier)
	if not BenchIO.write_result({"rows": rows, "replayed": replayed,
		"setup": {"samples": samples, "thresholds": [1, 3, 5], "weapons": WEAPONS,
			"builds": builds, "policy": "Fixed physical-first; prepared entry as paladin bench; one potion; dodge live breath.",
			"seeds": "1620000 + sample, paired across builds, weapons and thresholds.",
			"limits": "Level 5 common gear; constructed 90-rage preparation; no route, gifts or reinforcements."}}):
		quit(1)
		return
	print("COMPLETE Rogue feedback: %d cells, %d replays" % [rows.size(), replayed])
	quit()


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	if control_finisher:
		hero.find_skill(&"eviscerate_1").weapon_multiplier = 0.5


func _finishers(hero: HeroState) -> Array[StringName]:
	return [&"eviscerate_1"] if hero.combo_points >= point_threshold else []


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	return (FeedbackWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
		if traced else GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false))


func _battle_metrics(world: GridWorld) -> Dictionary:
	if world is FeedbackWorld:
		return {"rage_spent": world.rage_spent.duplicate(), "finisher_points": world.finisher_points.duplicate()}
	return {}
