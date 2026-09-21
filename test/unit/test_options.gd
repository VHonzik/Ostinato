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
