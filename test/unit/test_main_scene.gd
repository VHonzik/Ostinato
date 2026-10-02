extends GutTest

var _viewport: SubViewport
var _main: Control
var _game_viewport: SubViewport
var _game: MovementGame
var _original_options: GlobalOptions
var _options_path: String


func before_each() -> void:
	_original_options = GlobalOptions.new()
	_options_path = "user://test_scene_options_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.notify_mouse_entered()
	add_child_autofree(_viewport)
	var main_scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	assert_not_null(main_scene, "The configured startup scene must load.")
	_main = main_scene.instantiate() as Control
	_viewport.add_child(_main)
	_game_viewport = _main.get_node("GameContainer/GameViewport") as SubViewport
	_game = _game_viewport.get_node("MovementGame") as MovementGame
	# Gameplay preferences must not change this default-keyboard fixture or be overwritten by it.
	InputMap.load_from_project_settings()
	_game.menu.options = GlobalOptions.new(_options_path)
	_game.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_original_options.apply_bindings()
	if FileAccess.file_exists(_options_path):
		DirAccess.remove_absolute(_options_path)


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
	_game.reset_fixture()
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
	_prepare_melee(GridActor.Relationship.NEUTRAL)
	_game.set_process(true)
	await _tap_key(KEY_P)
	assert_true(_game.hero_panel.visible)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
	assert_true(_game.hero_panel.visible)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Fireball")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.turn_count, 0, "Target preselection does not cast.")
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.SPELL)
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
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
	_game.reset_fixture()
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
		"HUD/Top/Rows/HeroStatus/Spells", "HUD/Top/Rows/HeroStatus/Inventory",
		"HUD/Bottom/Rows/Chat"]:
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
		assert_null(_game_viewport.gui_get_focus_owner(), "Tab cannot focus combat buttons.")
	assert_eq(_game.world.turn_count, 0)
	assert_false(north.engaged)
	assert_false(south.engaged)
	assert_false(_game.hero_panel.visible)
	await _tap_key(KEY_ESCAPE)
	assert_false(_game.combat_panel.visible)
	assert_null(_game.grid_view.selected)
	assert_null(_game_viewport.gui_get_focus_owner())


func test_single_neutral_skips_selection_but_requires_explicit_attack_confirmation() -> void:
	var actor := _prepare_melee(GridActor.Relationship.NEUTRAL)
	await _tap_key(KEY_F)
	assert_true(_game.combat_panel.visible)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.CONFIRM_ATTACK)
	var heading := _game.combat_panel.find_child("Heading", true, false) as Label
	assert_eq(heading.text, "Attack %s?" % actor.title)
	assert_eq(_game.world.turn_count, 0)
	assert_false(actor.engaged)
	await _tap_key(KEY_TAB)
	assert_null(_game_viewport.gui_get_focus_owner())
	await _tap_key(KEY_ESCAPE)
	assert_false(_game.combat_panel.visible)
	assert_eq(_game.world.turn_count, 0)
	assert_false(actor.engaged)
	await _tap_key(KEY_F)
	await _tap_key(KEY_ENTER)
	assert_true(actor.engaged)
	assert_eq(actor.relationship, GridActor.Relationship.HOSTILE)
	assert_eq(_game.world.turn_count, 1)
	assert_false(_game.combat_panel.visible)


