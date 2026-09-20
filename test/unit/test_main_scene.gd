extends GutTest

var _viewport: SubViewport
var _main: Control
var _game_viewport: SubViewport
var _game: MovementGame


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	add_child_autofree(_viewport)
	var main_scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	assert_not_null(main_scene, "The configured startup scene must load.")
	_main = main_scene.instantiate() as Control
	_viewport.add_child(_main)
	_game_viewport = _main.get_node("GameContainer/GameViewport") as SubViewport
	_game = _game_viewport.get_node("MovementGame") as MovementGame
	await get_tree().process_frame
	await get_tree().process_frame


func test_startup_shows_the_game_title_and_playable_fixture() -> void:
	var title := _game.get_node("HUD/Top/Rows/Heading/Title") as Label
	assert_true(_main.is_node_ready())
	assert_true(title.is_visible_in_tree())
	assert_string_contains(title.text, "OSTINATO")
	assert_eq(_game.world.player_tile, Vector2i(20, 14))
	assert_eq(_game.world.turn_count, 0)
	assert_gt(_game.world.actors.size(), 0)


func test_title_and_controls_fit_at_minimum_window_size() -> void:
	var visible_area := Rect2(Vector2.ZERO, Vector2(640, 360))
	for path in [
		"HUD/Top", "HUD/Top/Rows/Heading/Title", "HUD/Top/Rows/Heading/Reset",
		"HUD/Top/Rows/Status", "HUD/Bottom", "HUD/Bottom/Rows/Controls",
		"HUD/Bottom/Rows/Legend", "HUD/Bottom/Rows/Feedback",
	]:
		var control := _game.get_node(path) as Control
		assert_true(control.is_visible_in_tree(), path)
		assert_true(visible_area.encloses(control.get_global_rect()), path + " fits.")
		assert_gte(control.size.x, control.get_minimum_size().x, path + " is not clipped.")


func test_resizing_uses_whole_pixels_and_expands_the_centered_world() -> void:
	var container := _main.get_node("GameContainer") as SubViewportContainer
	for scenario in [
		[Vector2i(640, 360), Vector2i(640, 360), 1, Vector2.ZERO],
		[Vector2i(1279, 719), Vector2i(1279, 719), 1, Vector2.ZERO],
		[Vector2i(1280, 720), Vector2i(640, 360), 2, Vector2.ZERO],
		[Vector2i(1280, 800), Vector2i(640, 400), 2, Vector2.ZERO],
		[Vector2i(1919, 1079), Vector2i(959, 539), 2, Vector2.ZERO],
		[Vector2i(1920, 1080), Vector2i(640, 360), 3, Vector2.ZERO],
		[Vector2i(1922, 1082), Vector2i(640, 360), 3, Vector2.ONE],
		[Vector2i(1366, 768), Vector2i(683, 384), 2, Vector2.ZERO],
		[Vector2i(1283, 803), Vector2i(641, 401), 2, Vector2.ZERO],
	]:
		_viewport.size = scenario[0]
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(_game_viewport.size, scenario[1])
		assert_eq(container.scale, Vector2.ONE * scenario[2])
		assert_eq(container.position, scenario[3], "Remainders split on whole physical pixels.")
		assert_eq(_game.world.turn_count, 0, "Resizing never advances simulation.")
		_assert_camera_centered()


func test_camera_follows_movement_and_remains_centered_at_all_map_edges() -> void:
	_game.world.move_player(Vector2i.LEFT)
	_game.refresh_view()
	_assert_camera_centered()
	for tile in [Vector2i.ZERO, Vector2i(39, 0), Vector2i(0, 27), Vector2i(39, 27)]:
		_game.world.player_tile = tile
		_game.refresh_view()
		_assert_camera_centered()
	_game.reset_fixture()
	_assert_camera_centered()


func test_real_time_frames_do_not_advance_the_world() -> void:
	var random_before := _game.world.random.state
	await wait_seconds(0.1)
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.random.state, random_before)


