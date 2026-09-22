extends GutTest

var _directory: String
var _saves: SaveStore
var _session: GameSession


func before_each() -> void:
	_directory = "user://test_saves_" + Crypto.new().generate_random_bytes(8).hex_encode()
	_saves = SaveStore.new(_directory)
	_session = GameSession.new()
	_session.new_game(123456789)


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_directory):
		for file in DirAccess.get_files_at(_directory):
			DirAccess.remove_absolute(_directory.path_join(file))
		DirAccess.remove_absolute(_directory)


func test_five_slots_save_copy_overwrite_confirmation_and_seed_preservation() -> void:
	for slot in range(1, 6):
		assert_eq(_saves.metadata(slot).status, "Empty")
		assert_true(_saves.save_slot(_session, slot), _saves.last_error)
		assert_eq(_saves.metadata(slot).status, "Occupied")
		assert_eq(_saves.metadata(slot).loop, 1.0)
	assert_false(_saves.save_slot(_session, 6))
	var original := FileAccess.get_file_as_bytes(_saves.slot_path(1))
	_session.world.wait_turn()
	assert_false(_saves.save_slot(_session, 1))
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(1)), original)
	assert_true(_saves.save_slot(_session, 1, true), _saves.last_error)
	assert_ne(FileAccess.get_file_as_bytes(_saves.slot_path(1)), original)
	assert_true(_saves.load_slot(_session, 2), _saves.last_error)
	assert_eq(_session.seed_value, 123456789)
	assert_eq(_session.world.turn_count, 0)


func test_full_round_trip_restores_random_streams_effects_outfit_and_future_arrival() -> void:
	_session.world.hero.health = 0
	_session.restart_after_death()
	_session.select_class(&"Druid")
	_session.world.train(&"Druid", &"healing_touch_1")
	_session.world.train(&"Druid", &"mark_1")
	_session.world.hero.casting_credit = 0.6
	_session.world.movement_credit = 0.5
	_session.world.hero.copper = 200
	_session.world.hotbar[0] = &"healing_touch_1"
	_session.world.hotbar_locked = true
	_session.world.cast_skill(&"mark_1")
	for index in range(12):
		_session.world.wait_turn()
	assert_true(_saves.save_slot(_session, 1), _saves.last_error)
	var before := JSON.stringify(SaveCodec.capture(_session))
	for index in range(8):
		_session.world.wait_turn()
	var expected := JSON.stringify(SaveCodec.capture(_session))
	assert_true(_saves.load_slot(_session, 1), _saves.last_error)
	assert_eq(JSON.stringify(SaveCodec.capture(_session)), before)
	for index in range(8):
		_session.world.wait_turn()
	assert_eq(JSON.stringify(SaveCodec.capture(_session)), expected)


func test_combat_and_pending_actions_cannot_save_and_load_discards_continuation() -> void:
	assert_true(_saves.save_slot(_session, 1), _saves.last_error)
	var original := FileAccess.get_file_as_bytes(_saves.slot_path(1))
	var actor := GridActor.new(_session.world.player_tile + Vector2i.DOWN)
	actor.relationship = GridActor.Relationship.HOSTILE
	_session.world.actors.append(actor)
	_session.world.hero.swing.remaining = 10
	_session.world.request_melee(actor)
	assert_false(_saves.save_slot(_session, 1, true))
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(1)), original)
	var abandoned := _session.world
	assert_true(_saves.load_slot(_session, 1), _saves.last_error)
	assert_null(abandoned.pending_melee)
	assert_eq(_session.world.turn_count, 0)
	_session.world.hero.learn_skill(SkillRank.catalog(&"healing_touch_1"))
	_session.world.cast_skill(&"healing_touch_1")
	assert_false(_saves.save_slot(_session, 2))
	assert_false(FileAccess.file_exists(_saves.slot_path(2)))