func test_melee_automatically_waits_until_one_swing_and_gives_npcs_every_turn() -> void:
	var actor := _prepare_melee(GridActor.Relationship.HOSTILE)
	actor.swing.remaining = 10.0
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible, "A lone hostile needs no selector or confirmation.")
	assert_eq(_game.world.turn_count, 1)
	assert_same(_game.world.pending_melee, actor)
	for key in [KEY_S, KEY_PERIOD, KEY_ENTER, KEY_K, KEY_TAB]:
		await _tap_key(key)
	assert_eq(_game.world.turn_count, 1, "Other keys cannot advance the pending action.")
	_game._process(MovementGame.MELEE_BOUNDARY_SECONDS / 2.0)
	assert_eq(_game.world.turn_count, 1, "The presentation gap leaves time to cancel.")
	for expected_turn in [2, 3, 4]:
		_game._process(MovementGame.MELEE_BOUNDARY_SECONDS)
		assert_eq(_game.world.turn_count, expected_turn)
	assert_null(_game.world.pending_melee)
	assert_eq(actor.swing.remaining, 6.0, "Each elapsed boundary grants the NPC its phase.")
	assert_string_contains("\n".join(_game.world.messages), "You ->")
	assert_false(_game.combat_panel.visible)
	assert_false((_game.get_node("HUD/Top/Rows/Heading/CancelAttack") as Button).visible)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 4, "Finishing a request does not start another attack.")


func test_automatic_melee_can_be_canceled_between_boundaries_with_escape_or_mouse() -> void:
	var actor := _prepare_melee(GridActor.Relationship.HOSTILE)
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	_game._process(MovementGame.MELEE_BOUNDARY_SECONDS)
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.world.turn_count, 2)
	assert_null(_game.world.pending_melee)
	assert_eq(_game.world.hero.swing.remaining, 1.5)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 2)
	await _tap_key(KEY_F)
	assert_same(_game.world.pending_melee, actor)
	var cancel := _game.get_node("HUD/Top/Rows/Heading/CancelAttack") as Button
	assert_true(cancel.is_visible_in_tree())
	assert_true(Rect2(0, 0, 640, 360).encloses(cancel.get_global_rect()))
	await _click_button(cancel)
	assert_null(_game.world.pending_melee)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 3)


func test_pending_melee_stops_on_invalid_target_reset_and_death() -> void:
	var actor := _prepare_melee(GridActor.Relationship.HOSTILE)
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	actor.tile += Vector2i(5, 0)
	_game._process(MovementGame.MELEE_BOUNDARY_SECONDS)
	assert_null(_game.world.pending_melee)
	assert_eq(_game.world.turn_count, 1)
	actor.tile = _game.world.player_tile + Vector2i.DOWN
	await _tap_key(KEY_F)
	assert_not_null(_game.world.pending_melee)
	_game.reset_fixture()
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 0, "Reset cannot leave a delayed attack running.")
	actor = _prepare_melee(GridActor.Relationship.HOSTILE)
	actor.melee.damage_min = 1000.0
	actor.melee.damage_max = 1000.0
	actor.melee.critical = 100.0
	actor.melee.level = 100
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	assert_false(_game.world.is_player_dead())
	assert_null(_game.world.pending_melee)
	assert_false(_game.combat_panel.visible)
	assert_eq(_game.session.loop_count, 2)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 0)


func test_friendly_corpse_and_no_candidate_results_go_to_chat_without_dialogue() -> void:
	_game.world.actors.clear()
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible)
	assert_string_contains(_game.world.messages[-1], "No one")
	var actor := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	_game.world.actors.append(actor)
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible)
	var chat := _game.get_node("HUD/Bottom/Rows/Chat") as RichTextLabel
	assert_string_contains(chat.text, "Welcome")
	actor.alive = false
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible)
	assert_string_contains(chat.text, "no loot")
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.player_tile, Vector2i(20, 14))
	var friend := GridActor.new(_game.world.player_tile + Vector2i.UP)
	_game.world.actors.append(friend)
	await _tap_key(KEY_F)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.SELECT)
	await _tap_key(KEY_W)
	assert_same(_game.combat_panel.selected, friend)
	await _tap_key(KEY_ENTER)
	assert_false(_game.combat_panel.visible, "Choosing a friendly adds no second dialogue.")
	assert_string_contains(_game.world.messages[-1], "Welcome")
	assert_eq(_game.world.turn_count, 0)