func test_all_letter_and_numpad_movement_bindings_reach_gameplay() -> void:
	for pair in [
		[KEY_W, Vector2i.UP], [KEY_E, Vector2i(1, -1)], [KEY_D, Vector2i.RIGHT],
		[KEY_C, Vector2i(1, 1)], [KEY_S, Vector2i.DOWN], [KEY_Z, Vector2i(-1, 1)],
		[KEY_A, Vector2i.LEFT], [KEY_Q, Vector2i(-1, -1)],
		[KEY_KP_8, Vector2i.UP], [KEY_KP_9, Vector2i(1, -1)],
		[KEY_KP_6, Vector2i.RIGHT], [KEY_KP_3, Vector2i(1, 1)],
		[KEY_KP_2, Vector2i.DOWN], [KEY_KP_1, Vector2i(-1, 1)],
		[KEY_KP_4, Vector2i.LEFT], [KEY_KP_7, Vector2i(-1, -1)],
	]:
		_game.world = GridWorld.new(Rect2i(0, 0, 40, 28), Vector2i(20, 14))
		_game.grid_view.world = _game.world
		await _tap_key(pair[0])
		assert_eq(_game.world.player_tile, Vector2i(20, 14) + pair[1])
		assert_eq(_game.world.turn_count, 1)


func test_simultaneous_arrow_pairs_make_one_diagonal_turn() -> void:
	for pair in [
		[KEY_UP, KEY_RIGHT, Vector2i(1, -1)],
		[KEY_DOWN, KEY_RIGHT, Vector2i(1, 1)],
		[KEY_DOWN, KEY_LEFT, Vector2i(-1, 1)],
		[KEY_UP, KEY_LEFT, Vector2i(-1, -1)],
	]:
		_game.world = GridWorld.new(Rect2i(0, 0, 40, 28), Vector2i(20, 14))
		_game.grid_view.world = _game.world
		for key: Key in [pair[0], pair[1]]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			event.keycode = key
			event.pressed = true
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			_viewport.push_input(event)
		await get_tree().process_frame
		await get_tree().process_frame
		for key: Key in [pair[0], pair[1]]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			event.keycode = key
			event.pressed = false
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			_viewport.push_input(event)
		assert_eq(_game.world.player_tile, Vector2i(20, 14) + pair[2])
		assert_eq(_game.world.turn_count, 1)

func test_both_wait_keys_advance_exactly_one_turn_and_top_row_does_not_move() -> void:
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)
	await _tap_key(KEY_KP_5)
	assert_eq(_game.world.turn_count, 2)
	await _tap_key(KEY_5)
	await _tap_key(KEY_1)
	assert_eq(_game.world.turn_count, 2)
	assert_eq(_game.world.player_tile, Vector2i(20, 14))


func test_key_echo_does_not_advance_time() -> void:
	_send_key(KEY_PERIOD, true, true)
	await get_tree().process_frame
	assert_eq(_game.world.turn_count, 0)


func test_focused_fixture_controls_suppress_gameplay_until_escape() -> void:
	var button := _game.get_node("HUD/Top/Rows/Heading/Fast") as Button
	button.grab_focus()
	await _tap_key(KEY_S)
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	assert_null(_game_viewport.gui_get_focus_owner())
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)


func test_fixture_speed_and_reset_controls_preserve_then_clear_credit() -> void:
	_game.world.movement_credit = 0.5
	var button := _game.get_node("HUD/Top/Rows/Heading/Fast") as Button
	button.pressed.emit()
	assert_eq(_game.world.movement_speed, 1.5)
	assert_eq(_game.world.movement_credit, 0.5)
	assert_eq(_game.world.turn_count, 0)
	_game.world.wait_turn()
	(_game.get_node("HUD/Top/Rows/Heading/Reset") as Button).pressed.emit()
	assert_eq(_game.world.movement_speed, 1.0)
	assert_eq(_game.world.movement_credit, 0.0)
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.player_tile, Vector2i(20, 14))
	_assert_camera_centered()


func _assert_camera_centered() -> void:
	var center := GridView.tile_center(_game.world.player_tile)
	var player_screen := _game_viewport.canvas_transform * center
	assert_almost_eq(player_screen, Vector2(_game_viewport.size) / 2.0, Vector2.ONE * 0.01)


func _tap_key(key: Key) -> void:
	_send_key(key, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_send_key(key, false)


func _send_key(key: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	_viewport.push_input(event)


func test_character_and_spell_book_keyboard_flow_casts_and_levels() -> void:
	await _tap_key(KEY_P)
	assert_true(_game.hero_panel.visible)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
	assert_true(_game.hero_panel.visible)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Fireball")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.turn_count, 0, "Starting spells are informational previews.")
	await _tap_key(KEY_D)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Practice")
	await _tap_key(KEY_S)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "450 XP")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.turn_count, 1)
	assert_eq([_game.world.hero.level, _game.world.hero.experience], [2, 50])
	assert_eq(_game.world.player_tile, Vector2i(20, 14))
	var chat := _game.get_node("HUD/Bottom/Rows/Chat") as RichTextLabel
	assert_string_contains(chat.text, "450 XP")
	assert_string_contains(chat.text, "level 2")
	var status := _game.get_node("HUD/Top/Rows/HeroStatus") as Label
	assert_string_contains(status.text, "Lv 2")
	assert_string_contains(status.text, "Mana 250/250")
	await _tap_key(KEY_ESCAPE)
	assert_false(_game.hero_panel.visible)
	assert_null(_game_viewport.gui_get_focus_owner())
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 2)


