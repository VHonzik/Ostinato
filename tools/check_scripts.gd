extends SceneTree
## Load first-party scripts in one engine process instead of one process per file.


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not FileAccess.file_exists(arguments[0]):
		push_error("Expected a script manifest path.")
		quit(1)
		return
	var paths := FileAccess.get_file_as_string(arguments[0]).strip_edges().split("\n")
	var checked := 0
	for path in paths:
		var script := load(path.strip_edges()) as GDScript
		if script == null or not script.can_instantiate():
			push_error("Cannot load script: " + path)
			quit(1)
			return
		checked += 1
	print("Checked %d scripts." % checked)
	quit(0)