func test_death_restarts_loop_and_restores_gameplay_without_a_reset_prompt() -> void:
	_game.world.hero.add_experience(400)
	_game.world.cast_skill(&"death_1")
	var ended := _game.world
	_game.refresh_view()
	assert_false(_game.combat_panel.visible)
	assert_false(_game.hero_panel.visible)
	assert_ne(_game.world, ended)
	assert_eq(_game.session.loop_count, 2)
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.hero.level, 1)
	assert_eq(_game.world.hero.health, 51)
	var status := _game.get_node("HUD/Top/Rows/HeroStatus") as Label
	assert_true(status.is_visible_in_tree())
	assert_string_contains(status.text, "HP 51/51")
	assert_string_contains(status.text, "Mana 165/165")
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)


func test_combat_panels_fit_minimum_viewport_and_mouse_buttons_work() -> void:
	_game.set_process(false)
	_game.world.actors.clear()
	var first := GridActor.new(_game.world.player_tile + Vector2i.LEFT)
	var second := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	second.relationship = GridActor.Relationship.NEUTRAL
	_game.world.actors.assign([first, second])
	_game.combat_panel.open_interaction(_game.world)
	_game.combat_panel.select_tile(second.tile)
	assert_same(_game.combat_panel.selected, second)
	var area := Rect2(0, 0, 640, 360)
	for mode in [CombatPanel.Mode.SELECT, CombatPanel.Mode.CONFIRM_ATTACK]:
		assert_eq(_game.combat_panel.mode, mode)
		await get_tree().process_frame
		await get_tree().process_frame
		for control: Control in _game.combat_panel.find_children("*", "Control", true, false):
			if control.is_visible_in_tree():
				assert_true(area.encloses(control.get_global_rect()), control.name)
				if control is Button:
					assert_gte(control.size.x, control.get_minimum_size().x, control.text)
					assert_eq(control.focus_mode, Control.FOCUS_NONE)
		if mode == CombatPanel.Mode.SELECT:
			await _click_combat_button("Choose")
			assert_eq(_game.world.turn_count, 0, "Choosing a neutral still requires attack confirmation.")
		elif mode == CombatPanel.Mode.CONFIRM_ATTACK:
			await _click_combat_button("Cancel")
			assert_false(second.engaged)
			assert_false(_game.combat_panel.visible)
			_game.world.actors.erase(first)
			_game.combat_panel.open_interaction(_game.world)
			await get_tree().process_frame
			await _click_combat_button("Attack")
			assert_true(second.engaged)
			assert_false(_game.combat_panel.visible)
			assert_eq(_game.world.turn_count, 1)
			_game.world.cast_skill(&"death_1")
			_game.refresh_view()
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.session.loop_count, 2)


func _prepare_melee(relationship: GridActor.Relationship) -> GridActor:
	# Advance presentation time explicitly; keyboard helper frames cannot race the action.
	_game.set_process(false)
	_game.world.actors.clear()
	var actor := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	actor.relationship = relationship
	_game.world.actors.append(actor)
	return actor


func _click_combat_button(prefix: String) -> void:
	for button: Button in _game.combat_panel.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.begins_with(prefix):
			await _click_button(button)
			return
	fail_test("Expected visible combat button: " + prefix)


func _click_button(button: Button) -> void:
	# Route through the container so Godot updates the child viewport mouse position.
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	_viewport.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(event, true)
	event.pressed = false
	event.button_mask = 0
	_viewport.push_input(event, true)
	await get_tree().process_frame
	await get_tree().process_frame


