extends RefCounted
## Only the launcher supplies output paths; game code never depends on the bench.


static func write_result(value: Variant) -> bool:
	var directory := OS.get_environment("OSTINATO_BENCH_DIR")
	if directory.is_empty():
		push_error("Run simulations with tools/simulate.ps1.")
		return false
	var file := FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write bench result: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		push_error("Cannot flush bench result: " + error_string(error))
	return error == OK
