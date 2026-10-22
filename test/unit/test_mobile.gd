extends GutTest

var _viewport: SubViewport
var _main: Control
var _game: Gameplay
var _adapter: MobileGameplayInput
var _directory: String
var _original_options: GlobalOptions

class RefusingStore extends SaveStore:
	func save_path(_session: GameSession, _path: String) -> bool:
		return _fail("Write refused; previous save preserved.")


func before_each() -> void:
	_original_options = GlobalOptions.new()
	_directory = "user://test_mobile_" + Crypto.new().generate_random_bytes(8).hex_encode()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	add_child_autofree(_viewport)
	_main = preload("res://mobile/main.tscn").instantiate()
	_viewport.add_child(_main)
	_game = _main.game
	_game.recovery = MobileRecoveryStore.new(_directory)
	_game.menu.recovery = _game.recovery
	_game.menu.options = GlobalOptions.new(_directory.path_join("options.json"))
	_game.menu.saves = SaveStore.new(_directory)
	_game.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_game.set_process(false)
	_adapter = _game.input_adapter


func after_each() -> void:
	_original_options.apply_bindings()
	# Menu rebuilds remove old rows immediately and free them at the frame boundary.
	await get_tree().process_frame
	if DirAccess.dir_exists_absolute(_directory):
		for file in DirAccess.get_files_at(_directory):
			DirAccess.remove_absolute(_directory.path_join(file))
		DirAccess.remove_absolute(_directory)


func _empty_world() -> void:
	_game.world = GridWorld.new(Rect2i(0, 0, 40, 28), Vector2i(20, 14))
	_game.session.world = _game.world
	_game.grid_view.world = _game.world
	_main.controls.refresh()


func _touch(slot: int, pressed: bool = true, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = _adapter.buttons[slot].get_global_rect().get_center()
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	_adapter.handle_input(event)


func test_mobile_resources_and_auras_refresh_and_follow_menu_visibility() -> void:
	var hero := _game.world.hero
	hero.health = hero.max_health - 1
	hero.rage = 25
	hero.experience = 1
	hero.learn_skill(SkillDefinition.catalog(&"relentless_assault_1"))
	hero.learn_skill(SkillDefinition.catalog(&"maelstrom_weapon_1"))
	hero.buffs[&"battle_shout_1"] = {"until": 20, "physical_percent": 10}
	_game.refresh_view()
	var hud := _game.hud
	assert_eq(hud.get_node("HealthBar/Fill").value, float(hero.health))
	assert_eq(hud.get_node("RageBar/Fill").value, 25.0)
	assert_eq(hud.get_node("ExperienceBar/Fill").value, 1.0)
	var auras := hud.get_node("Auras") as Control
	assert_eq(auras.get_child_count(), 1)
	assert_string_contains((auras.get_child(0) as Control).tooltip_text, "Battle Shout")
	for path in ["Auras", "HealthBar", "RageBar", "ExperienceBar", "ComboPointBar",
		"MaelstromWeaponBar"]:
		assert_true((hud.get_node(path) as Control).visible)
	_game.menu.open_player()
	for path in ["Auras", "HealthBar", "RageBar", "ExperienceBar", "ComboPointBar",
		"MaelstromWeaponBar"]:
		assert_false((hud.get_node(path) as Control).visible)
	_game.menu.close()
	for path in ["Auras", "HealthBar", "RageBar", "ExperienceBar", "ComboPointBar",
		"MaelstromWeaponBar"]:
		assert_true((hud.get_node(path) as Control).visible)
	hero.buffs.clear()
	_game.refresh_view()
	assert_eq(auras.get_child_count(), 0, "Expired auras leave the mobile container.")
	_game._return_to_menu()
	assert_false(auras.visible)


func test_all_eight_arrows_and_tap_only_wait_use_shared_turn_queue() -> void:
	_empty_world()
	for slot in range(9):
		var start := _game.world.player_tile
		var turn := _game.world.turn_count
		_touch(slot)
		_touch(slot, false)
		_game._process(0.0)
		_game._process(5.0)
		assert_eq(_game.world.player_tile, start + _adapter.directions[slot])
		assert_eq(_game.world.turn_count, turn + 1)


func test_hold_delay_repeat_release_and_slow_frame_do_not_burst_turns() -> void:
	_empty_world()
	_touch(5)
	_game._process(0.0)
	_game._process(0.45)
	assert_eq(_game.world.turn_count, 1)
	_game._process(0.05)
	assert_eq(_game.world.turn_count, 2)
	_game._process(0.15)
	assert_eq(_game.world.turn_count, 3)
	_game._process(20.0)
	assert_eq(_game.world.turn_count, 4)
	_touch(5, false)
	_game._process(20.0)
	assert_eq(_game.world.turn_count, 4)


func test_canceled_touch_and_drag_out_cancel_pending_movement() -> void:
	_empty_world()
	_touch(5)
	_touch(5, false, 0, true)
	_game._process(5.0)
	assert_eq(_game.world.turn_count, 0)
	_touch(5)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2.ZERO
	_adapter.handle_input(drag)
	_game._process(5.0)
	assert_eq(_game.world.turn_count, 0)


func test_ability_consumes_movement_hold_and_synthetic_mouse_is_ignored() -> void:
	_empty_world()
	_touch(5)
	_game._process(0.0)
	_game.request_slot(19)
	_game._process(10.0)
	assert_eq(_game.world.player_tile, Vector2i(21, 14))
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = _adapter.buttons[5].get_global_rect().get_center()
	_adapter.handle_input(mouse)
	_game._process(10.0)
	assert_eq(_game.world.player_tile, Vector2i(21, 14))


func test_second_finger_clears_hold_and_modal_rejects_movement() -> void:
	_empty_world()
	_touch(5)
	_game._process(0.0)
	var other := InputEventScreenTouch.new()
	other.index = 1
	other.position = Vector2(900, 100)
	other.pressed = true
	_adapter.handle_input(other)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 1)
	_game.menu.open_player()
	_touch(5)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 1)