func test_main_menu_keyboard_starts_game_and_menu_actions_never_spend_time() -> void:
	_game._return_to_menu()
	_game.menu.open_main()
	assert_false(_game.active_game)
	assert_false((_game.get_node("HUD/Top") as Control).visible)
	var titles: Array[String] = []
	for button: Button in _game.menu.find_children("*", "Button", true, false):
		titles.append(button.text)
	assert_eq(titles, ["New Game", "Load", "Options", "Exit"])
	await _tap_key(KEY_PERIOD)
	assert_false(_game.active_game)
	await _tap_key(KEY_ENTER)
	assert_true(_game.active_game)
	assert_false(_game.menu.visible)
	assert_eq(_game.session.loop_count, 1)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.menu.page, "options")
	await _tap_key(KEY_PERIOD)
	await _tap_key(KEY_F)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	assert_false(_game.menu.visible)


func test_targeted_spell_keyboard_confirmation_and_cast_cancellation() -> void:
	_prepare_melee(GridActor.Relationship.NEUTRAL)
	_game.set_process(false)
	await _tap_key(KEY_K)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.SPELL)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.turn_count, 1)
	assert_not_null(_game.world.pending_skill)
	assert_eq(_game.world.hero.mana, 165)
	await _tap_key(KEY_ESCAPE)
	assert_null(_game.world.pending_skill)
	_game._process(1.0)
	assert_eq(_game.world.turn_count, 1)
	assert_eq(_game.world.hero.mana, 165)


func test_enemy_spell_target_stays_selected_across_spells_until_it_dies() -> void:
	_game.set_process(false)
	var world := _game.world
	world.actors.clear()
	world.population.clear()
	world.blocked_tiles.clear()
	world.sight_blockers.clear()
	var near := GridActor.new(world.player_tile + Vector2i.RIGHT)
	near.relationship = GridActor.Relationship.NEUTRAL
	near.health = 1000
	near.max_health = 1000
	var far := GridActor.new(world.player_tile + Vector2i(3, 0))
	far.relationship = GridActor.Relationship.NEUTRAL
	far.health = 1000
	far.max_health = 1000
	far.rooted_until = 100
	world.actors.append_array([near, far])
	world.hero.add_experience(2700)
	assert_eq(world.hero.level, 4)
	assert_true(world.hero.learn_skill(SkillRank.catalog(&"frostbolt_1")))
	var fireball := world.hero.find_skill(&"fireball_1")
	var frostbolt := world.hero.find_skill(&"frostbolt_1")
	var panel := _game.combat_panel

	panel.open_spell(world, fireball)
	assert_same(panel.selected, near, "The first cast starts with the nearest valid enemy.")
	panel.select_tile(far.tile)
	panel.confirm()
	assert_same(world.pending_target, far)
	world.cancel_cast()
	panel.open_spell(world, fireball)
	assert_same(panel.selected, far, "The second Fireball remembers the confirmed target.")
	panel.confirm()
	assert_same(world.pending_target, far)
	world.cancel_cast()

	panel.open_spell(world, frostbolt)
	assert_same(panel.selected, far, "Another enemy spell shares the target.")
	panel.select_tile(near.tile)
	panel.cancel()
	panel.open_spell(world, frostbolt)
	assert_same(panel.selected, far, "Canceling a new selection keeps the last confirmed target.")
	panel.cancel()
	far.alive = false
	panel.open_spell(world, fireball)
	assert_same(panel.selected, near, "A dead target falls back to the nearest living enemy.")
	panel.cancel()


