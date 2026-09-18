extends GutHookScript
## GUT's XML omits unrun tests and script skips. Preserve both for validation.


func run() -> void:
	var report: Dictionary = GutUtils.ResultExporter.new().get_results_dictionary(gut)
	var collected: Array[Dictionary] = []
	for test_script in gut.get_test_collector().scripts:
		for test_case in test_script.tests:
			collected.append({
				"script": test_script.get_full_name(),
				"name": test_case.name,
				"status": test_case.get_status_text(),
			})
	report["collected"] = collected
	var tracked_errors: Array[Dictionary] = []
	for test_id in gut.error_tracker.errors.items:
		for tracked_error: GutTrackedError in gut.error_tracker.errors.items[test_id]:
			if tracked_error.is_push_warning():
				continue
			tracked_errors.append({
				"test": str(test_id),
				"code": tracked_error.code,
				"rationale": tracked_error.rationale,
				"file": tracked_error.file,
				"function": tracked_error.function,
				"line": tracked_error.line,
				"expected": tracked_error.handled and test_id != GutUtils.NO_TEST and not (
					tracked_error.file == "modules/gdscript/gdscript_byte_codegen.cpp"
					and tracked_error.function == "write_return"
				),
			})
	report["tracked_errors"] = tracked_errors
	var report_directory := OS.get_environment("OSTINATO_REPORT_DIR")
	if report_directory.is_empty():
		report_directory = "res://reports"
	var report_path := report_directory.path_join("gut.json")
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("Cannot write GUT validation report: " + report_path)
		set_exit_code(1)
		return
	report_file.store_string(JSON.stringify(report, "  ") + "\n")
