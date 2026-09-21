class_name GlobalOptions
extends RefCounted

const ACTIONS: Array[StringName] = [
	&"move_north", &"move_northeast", &"move_east", &"move_southeast",
	&"move_south", &"move_southwest", &"move_west", &"move_northwest",
	&"wait", &"interact", &"character", &"spell_book", &"inventory", &"options", &"fullscreen",
]
var path: String
var bindings: Dictionary = {}
var fullscreen: bool = false
var alternate_palette: bool = false
var last_error: String = ""


func _init(settings_path: String = "user://options.json") -> void:
	path = settings_path
	for entry in [[&"inventory", KEY_I], [&"options", KEY_ESCAPE], [&"fullscreen", KEY_F11]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
			var event := InputEventKey.new()
			event.physical_keycode = entry[1]
			InputMap.action_add_event(entry[0], event)
	for action in ACTIONS:
		bindings[String(action)] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				bindings[String(action)].append(int(event.physical_keycode))


func load_options() -> void:
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	if not data.get("bindings") is Dictionary:
		return
	var used: Array[int] = []
	for action in ACTIONS:
		var keys: Variant = data.bindings.get(String(action))
		if not keys is Array or keys.is_empty():
			return
		for key in keys:
			if not (key is float or key is int) or key <= 0 or int(key) in used:
				return
			used.append(int(key))
	bindings = data.bindings
	fullscreen = data.get("fullscreen", false) == true
	alternate_palette = data.get("alternate_palette", false) == true
	apply_bindings()


func apply_bindings() -> void:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		for code in bindings[String(action)]:
			var event := InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(action, event)


func conflict(action: StringName, key: int) -> StringName:
	for candidate in ACTIONS:
		if candidate != action and key in bindings[String(candidate)]:
			return candidate
	return &""


func rebind(action: StringName, key: int, swap: bool = false) -> bool:
	last_error = ""
	if action not in ACTIONS or key in [0, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]:
		last_error = "Enter and Tab are reserved for menu navigation."
		return false
	var other := conflict(action, key)
	if other != &"" and not swap:
		last_error = "Key is assigned to %s. Confirm a swap." % other
		return false
	var previous: Array = bindings[String(action)].duplicate()
	if other != &"":
		# Transfer the complete previous action binding; no same-context duplicates.
		bindings[String(other)].erase(key)
		bindings[String(other)].append_array(previous)
	bindings[String(action)] = [key]
	apply_bindings()
	return save_options()


func save_options() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not save global options."
		return false
	file.store_string(JSON.stringify({"bindings": bindings, "fullscreen": fullscreen,
		"alternate_palette": alternate_palette}))
	file.flush()
	var success := file.get_error() == OK
	file.close()
	if not success:
		last_error = "Could not save global options."
	return success


func key_label(action: StringName) -> String:
	return OS.get_keycode_string(int(bindings[String(action)][0]))