func test_switching_spell_target_type_and_loop_reset_clear_target_memory() -> void:
	_game.set_process(false)
	var world := _game.world
	world.actors.clear()
	world.population.clear()
	world.blocked_tiles.clear()
	world.sight_blockers.clear()
	var near := GridActor.new(world.player_tile + Vector2i.RIGHT)
	near.relationship = GridActor.Relationship.NEUTRAL
	var far := GridActor.new(world.player_tile + Vector2i(3, 0))
	far.relationship = GridActor.Relationship.NEUTRAL
	far.rooted_until = 100
	var ally := GridActor.new(world.player_tile + Vector2i.UP)
	ally.relationship = GridActor.Relationship.FRIENDLY
	world.actors.append_array([near, far, ally])
	assert_true(world.hero.learn_skill(SkillRank.catalog(&"intellect_1")))
	var panel := _game.combat_panel
	var fireball := world.hero.find_skill(&"fireball_1")
	var intellect := world.hero.find_skill(&"intellect_1")

	panel.open_spell(world, fireball)
	panel.select_tile(far.tile)
	panel.confirm()
	world.cancel_cast()
	panel.open_spell(world, intellect)
	assert_eq(panel.selected.title, "You", "An ally spell leaves the enemy selection behind.")
	panel.select_tile(ally.tile)
	panel.confirm()
	panel.open_spell(world, intellect)
	assert_same(panel.selected, ally, "Ally spells also remember a confirmed living ally.")
	panel.cancel()
	panel.open_spell(world, fireball)
	assert_same(panel.selected, near, "Switching back to enemies starts with the nearest.")
	panel.cancel()

	panel.open_spell(world, fireball)
	panel.select_tile(far.tile)
	panel.confirm()
	world.cancel_cast()
	_game._cast_skill(&"frost_armor_1")
	panel.open_spell(world, fireball)
	assert_same(panel.selected, near, "Choosing a self spell clears the enemy selection.")
	panel.cancel()

	panel.open_spell(world, fireball)
	panel.select_tile(far.tile)
	panel.confirm()
	world.cancel_cast()
	assert_true(world.cast_skill(&"death_1"))
	_game.refresh_view()
	assert_eq(_game.session.loop_count, 2)
	assert_null(panel._last_spell_target, "Player death clears target memory.")
	assert_eq(panel._last_target_type, SkillRank.Target.NONE)


func test_marshal_and_trainer_interactions_open_services_without_advancing_time() -> void:
	_game.world.cast_skill(&"death_1")
	_game.refresh_view()
	_game.world.player_tile = Vector2i(19, 13)
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	for button in _game.menu._buttons:
		if button.text == "Discuss class selection":
			button.grab_focus()
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "marshal")
	var choices: Array[String] = []
	for button: Button in _game.menu.find_children("*", "Button", true, false):
		choices.append(button.text)
	assert_eq(choices, ["Choose Druid", "Choose Warlock", "Choose Priest", "Choose Shaman", "Choose Paladin", "Leave (Esc)"])
	assert_eq((_game_viewport.gui_get_focus_owner() as Button).text, "Choose Druid")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.hero.selected_class, &"Druid")
	assert_null(_game.world.hero.find_skill(&"wrath_1"))
	_game.world.player_tile = Vector2i(12, 14)
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "trainer")
	await _tap_key(KEY_ENTER)
	assert_not_null(_game.world.hero.find_skill(&"wrath_1"))
	assert_eq(_game.world.turn_count, 0)


func test_ingame_menus_keep_resources_visible_and_scroll_keyboard_focus_into_view() -> void:
	var area := Rect2(0, 0, 640, 360)
	var resource_row := _game.get_node("HUD/Top/Rows/HeroStatus") as Control
	for open_page: Callable in [
		_game.menu.open_options, _game.menu.open_slots, _game.menu.open_bindings,
		_game.menu.open_marshal, _game.menu.open_inventory,
	]:
		open_page.call()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(area.encloses(_game.menu._panel.get_global_rect()))
		assert_false(resource_row.get_global_rect().intersects(_game.menu._panel.get_global_rect()))
		# Wrapping upward must reveal a distant final item, not just its nearest neighbor.
		await _tap_key(KEY_W)
		var last_focused := _game_viewport.gui_get_focus_owner() as Button
		assert_eq(last_focused.text, _game.menu._buttons[-1].text)
		assert_true(_game.menu._panel.get_global_rect().encloses(last_focused.get_global_rect()))
		await _tap_key(KEY_S)
		var count := _game.menu._buttons.size()
		for step in range(count):
			var focused := _game_viewport.gui_get_focus_owner() as Button
			assert_not_null(focused)
			await get_tree().process_frame
			await get_tree().process_frame
			assert_true(area.encloses(focused.get_global_rect()), focused.text)
			await _tap_key(KEY_S)
		assert_eq(_game.world.turn_count, 0)
	_game.menu.close()