func test_opening_panel_cancels_queued_movement_and_modal_focus_cannot_escape() -> void:
	_send_key(KEY_S, true)
	_send_key(KEY_K, true)
	await get_tree().process_frame
	_send_key(KEY_S, false)
	_send_key(KEY_K, false)
	assert_true(_game.hero_panel.visible)
	assert_eq(_game.world.turn_count, 0)
	for index in range(12):
		await _tap_key(KEY_TAB)
		assert_true(_game.hero_panel.is_ancestor_of(_game_viewport.gui_get_focus_owner()))
	await _tap_key(KEY_PERIOD)
	await _tap_key(KEY_KP_5)
	await _tap_key(KEY_Q)
	await _tap_key(KEY_C)
	assert_eq(_game.world.turn_count, 0)
	await wait_seconds(0.1)
	assert_eq(_game.world.turn_count, 0)


func test_mouse_buttons_open_panels_and_reset_clears_hero_and_chat() -> void:
	(_game.get_node("HUD/Top/Rows/HeroStatus/Spells") as Button).pressed.emit()
	assert_true(_game.hero_panel.visible)
	_game.hero_panel.change_tab(1)
	for button: Button in _game.hero_panel.find_children("*", "Button", true, false):
		if button.text.begins_with("Gain 450"):
			button.pressed.emit()
	assert_eq(_game.world.hero.level, 2)
	_game.hero_panel.close()
	(_game.get_node("HUD/Top/Rows/Heading/Reset") as Button).pressed.emit()
	assert_eq([_game.world.hero.level, _game.world.hero.experience], [1, 0])
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.messages.size(), 1)
	assert_false(_game.hero_panel.visible)
	(_game.get_node("HUD/Top/Rows/HeroStatus/Character") as Button).pressed.emit()
	assert_true(_game.hero_panel.visible)

	await get_tree().process_frame


func test_hero_panels_and_hud_fit_at_minimum_content_size() -> void:
	var area := Rect2(0, 0, 640, 360)
	for path in ["HUD/Top/Rows/HeroStatus", "HUD/Top/Rows/HeroStatus/Character",
		"HUD/Top/Rows/HeroStatus/Spells", "HUD/Bottom/Rows/Chat"]:
		var control := _game.get_node(path) as Control
		assert_true(area.encloses(control.get_global_rect()), path)
	_game.hero_panel.open(_game.world.hero, false)
	for tab in range(3):
		await get_tree().process_frame
		await get_tree().process_frame
		for control: Control in _game.hero_panel.find_children("*", "Control", true, false):
			if control.is_visible_in_tree():
				assert_true(area.encloses(control.get_global_rect()), control.name)
				if control is Label or control is Button:
					assert_gte(control.size.x, control.get_minimum_size().x, control.name)
		_game.hero_panel.change_tab(1)


func test_release_spell_book_has_no_development_tab_or_controls() -> void:
	_game.hero_panel.open(HeroState.new(false), true)
	var tabs := _game.hero_panel.find_children("*", "TabContainer", true, false)[0] as TabContainer
	assert_eq(tabs.get_tab_count(), 2)
	assert_eq(tabs.get_tab_title(1), "Mage")
	for button: Button in _game.hero_panel.find_children("*", "Button", true, false):
		assert_false(button.text.contains("450 XP"))
		assert_false(button.text.contains("Death trigger"))


func test_shift_tab_navigates_backward_inside_the_panel() -> void:
	await _tap_key(KEY_K)
	var focused := _game_viewport.gui_get_focus_owner()
	await _tap_key(KEY_TAB)
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.shift_pressed = true
	event.pressed = true
	_viewport.push_input(event)
	await get_tree().process_frame
	event.pressed = false
	_viewport.push_input(event)
	assert_same(_game_viewport.gui_get_focus_owner(), focused)
	assert_eq(_game.world.turn_count, 0)


