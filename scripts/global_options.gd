class_name GlobalOptions
extends RefCounted

const ACTIONS: Array[StringName] = [
	&"move_north", &"move_northeast", &"move_east", &"move_southeast",
	&"move_south", &"move_southwest", &"move_west", &"move_northwest",
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5",
	&"hotbar_6", &"hotbar_7", &"hotbar_8", &"hotbar_9", &"hotbar_10", &"hotbar_11", &"hotbar_12",
	&"hotbar_13", &"hotbar_14", &"hotbar_15", &"hotbar_16",
	&"hotbar_17", &"hotbar_18", &"hotbar_19", &"hotbar_20",
	&"player_menu",
	&"wait", &"interact", &"character", &"spell_book", &"inventory", &"quest_log", &"options", &"fullscreen",
]
const HOTBAR_KEYS: Array[Key] = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_R, KEY_T, KEY_G, KEY_V,
	KEY_1 | KEY_MASK_SHIFT, KEY_2 | KEY_MASK_SHIFT, KEY_3 | KEY_MASK_SHIFT,
	KEY_4 | KEY_MASK_SHIFT, KEY_5 | KEY_MASK_SHIFT, KEY_6 | KEY_MASK_SHIFT,
	KEY_R | KEY_MASK_SHIFT, KEY_T | KEY_MASK_SHIFT, KEY_G | KEY_MASK_SHIFT, KEY_V | KEY_MASK_SHIFT,
]

var path: String
var bindings: Dictionary = {}
var fullscreen: bool = false
var alternate_palette: bool = false
var last_error: String = ""


func _init(settings_path: String = "user://options.json") -> void:
	path = settings_path
	var defaults: Array = [[&"player_menu", KEY_M], [&"quest_log", KEY_J],
		[&"inventory", KEY_I], [&"options", KEY_ESCAPE], [&"fullscreen", KEY_F11]]
	for index in range(HOTBAR_KEYS.size()):
		defaults.append([StringName("hotbar_%d" % (index + 1)), HOTBAR_KEYS[index]])
	for entry in defaults:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
			var event := key_event(entry[1])
			InputMap.action_add_event(entry[0], event)
	for action in ACTIONS:
		bindings[String(action)] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				bindings[String(action)].append(int(event.get_physical_keycode_with_modifiers()))


func load_options() -> void:
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	if not data.get("bindings") is Dictionary:
		return
	var restored: Dictionary = {}
	var used: Array[int] = []
	# Validate saved actions first. New hotbar defaults must not steal older bindings.
	for action in ACTIONS:
		if not data.bindings.has(String(action)):
			continue
		var keys: Variant = data.bindings[String(action)]
		if not keys is Array or (keys.is_empty() and not _can_be_unbound(action)):
			return
		for key in keys:
			if not (key is float or key is int) or key <= 0 or int(key) in used:
				return
			used.append(int(key))
		restored[String(action)] = keys.duplicate()
	for action in ACTIONS:
		if restored.has(String(action)):
			continue
		var keys: Array = bindings[String(action)].duplicate()
		for key in keys.duplicate():
			if int(key) in used:
				if not _can_be_unbound(action):
					return
				keys.erase(key)
			else:
				used.append(int(key))
		restored[String(action)] = keys
	bindings = restored
	fullscreen = data.get("fullscreen", false) == true
	alternate_palette = data.get("alternate_palette", false) == true
	apply_bindings()


func apply_bindings() -> void:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		for code in bindings[String(action)]:
			var event := key_event(int(code))
			InputMap.action_add_event(action, event)


func conflict(action: StringName, key: int) -> StringName:
	for candidate in ACTIONS:
		if candidate == action:
			continue
		for bound_key in bindings[String(candidate)]:
			if int(bound_key) == key:
				return candidate
	return &""


func rebind(action: StringName, key: int, swap: bool = false) -> bool:
	last_error = ""
	if action not in ACTIONS or (key & KEY_CODE_MASK) in [
		0, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
	]:
		last_error = "Enter and Tab are reserved for menu navigation."
		return false
	var other := conflict(action, key)
	if other != &"" and not swap:
		last_error = "Key is assigned to %s. Confirm a swap." % other
		return false
	var previous: Array = bindings[String(action)].duplicate()
	if other != &"" and previous.is_empty():
		last_error = "Bind an unused key before swapping an unbound slot."
		return false
	if other != &"":
		# Transfer the complete previous action binding; no same-context duplicates.
		for bound_key in bindings[String(other)].duplicate():
			if int(bound_key) == key:
				bindings[String(other)].erase(bound_key)
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
	var keys: Array = bindings[String(action)]
	return "Unbound" if keys.is_empty() else OS.get_keycode_string(int(keys[0]))


func _can_be_unbound(action: StringName) -> bool:
	return String(action).begins_with("hotbar_") or action == &"player_menu"


static func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code & KEY_CODE_MASK
	event.shift_pressed = (code & KEY_MASK_SHIFT) != 0
	event.ctrl_pressed = (code & KEY_MASK_CTRL) != 0
	event.alt_pressed = (code & KEY_MASK_ALT) != 0
	event.meta_pressed = (code & KEY_MASK_META) != 0
	return event