func test_fireball_can_be_selected_and_cast_from_all_eight_adjacent_tiles() -> void:
	_game.set_process(false)
	for direction in GridWorld.DIRECTIONS:
		_game.session.new_game(11)
		_game.world.blocked_tiles.clear()
		_game.world.sight_blockers.clear()
		_game.world.actors.clear()
		var target := GridActor.new(_game.world.player_tile + direction)
		target.relationship = GridActor.Relationship.NEUTRAL
		target.health = 1000
		target.max_health = 1000
		target.swing.remaining = 100.0
		_game.world.actors.append(target)
		_game.world.hero.mana = 30
		_game.world.combat_random.seed = 1
		await _tap_key(KEY_K)
		await _tap_key(KEY_ENTER)
		assert_true(_game.combat_panel.visible)
		assert_same(_game.combat_panel.selected, target)
		assert_eq(_game.world.turn_count, 0)
		assert_false(target.engaged)
		await _tap_key(KEY_ENTER)
		assert_eq(_game.world.turn_count, 1)
		assert_true(target.engaged)
		_game._process(MovementGame.MELEE_BOUNDARY_SECONDS)
		assert_eq(_game.world.turn_count, 2)
		assert_eq(_game.world.hero.mana, 0)
		assert_lt(target.health, target.max_health)
		assert_null(_game.world.pending_skill)


func test_fireball_with_insufficient_mana_reports_the_cost_instead_of_no_target() -> void:
	var target := _prepare_melee(GridActor.Relationship.NEUTRAL)
	_game.world.hero.mana = 29
	await _tap_key(KEY_K)
	await _tap_key(KEY_ENTER)
	assert_false(_game.combat_panel.visible)
	var chat := _game.get_node("HUD/Bottom/Rows/Chat") as RichTextLabel
	assert_string_contains(chat.text, "Not enough mana for Fireball: requires 30, have 29.")
	assert_false(chat.text.contains("No valid target"))
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.hero.mana, 29)
	assert_false(target.engaged)
	assert_null(_game.world.pending_skill)


func test_supply_chest_keyboard_looting_is_free_and_empty_chest_cannot_duplicate_rewards() -> void:
	var chest := _game.world.actors[-1]
	assert_true(chest.chest)
	_game.world.player_tile = chest.tile + Vector2i.LEFT
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "loot")
	assert_true(_game.menu.visible)
	var expected := chest.loot_copper
	assert_gt(expected, 0)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.hero.copper, expected)
	assert_eq(chest.loot_copper, 0)
	while _game.menu.visible:
		await _tap_key(KEY_ENTER)
	assert_false(chest.corpse_visible)
	assert_eq(_game.world.turn_count, 0)
	assert_gt(_game.world.hero.inventory.filter(func(item: Dictionary) -> bool: return not item.is_empty()).size(), 0)
	var money := _game.world.hero.copper
	await _tap_key(KEY_F)
	assert_eq(_game.world.hero.copper, money)
	assert_false(_game.menu.visible)


func test_inventory_equipping_through_menu_spends_one_turn_and_death_closes_stale_menu() -> void:
	_game.world.hero.inventory[0] = ItemData.instance(85)
	_game.menu.open_inventory()
	_game.menu._item_detail(0)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.hero.equipment.chest.id, 85)
	assert_eq(_game.world.turn_count, 1)
	assert_eq(_game.menu.page, "inventory")
	_game.menu.close()
	_game.world.hero.health = 1
	_game.world.player_tile = Vector2i(40, 20)
	var attacker := GridActor.new(Vector2i(41, 20))
	attacker.relationship = GridActor.Relationship.HOSTILE
	attacker.engaged = true
	attacker.melee.level = 60
	attacker.melee.damage_min = 1000
	attacker.melee.damage_max = 1000
	_game.world.actors.append(attacker)
	_game.world.hero.inventory[1] = ItemData.instance(2139)
	_game.menu._item_detail(1)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.session.loop_count, 2)
	assert_false(_game.menu.visible)
	assert_eq(_game.world.hero.equipment.main_hand.id, 35)