func test_spell_inspection_is_free_and_assignment_uses_selected_slot() -> void:
	_game._open_hero_panel(true)
	var turns := _game.world.turn_count
	var skill: StringName = _game.hero_panel._skill_buttons[0].get_meta("skill_id")
	_game.hero_panel._skill_buttons[0].pressed.emit()
	assert_eq(_game.world.turn_count, turns)
	assert_true(_game.hero_panel.visible)
	_game.world.hotbar_locked = false
	_game._refresh_hotbar()
	_game.hero_panel.begin_assignment()
	_game.hotbar_panel.slots[7].pressed.emit()
	assert_eq(_game.world.hotbar[7], skill)
	assert_eq(_game.world.turn_count, turns)
	assert_false(_game.hero_panel.choosing_slot)


func test_bag_assignment_uses_hotbar_without_consuming_item_or_turn() -> void:
	_game.world.hotbar_locked = false
	_game.world.hero.inventory[0] = ItemData.instance(118, 2)
	var turn := _game.world.turn_count
	_game.menu.open_bags()
	_game.menu._assign_active_item(0)
	assert_false(_game.menu.visible)
	assert_true(_game.hero_panel.choosing_slot)
	_game.hotbar_panel.slots[6].pressed.emit()
	assert_eq(_game.world.hotbar[6], ItemData.POTION_HOTBAR_ID)
	assert_eq(int(_game.world.hero.inventory[0].quantity), 2)
	assert_eq(_game.world.turn_count, turn)


func test_pause_cancels_queued_movement_and_resume_requires_fresh_input() -> void:
	_empty_world()
	_touch(5)
	_main.suspend()
	_game._process(20.0)
	assert_true(_game.suspended)
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.process_mode, Node.PROCESS_MODE_DISABLED)
	_main.resume_game()
	_game.set_process(false)
	_game._process(20.0)
	assert_eq(_game.world.turn_count, 0)
	_touch(5)
	_game._process(0.0)
	assert_eq(_game.world.turn_count, 1)


