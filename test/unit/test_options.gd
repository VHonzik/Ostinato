extends GutTest

var _options: GlobalOptions
var _original: Dictionary
var _path: String


func before_each() -> void:
	_path = "user://test_options_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	_options = GlobalOptions.new(_path)
	_original = _options.bindings.duplicate(true)


func after_each() -> void:
	_options.bindings = _original
	_options.apply_bindings()
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func test_conflicting_key_requires_explicit_swap_and_persists_globally() -> void:
	var old_north: Array = _options.bindings.move_north.duplicate()
	assert_false(_options.rebind(&"move_north", KEY_S))
	assert_eq(_options.bindings.move_north, old_north)
	assert_true(_options.rebind(&"move_north", KEY_S, true))
	assert_eq(_options.bindings.move_north, [KEY_S])
	assert_false(KEY_S in _options.bindings.move_south)
	for key in old_north:
		assert_true(key in _options.bindings.move_south)
	var loaded := GlobalOptions.new(_path)
	loaded.load_options()
	assert_eq(loaded.bindings.move_north, [float(KEY_S)])
	var event := InputEventKey.new()
	event.physical_keycode = KEY_S
	event.pressed = true
	assert_true(event.is_action_pressed("move_north"))
	assert_false(event.is_action_pressed("move_south"))


func test_reserved_menu_keys_are_rejected_without_changing_gameplay_bindings() -> void:
	assert_false(_options.rebind(&"interact", KEY_ENTER))
	assert_false(_options.rebind(&"interact", KEY_TAB))
	assert_eq(_options.bindings, _original)


func test_display_and_palette_preferences_persist_independently_of_game_state() -> void:
	_options.fullscreen = true
	_options.alternate_palette = true
	assert_true(_options.save_options())
	var loaded := GlobalOptions.new(_path)
	loaded.load_options()
	assert_true(loaded.fullscreen)
	assert_true(loaded.alternate_palette)


func test_hotbar_keys_are_global_distinct_from_numpad_and_conflicts_require_swap() -> void:
	assert_false(_options.rebind(&"hotbar_1", KEY_KP_1))
	assert_true(_options.rebind(&"hotbar_1", KEY_R))
	var loaded := GlobalOptions.new(_path)
	loaded.load_options()
	assert_eq(loaded.key_label(&"hotbar_1"), "R")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.pressed = true
	assert_true(event.is_action_pressed("hotbar_1"))
	event.physical_keycode = KEY_KP_1
	assert_true(event.is_action_pressed("move_southwest"))
	assert_false(event.is_action_pressed("hotbar_1"))


func test_older_options_keep_number_key_bindings_without_duplicate_hotbar_activation() -> void:
	var old_bindings := _options.bindings.duplicate(true)
	for index in range(1, 6):
		old_bindings.erase("hotbar_%d" % index)
	old_bindings.move_north = [KEY_1]
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"bindings": old_bindings,
		"fullscreen": true, "alternate_palette": true}))
	file.close()
	_options.load_options()
	assert_eq(_options.key_label(&"move_north"), "1")
	assert_eq(_options.key_label(&"hotbar_1"), "Unbound")
	assert_eq(_options.key_label(&"hotbar_2"), "2")
	assert_true(_options.fullscreen)
	assert_true(_options.alternate_palette)
	assert_false(_options.rebind(&"hotbar_1", KEY_1, true))
	assert_true(_options.save_options())
	var loaded := GlobalOptions.new(_path)
	loaded.load_options()
	assert_eq(loaded.key_label(&"hotbar_1"), "Unbound")
	assert_true(loaded.rebind(&"hotbar_1", KEY_R))
	loaded.load_options()
	assert_false(loaded.rebind(&"hotbar_1", KEY_1))
	assert_true(loaded.rebind(&"hotbar_1", KEY_1, true))
	assert_eq(loaded.key_label(&"move_north"), "R")
	assert_eq(loaded.key_label(&"hotbar_1"), "1")