func test_trader_keyboard_quantity_purchase_never_moves_player_or_advances_time() -> void:
	_game.world.player_tile = Vector2i(17, 17)
	_game.world.hero.copper = 200
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "trade")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "quantity")
	var confirm_button: Button
	for button in _game.menu._buttons:
		if button.text.begins_with("Confirm"):
			confirm_button = button
	confirm_button.grab_focus()
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.hero.inventory[0].id, 2139)
	assert_eq(_game.world.hero.copper, 143)
	assert_eq(_game.world.player_tile, Vector2i(17, 17))
	assert_eq(_game.world.turn_count, 0)


func test_new_services_keep_last_keyboard_control_and_resources_visible_at_minimum_size() -> void:
	_game.world.hero.level = 10
	_game.world.hero._apply_level_stats()
	_game.world.hero.copper = 10000
	for page: Callable in [_game.menu.open_inventory, _game.menu.open_trade,
		_game.menu.open_trainer.bind(&"Mage")]:
		page.call()
		_game.menu._buttons[-1].grab_focus()
		for frame in range(4):
			await get_tree().process_frame
		var button := _game.menu._buttons[-1]
		var panel := _game.menu._panel.get_global_rect()
		assert_true(Rect2(0, 0, 640, 360).encloses(panel))
		assert_true(panel.encloses(button.get_global_rect()))
		var resources := _game.get_node("HUD/Top/Rows/HeroStatus") as Control
		assert_false(panel.intersects(resources.get_global_rect()))
		await _tap_key(KEY_ESCAPE)


func test_spell_book_remembers_each_class_selection_across_close_and_loop() -> void:
	var hero := _game.world.hero
	assert_true(hero.learn_skill(SkillRank.catalog(&"wrath_1")))
	assert_true(hero.learn_skill(SkillRank.catalog(&"healing_touch_1")))
	await _tap_key(KEY_K)
	var frost := _game.hero_panel._skill_buttons.filter(func(button: Button) -> bool:
		return button.text.begins_with("Frost Armor"))[0] as Button
	frost.grab_focus()
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
	assert_same(_game_viewport.gui_get_focus_owner(), _game.hero_panel._skill_buttons[1])
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Frost Armor")
	_game.hero_panel.change_tab(2)
	var healing := _game.hero_panel._skill_buttons.filter(func(button: Button) -> bool:
		return button.text.begins_with("Healing Touch"))[0] as Button
	healing.grab_focus()
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
	assert_eq(_game.hero_panel._tabs.get_tab_title(_game.hero_panel._tabs.current_tab), "Druid")
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Healing Touch")
	_game.hero_panel.change_tab(-2)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Frost Armor")
	_game.hero_panel.close()
	_game.world.cast_skill(&"death_1")
	_game.refresh_view()
	await _tap_key(KEY_K)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Frost Armor")
	_game.start_new_game()
	await _tap_key(KEY_K)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Fireball")


func test_inventory_hud_button_shows_binding_and_opens_menu_without_time() -> void:
	var button := _game.get_node("HUD/Top/Rows/HeroStatus/Inventory") as Button
	assert_string_contains(button.text, "Inventory (I)")
	assert_true(Rect2(0, 0, 640, 360).encloses(button.get_global_rect()))
	button.pressed.emit()
	assert_eq(_game.menu.page, "inventory")
	assert_eq(_game.world.turn_count, 0)
	_game.menu.close()
	_game.menu.options.bindings["inventory"] = [KEY_B]
	_game.menu.options.apply_bindings()
	_game.refresh_view()
	assert_string_contains(button.text, "Inventory (B)")


