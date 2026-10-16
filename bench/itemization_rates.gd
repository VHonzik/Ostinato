extends SceneTree

const BenchIO = preload("res://bench/bench_io.gd")
const RUNS := 20000
var runs: int = RUNS


func _init() -> void:
	if "smoke" in OS.get_cmdline_user_args():
		runs = 20
	call_deferred("_run")


func _run() -> void:
	var world := ValleyRoute.create_world(0, false)
	var sources: Array[GridActor] = []
	for actor in world.actors:
		if actor.loot_table > 0: sources.append(actor)
	var results: Array[Dictionary] = []
	for rates in [[3, 25], [5, 40], [8, 50]]:
		var tables := NorthshireLoot.TABLES.duplicate(true)
		for key in tables:
			for row in tables[key]:
				if int(row[0]) == 60002:
					row[1] = rates[1] if key == "2843" else rates[0]
				if key == "2843" and int(row[0]) == 60001:
					row[1] = 100 - int(rates[1])
		var total := 0
		var any_green := 0
		var two_plus := 0
		var full := 0
		for seed_value in range(runs):
			var count := 0
			var slots: Dictionary = {}
			var rings := 0
			for source in sources:
				var generator := RandomNumberGenerator.new()
				generator.seed = seed_value ^ int(source.spawn_id.hash()) ^ 32452843
				if source.chest:
					generator.randi_range(10, 20)
				else:
					var profile: Dictionary = NorthshireData.CREATURES[str(source.loot_table)]
					generator.randi_range(int(profile.copper_min), int(profile.copper_max))
				var loot := LootData.roll_table(tables[str(source.loot_table)], generator)
				for item in loot:
					var data := ItemData.get_item(int(item.id))
					if int(data.quality) != 2: continue
					count += 1
					if data.slot == "ring": rings += 1
					else: slots[data.slot] = true
			total += count
			any_green += int(count > 0)
			two_plus += int(count >= 2)
			full += int(slots.size() + mini(2, rings) == 5)
		var result := {"mob_percent": rates[0], "chest_percent": rates[1], "seed_count": runs,
			"average_drops": total / float(runs), "any_green_percent": any_green * 100.0 / runs,
			"two_plus_percent": two_plus * 100.0 / runs, "full_percent": full * 100.0 / runs}
		results.append(result)
		print(JSON.stringify(result))
	if not BenchIO.write_result(results):
		world.discard()
		quit(1)
		return
	world.discard()
	quit()
