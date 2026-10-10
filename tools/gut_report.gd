extends GutHookScript
## One result file detects unrun tests and matches narrowly asserted engine errors.


func run() -> void:
	var results: Dictionary = GutUtils.ResultExporter.new().get_results_dictionary(gut)
	var collected: Array[Dictionary] = []
	for test_script in gut.get_test_collector().scripts:
		for test_case in test_script.tests:
			collected.append({
				"script": test_script.get_full_name(),
				"name": test_case.name,
				"status": test_case.get_status_text(),
			})
	var skipped_scripts := 0
	for script_result: Dictionary in results.test_scripts.scripts.values():
		if script_result.props.skipped:
			skipped_scripts += 1
	var tracked_errors: Array[Dictionary] = []
	for test_id in gut.error_tracker.errors.items:
		for tracked_error: GutTrackedError in gut.error_tracker.errors.items[test_id]:
			if tracked_error.is_push_warning():
				continue
			tracked_errors.append({
				"code": tracked_error.code,
				"rationale": tracked_error.rationale,
				"file": tracked_error.file,
				"line": tracked_error.line,
				"expected": tracked_error.handled and test_id != GutUtils.NO_TEST,
			})
	var directory := OS.get_environment("OSTINATO_REPORT_DIR")
	if directory.is_empty():
		return # Editor runs use GUT's own results display.
	var file := FileAccess.open(directory.path_join("gut.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write GUT result.")
		set_exit_code(1)
		return
	file.store_string(JSON.stringify({
		"totals": results.test_scripts.props,
		"collected": collected,
		"skipped_scripts": skipped_scripts,
		"tracked_errors": tracked_errors,
	}, "  ") + "\n")