func test_quest_log_keyboard_accept_hand_in_abandon_and_focus_do_not_advance_time() -> void:
	_game.world.player_tile = Vector2i(21, 15)
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "quest_detail")
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.quests.has("783"))
	assert_true(_game.world.ever_accepted_quest)
	assert_false(_game.menu.visible, "No remaining conversation choices return to play.")
	await _tap_key(KEY_J)
	assert_eq(_game.menu.page, "quests")
	assert_string_contains(_game.menu._buttons[0].text, "In progress")
	var position := _game.world.player_tile
	await _tap_key(KEY_S)
	assert_eq(_game.world.player_tile, position)
	await _tap_key(KEY_ESCAPE)
	_game.world.player_tile = Vector2i(19, 13)
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_true(QuestRules.ready(_game.world, "783"))
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "quest_detail")
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.quests["783"].handed_in)
	assert_eq(_game.world.hero.experience, 40)
	# First follow-up at the marshal is Kobold Camp Cleanup.
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.quests.has("7"))
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_J)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "quest_detail")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "confirm")
	await _tap_key(KEY_ESCAPE)
	assert_true(_game.world.quests.has("7"), "Cancel abandonment preserves the quest.")
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_ENTER)
	assert_false(_game.world.quests.has("7"))
	assert_true(_game.world.ever_accepted_quest)
	assert_eq(_game.world.turn_count, 0)


func test_quest_pages_scroll_and_mouse_open_log_at_minimum_size() -> void:
	_game.menu.open_options()
	await get_tree().process_frame
	await get_tree().process_frame
	for button in _game.menu._buttons:
		if button.text.begins_with("Quest log"):
			await _click_button(button)
			break
	assert_eq(_game.menu.page, "quests")
	_game.menu._quest_detail("18", null)
	_game.menu._buttons[-1].grab_focus()
	for frame in range(4):
		await get_tree().process_frame
	assert_true(_game.menu._panel.get_global_rect().encloses(
		_game.menu._buttons[-1].get_global_rect()))
	assert_true(Rect2(0, 0, 640, 360).encloses(_game.menu._panel.get_global_rect()))
	assert_eq(_game.world.turn_count, 0)


func test_six_class_spell_book_scrolls_and_keyboard_reaches_commands_at_minimum_size() -> void:
	var hero := _game.world.hero
	hero.level = 10
	for identifier in SkillRank.all_ranks():
		hero.learn_skill(SkillRank.catalog(StringName(identifier)))
	_game.hero_panel.open(hero, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := _game.hero_panel
	var area := Rect2(0, 0, 640, 360)
	assert_true(area.encloses(panel._panel.get_global_rect()))
	assert_true(area.encloses(panel._tabs.get_tab_bar().get_global_rect()))
	var seen: Array[String] = []
	for index in range(panel._tabs.get_tab_count()):
		panel._tabs.current_tab = index
		seen.append(panel._tabs.get_tab_title(index))
	for category in ClassSkillData.CLASSES:
		assert_has(seen, String(category))
	panel._tabs.current_tab = seen.find("Warlock")
	for step in range(25):
		panel.navigate(true)
		await get_tree().process_frame
	var dismiss: Button
	for button in panel._skill_buttons:
		if button.get_meta("skill_id") == &"pet_dismiss":
			dismiss = button
	assert_not_null(dismiss)
	dismiss.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := panel._tabs.get_current_tab_control() as ScrollContainer
	assert_gt(scroll.scroll_vertical, 0)
	assert_true(scroll.get_global_rect().encloses(dismiss.get_global_rect()))
	assert_eq(_game.world.turn_count, 0)
