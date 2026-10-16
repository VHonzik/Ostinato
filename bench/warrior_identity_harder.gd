extends "res://bench/warrior_identity_sim.gd"

const HARD_CASES: Array[Dictionary] = [
	{"id": "4xL4", "hero_level": 3, "profile": "38", "count": 4},
	{"id": "3xL5", "hero_level": 3, "profile": "103", "count": 3},
	{"id": "4xL5", "hero_level": 3, "profile": "103", "count": 4},
]


func _run() -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		OS.get_environment("OSTINATO_BENCH_BASELINE")))
	for weapon in range(3):
		if shard >= 0 and weapon != shard:
			continue
		for prepared in [false, true]:
			var policy := ""
			for row: Dictionary in baseline.rows:
				if row.case == "3xL4" and row.weapon == STYLES[weapon] and row.prepared == prepared:
					policy = String(row.policy)
			assert(not policy.is_empty())
			for index in range(HARD_CASES.size()):
				_measure(HARD_CASES[index], 7 + index, weapon, prepared, false, policy)
	var setup: Dictionary = baseline.setup.duplicate(true)
	setup.commit = OS.get_environment("OSTINATO_BENCH_REVISION")
	setup.samples_per_cell = samples
	setup.cases = HARD_CASES
	setup.policy_selection = "Reuse the independent 3xL4 pilot policy from the supplied baseline; no new selection on these harder cases."
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE harder: %d cells, %d fights, %d plain replays, %.1fs" % [
		rows.size(), rows.size() * samples, replayed, (Time.get_ticks_msec() - started) / 1000.0])
	quit()