func test_backgrounded_cast_does_not_advance_until_explicit_resume() -> void:
	_empty_world()
	_game.world.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	_game.world.hero.rage = 100
	var enemy := GridActor.new(_game.world.player_tile + Vector2i(2, 0))
	enemy.relationship = GridActor.Relationship.NEUTRAL
	enemy.health = 100
	enemy.max_health = 100
	enemy.stunned_until = 1000
	_game.world.actors.append(enemy)
	assert_true(_game.world.cast_skill(&"lava_burst_1", enemy))
	_game.refresh_view()
	assert_not_null(_game.world.pending_skill)
	var turn := _game.world.turn_count
	var elapsed := _game.world.cast_elapsed
	_main.suspend()
	_game._process(20.0)
	assert_eq(_game.world.turn_count, turn)
	assert_eq(_game.world.cast_elapsed, elapsed)
	_main.resume_game()
	_game.set_process(false)
	_game._process(Gameplay.MELEE_BOUNDARY_SECONDS)
	assert_gt(_game.world.turn_count, turn)


func test_native_ui_viewport_touch_routes_one_action_and_modal_blocks_it() -> void:
	_empty_world()
	var event := InputEventScreenTouch.new()
	event.position = _adapter.buttons[5].get_global_rect().get_center()
	event.pressed = true
	_main.get_node("UiContainer/UiViewport").push_input(event, true)
	event.pressed = false
	_main.get_node("UiContainer/UiViewport").push_input(event, true)
	_game._process(0.0)
	assert_eq(_game.world.turn_count, 1)
	_game.request_menu()
	event.pressed = true
	_main.get_node("UiContainer/UiViewport").push_input(event, true)
	_game._process(5.0)
	assert_eq(_game.world.turn_count, 1)


func test_failed_checkpoint_preserves_recovery_bytes_and_reports_error() -> void:
	assert_true(_game.recovery.checkpoint(_game.session))
	var previous := FileAccess.get_file_as_string(_game.recovery.path())
	_game.recovery.store = RefusingStore.new(_directory)
	_game.world.hero.copper += 1
	assert_false(_game.recovery.checkpoint(_game.session))
	assert_eq(FileAccess.get_file_as_string(_game.recovery.path()), previous)
	assert_string_contains(_game.recovery.last_error, "Write refused")


func test_log_and_back_navigation_do_not_spend_turns() -> void:
	_game.world.add_message("A test announcement.")
	var turns := _game.world.turn_count
	_game.request_menu()
	_game.menu.open_log()
	assert_eq(_game.menu.page, "log")
	_main.controls.back()
	assert_eq(_game.menu.page, "player")
	_main.controls.back()
	assert_false(_game.menu.visible)
	assert_eq(_game.world.turn_count, turns)


func test_accepting_quests_and_tapping_leave_restores_movement_without_another_action() -> void:
	var marshal := _game.world.actors[0]
	_game.world.hero.level = 2
	_game.world.player_tile = marshal.tile + Vector2i.DOWN
	_game.refresh_view()
	_game.menu.open_conversation(marshal)
	for identifier: String in ["valley_wolves", "valley_camp", "valley_mine"]:
		var quest_title: String = QuestData.QUESTS[identifier].title
		var quest_buttons := _game.menu._buttons.filter(func(button: Button) -> bool:
			return button.text.contains("! " + quest_title))
		assert_eq(quest_buttons.size(), 1)
		if quest_buttons.size() != 1:
			return
		quest_buttons[0].pressed.emit()
		assert_eq(_game.menu.page, "quest_detail")
		var accept_buttons := _game.menu._buttons.filter(func(button: Button) -> bool:
			return button.text == "Accept")
		assert_eq(accept_buttons.size(), 1)
		if accept_buttons.size() != 1:
			return
		accept_buttons[0].pressed.emit()
		assert_true(_game.world.quests.has(identifier))
		assert_eq(_game.menu.page, "conversation")
	var leave: Button = _game.menu._buttons.back()
	assert_eq(leave.text, "Leave")
	leave.grab_focus()
	leave.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_game.menu.visible)
	assert_true(_main.controls.pad.visible)
	assert_false((_adapter.buttons[7] as Button).disabled)
	assert_eq(_game.world.turn_count, 0)
	var tile := _game.world.player_tile
	_touch(7)
	_touch(7, false)
	_game._process(0.0)
	assert_eq(_game.world.player_tile, tile + Vector2i.DOWN)
	assert_eq(_game.world.turn_count, 1)