func test_interaction_keyboard_preselection_wrap_and_cancel_are_free() -> void:
	_game.world.actors.clear()
	var north := GridActor.new(_game.world.player_tile + Vector2i.UP)
	var south := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	north.relationship = GridActor.Relationship.NEUTRAL
	south.relationship = GridActor.Relationship.NEUTRAL
	_game.world.actors.assign([north, south])
	await _tap_key(KEY_F)
	assert_true(_game.combat_panel.visible)
	assert_same(_game.combat_panel.selected, north)
	await _tap_key(KEY_S)
	assert_same(_game.combat_panel.selected, south)
	await _tap_key(KEY_S)
	assert_same(_game.combat_panel.selected, north, "Directional edge wraps.")
	await _tap_key(KEY_PERIOD)
	await _tap_key(KEY_K)
	for index in range(8):
		await _tap_key(KEY_TAB)
		assert_true(_game.combat_panel.is_ancestor_of(_game_viewport.gui_get_focus_owner()))
	assert_eq(_game.world.turn_count, 0)
	assert_false(north.engaged)
	assert_false(south.engaged)
	assert_false(_game.hero_panel.visible)
	await _tap_key(KEY_ESCAPE)
	assert_false(_game.combat_panel.visible)
	assert_null(_game.grid_view.selected)
	assert_null(_game_viewport.gui_get_focus_owner())


func test_neutral_confirm_pending_continue_and_cancel_route_only_to_combat() -> void:
	_game.world.actors.clear()
	var actor := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	actor.relationship = GridActor.Relationship.NEUTRAL
	_game.world.actors.append(actor)
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.turn_count, 1)
	assert_true(actor.engaged)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.PENDING)
	await _tap_key(KEY_S)
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.turn_count, 2)
	await _tap_key(KEY_ESCAPE)
	assert_null(_game.world.pending_melee)
	assert_false(_game.combat_panel.visible)
	assert_eq(_game.world.turn_count, 2)


func test_friendly_conversation_and_no_candidate_feedback_cost_no_time() -> void:
	_game.world.actors.clear()
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible)
	assert_string_contains(_game.world.messages[-1], "No one")
	var actor := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	_game.world.actors.append(actor)
	await _tap_key(KEY_F)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.CONVERSATION)
	await _tap_key(KEY_S)
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.player_tile, Vector2i(20, 14))
	await _tap_key(KEY_ENTER)
	assert_false(_game.combat_panel.visible)


func test_death_overlay_blocks_gameplay_and_reset_restores_playable_fixture() -> void:
	_game.world.cast_skill(&"death_1")
	_game.refresh_view()
	assert_true(_game.combat_panel.visible)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.DEAD)
	for key in [KEY_S, KEY_F, KEY_P, KEY_K, KEY_PERIOD, KEY_ESCAPE]:
		await _tap_key(key)
	assert_true(_game.combat_panel.visible)
	assert_false(_game.hero_panel.visible)
	assert_eq(_game.world.turn_count, 1)
	assert_eq(_game.world.hero.health, 0)
	var status := _game.get_node("HUD/Top/Rows/HeroStatus") as Label
	assert_true(status.is_visible_in_tree())
	assert_string_contains(status.text, "HP 0/51")
	assert_string_contains(status.text, "Mana 165/165")
	await _tap_key(KEY_ENTER)
	assert_false(_game.combat_panel.visible)
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.hero.health, 51)
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)


func test_combat_panels_fit_minimum_viewport_and_mouse_buttons_work() -> void:
	_game.world.actors.clear()
	var first := GridActor.new(_game.world.player_tile + Vector2i.LEFT)
	var second := GridActor.new(_game.world.player_tile + Vector2i.RIGHT)
	_game.world.actors.assign([first, second])
	_game.combat_panel.open_interaction(_game.world)
	_game.combat_panel.select_tile(second.tile)
	assert_same(_game.combat_panel.selected, second)
	var area := Rect2(0, 0, 640, 360)
	for mode in range(4):
		await get_tree().process_frame
		await get_tree().process_frame
		for control: Control in _game.combat_panel.find_children("*", "Control", true, false):
			if control.is_visible_in_tree():
				assert_true(area.encloses(control.get_global_rect()), control.name)
				if control is Button:
					assert_gte(control.size.x, control.get_minimum_size().x, control.text)
		if mode == 0:
			for button: Button in _game.combat_panel.find_children("*", "Button", true, false):
				if button.text.begins_with("Confirm"):
					button.pressed.emit()
			assert_eq(_game.combat_panel.mode, CombatPanel.Mode.CONVERSATION)
		elif mode == 1:
			_game.world.pending_melee = first
			_game.refresh_view()
		elif mode == 2:
			_game.world.cancel_melee()
			_game.world.cast_skill(&"death_1")
			_game.refresh_view()
	assert_eq(_game.world.turn_count, 1)