func test_damage_is_preserved_byte_for_byte_and_no_partial_state_is_loaded() -> void:
	assert_true(_saves.save_slot(_session, 1), _saves.last_error)
	var file := FileAccess.open(_saves.slot_path(1), FileAccess.WRITE)
	file.store_string("{broken save bytes")
	file.close()
	var original := FileAccess.get_file_as_bytes(_saves.slot_path(1))
	var world := _session.world
	assert_false(_saves.load_slot(_session, 1))
	assert_same(_session.world, world)
	assert_string_contains(_saves.last_error, "preserved")
	var metadata := _saves.metadata(1)
	assert_eq(metadata.status, "Damaged")
	assert_eq(FileAccess.get_file_as_bytes(_directory.path_join(metadata.file)), original)
	assert_false(_saves.save_slot(_session, 1))
	assert_true(_saves.save_slot(_session, 1, true), _saves.last_error)
	assert_true(FileAccess.file_exists(_directory.path_join(metadata.file)))


func test_unsupported_schema_stays_unchanged() -> void:
	assert_true(_saves.save_slot(_session, 1), _saves.last_error)
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_saves.slot_path(1)))
	record.revision = SaveStore.REVISION + 1
	var file := FileAccess.open(_saves.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	var bytes := FileAccess.get_file_as_bytes(_saves.slot_path(1))
	assert_false(_saves.load_slot(_session, 1))
	assert_string_contains(_saves.last_error, "Incompatible")
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(1)), bytes)


func test_write_and_replacement_failures_preserve_previous_save() -> void:
	assert_true(_saves.save_slot(_session, 1), _saves.last_error)
	var bytes := FileAccess.get_file_as_bytes(_saves.slot_path(1))
	DirAccess.make_dir_recursive_absolute(_saves.slot_path(1) + ".tmp")
	assert_false(_saves.save_slot(_session, 1, true))
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(1)), bytes)
	DirAccess.remove_absolute(_saves.slot_path(1) + ".tmp")
	var impossible := SaveStore.new(_saves.slot_path(1))
	assert_false(impossible.save_slot(_session, 1))
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(1)), bytes)


func test_malformed_state_rejects_without_script_errors() -> void:
	var state := SaveCodec.capture(_session)
	for broken in [null, [], {}, {"loop": 1}]:
		assert_null(SaveCodec.restore(broken, true))
	var bad := state.duplicate(true)
	bad.hero.health = "invalid"
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.inventory[0] = {"id": 999999, "quantity": 1, "starter": false}
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.world.player_tile = [-9999, 0]
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.random = 9223372036854775807
	assert_null(SaveCodec.restore(bad, true), "RNG state must use lossless decimal text.")


func test_malformed_slot_metadata_is_safe_to_display_and_preserves_bytes_on_load() -> void:
	for broken in [{"timestamp": []}, {"loop": []}, {"loop": "invalid"}]:
		assert_true(_saves.save_slot(_session, 1, true), _saves.last_error)
		var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_saves.slot_path(1)))
		if broken.has("timestamp"):
			record.timestamp = broken.timestamp
		else:
			record.data.loop = broken.loop
		var file := FileAccess.open(_saves.slot_path(1), FileAccess.WRITE)
		file.store_string(JSON.stringify(record))
		file.close()
		var bytes := FileAccess.get_file_as_bytes(_saves.slot_path(1))
		assert_eq(_saves.metadata(1).status, "Damaged")
		assert_false(_saves.load_slot(_session, 1))
		var retained := _saves.last_error.trim_prefix("Damaged save preserved as ")
		assert_eq(FileAccess.get_file_as_bytes(_directory.path_join(retained)), bytes)


func test_save_does_not_impose_a_progression_level_cap() -> void:
	_session.world.hero.level = 100001
	_session.world.hero._apply_level_stats()
	assert_true(_saves.save_slot(_session, 1), _saves.last_error)
	_session.new_game(9)
	assert_true(_saves.load_slot(_session, 1), _saves.last_error)
	assert_eq(_session.world.hero.level, 100001)