func test_movement_controls_reenable_after_focus_and_attack_animation_release() -> void:
	_empty_world()
	_game.hotbar_panel.lock_button.grab_focus()
	_main.controls._process(0.0)
	assert_true(_main.controls.pad.visible)
	assert_true((_adapter.buttons[5] as Button).disabled)
	_game.hotbar_panel.lock_button.release_focus()
	_main.controls._process(0.0)
	assert_false((_adapter.buttons[5] as Button).disabled)
	_game.grid_view._queue_melee_bump(null, _game.world.player_tile + Vector2i.RIGHT)
	_main.controls._process(0.0)
	assert_true((_adapter.buttons[5] as Button).disabled)
	_game.grid_view._process(1.0)
	_main.controls._process(0.0)
	assert_true(_main.controls.pad.visible)
	assert_false((_adapter.buttons[5] as Button).disabled)
	assert_eq(_game.world.turn_count, 0)


func test_recovery_keeps_manual_slots_and_manual_saved_marker_independent() -> void:
	assert_true(_game.menu.saves.save_slot(_game.session, 1))
	_game.session.mark_saved()
	var manual := FileAccess.get_file_as_string(_game.menu.saves.slot_path(1))
	_game.world.hero.copper += 1
	assert_true(_game.recovery.checkpoint(_game.session))
	assert_true(_game.session.has_unsaved_changes())
	assert_eq(FileAccess.get_file_as_string(_game.menu.saves.slot_path(1)), manual)
	var copper := _game.world.hero.copper
	_game.world.hero.copper += 100
	assert_true(_game.recovery.restore(_game.session))
	assert_eq(_game.world.hero.copper, copper)
	assert_eq(_game.recovery.metadata(_game.session).status, "Occupied")


func test_recovery_rejects_combat_and_preserves_file_and_world_on_bad_load() -> void:
	assert_true(_game.recovery.checkpoint(_game.session))
	var previous := FileAccess.get_file_as_string(_game.recovery.path())
	_game.world.actors[0].engaged = true
	assert_true(_game.recovery.checkpoint(_game.session))
	assert_eq(FileAccess.get_file_as_string(_game.recovery.path()), previous)
	var file := FileAccess.open(_game.recovery.path(), FileAccess.WRITE)
	file.store_string("{bad")
	file.close()
	var world := _game.world
	assert_false(_game.recovery.restore(_game.session))
	assert_same(_game.world, world)
	assert_string_contains(_game.recovery.last_error, "preserved")
	assert_eq(DirAccess.get_files_at(_directory).size(), 1)


func test_loop_reset_replaces_recovery_and_completion_clears_it() -> void:
	_game.world.hero.health = 0
	_game.refresh_view()
	_game._process(0.0)
	assert_eq(int(_game.recovery.metadata(_game.session).loop), 2)
	_game.world.attempt_state = GridWorld.AttemptState.COMPLETED
	_game.refresh_view()
	_game._process(0.0)
	assert_false(FileAccess.file_exists(_game.recovery.path()))


func test_new_game_from_main_requires_confirmation_before_replacing_recovery() -> void:
	assert_true(_game.recovery.checkpoint(_game.session))
	var previous := FileAccess.get_file_as_string(_game.recovery.path())
	_game._return_to_menu()
	_game.menu.open_main()
	var seed_value := GameSession.WORLD_SEEDS[1].hash()
	_game.menu._new_game(seed_value)
	assert_eq(_game.menu.page, "confirm")
	assert_false(_game.active_game)
	assert_eq(FileAccess.get_file_as_string(_game.recovery.path()), previous)
	_game.menu._buttons[0].pressed.emit()
	_game._process(0.0)
	assert_true(_game.active_game)
	assert_eq(_game.session.seed_value, seed_value)
	assert_ne(FileAccess.get_file_as_string(_game.recovery.path()), previous)
