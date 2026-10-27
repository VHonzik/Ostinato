extends GutTest

var _viewport: SubViewport
var _main: Control
var _game_viewport: SubViewport
var _game: Gameplay
var _original_options: GlobalOptions
var _options_path: String


func before_each() -> void:
	_original_options = GlobalOptions.new()
	_options_path = "user://test_scene_options_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.notify_mouse_entered()
	add_child_autofree(_viewport)
	var main_scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	assert_not_null(main_scene, "The configured startup scene must load.")
	_main = main_scene.instantiate() as Control
	_viewport.add_child(_main)
	_game_viewport = _main.get_node("GameContainer/GameViewport") as SubViewport
	_game = _game_viewport.get_node("Gameplay") as Gameplay
	# Gameplay preferences must not change this default-keyboard fixture or be overwritten by it.
	InputMap.load_from_project_settings()
	_game.menu.options = GlobalOptions.new(_options_path)
	_game.start_new_game()
	_game.world.hero.rage = 100
	_game.world.hero.learn_skill(SkillDefinition.catalog(&"battle_shout_1"))
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_original_options.apply_bindings()
	if FileAccess.file_exists(_options_path):
		DirAccess.remove_absolute(_options_path)


func test_lava_picker_only_skips_confirmation_for_one_valid_engaged_target() -> void:
	_game.set_process(false)
	var world := _game.world
	world.stalker_schedule = false
	world.population.clear()
	world.blocked_tiles.clear()
	world.sight_blockers.clear()
	world.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	for scenario in ["neutral", "hostile", "engaged", "multiple", "distant_extra"]:
		world.actors.clear()
		world.hero.cooldowns.clear()
		world.hero.rage = 100
		_game.combat_panel.clear_spell_target()
		var enemy := GridActor.new(world.player_tile + Vector2i.RIGHT)
		enemy.relationship = (GridActor.Relationship.NEUTRAL if scenario == "neutral"
			else GridActor.Relationship.HOSTILE)
		enemy.engaged = scenario in ["engaged", "multiple", "distant_extra"]
		enemy.health = 1000
		enemy.max_health = 1000
		world.actors.append(enemy)
		world.last_attacked_enemy = enemy if enemy.engaged else null
		if scenario in ["multiple", "distant_extra"]:
			var other := GridActor.new(world.player_tile + Vector2i(3 if scenario == "multiple" else 8, 0))
			other.relationship = GridActor.Relationship.NEUTRAL
			world.actors.append(other)
		var before := world.turn_count
		_game._cast_skill(&"lava_burst_1")
		if scenario in ["engaged", "distant_extra"]:
			assert_false(_game.combat_panel.visible, scenario)
			assert_same(world.pending_target, enemy, scenario)
		else:
			assert_true(_game.combat_panel.visible, scenario)
			assert_null(world.pending_skill, scenario)
			assert_eq(world.turn_count, before, "Selection spends no time.")
			if scenario == "multiple":
				_game.combat_panel.select_tile(world.actors[1].tile)
				_game.combat_panel.confirm()
				assert_same(world.pending_target, world.actors[1], "The ranged pull can choose another enemy.")
		world.cancel_cast()
		_game.combat_panel.close()
		# Finish action presentation before testing the next independent input.
		_game.grid_view._process(10.0)


func test_bags_quality_order_preserves_actions_original_slots_and_stack_data() -> void:
	var hero := _game.world.hero
	hero.inventory.fill({})
	hero.inventory[0] = ItemData.instance(35, 1, true)
	hero.inventory[9] = ItemData.instance(2572)
	hero.inventory[4] = ItemData.instance(117, 3)
	hero.inventory[6] = ItemData.instance(118, 2)
	var original := hero.inventory.duplicate(true)
	_game.menu.open_bags()
	var buttons := _game.menu._buttons.duplicate()
	assert_string_contains(buttons[0].text, ItemData.get_item(2572).title)
	assert_string_contains(buttons[1].text, "Minor Healing Potion")
	assert_string_contains(buttons[2].text, "Tough Jerky")
	assert_string_contains(buttons[3].text, ItemData.get_item(35).title)
	assert_eq(hero.inventory, original)
	buttons[0].pressed.emit()
	assert_eq(_game.menu.page, "item")
	assert_string_contains((_game.menu._rows.get_child(0) as Label).text, ItemData.get_item(2572).title)


func test_war_horn_hotbar_and_bags_start_casts_and_resume_until_completion() -> void:
	_game.set_process(false)
	var world := _game.world
	world.actors.clear()
	world.stalker_schedule = false
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_HORN_ID)))
	assert_true(world.assign_hotbar(0, ItemData.WAR_HORN_HOTBAR_ID))
	_game.refresh_view()
	assert_string_contains(_game.hotbar_panel.slots[0].tooltip_text, "War Horn")
	_game._cast_skill(ItemData.WAR_HORN_HOTBAR_ID)
	assert_eq(world.turn_count, 1)
	assert_not_null(world.pending_skill)
	world.cancel_cast()
	_game.refresh_view()
	_game.menu.open_bags()
	var index := -1
	for slot in range(world.hero.inventory.size()):
		var item := world.hero.inventory[slot]
		if not item.is_empty() and item.id == ItemData.WAR_HORN_ID:
			index = slot
	assert_gte(index, 0)
	if index < 0:
		return
	_game.menu._item_detail(index)
	var use_button: Button
	for button in _game.menu._buttons:
		if button.text == "Use (2-turn cast)":
			use_button = button
	assert_not_null(use_button)
	if use_button == null:
		return
	use_button.pressed.emit()
	assert_false(_game.menu.visible, "Bags close so the pending cast can continue.")
	assert_not_null(world.pending_skill)
	assert_eq(world.turn_count, 2)
	_game._process(Gameplay.MELEE_BOUNDARY_SECONDS)
	assert_null(world.pending_skill)
	assert_eq(world.turn_count, 3)
	assert_true(world.has_war_horn())
	assert_eq(_game.hotbar_panel._cooldown_labels[0].text, "30")


func test_ancestral_totem_bags_use_summons_and_disables_consumed_hotbar_item() -> void:
	_game.set_process(false)
	var world := _game.world
	world.actors.clear()
	world.stalker_schedule = false
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(ItemData.ANCESTRAL_TOTEM_ID)))
	assert_true(world.assign_hotbar(0, ItemData.ANCESTRAL_TOTEM_HOTBAR_ID))
	_game.refresh_view()
	assert_string_contains(_game.hotbar_panel.slots[0].tooltip_text, "Ancestral totem")
	var index := -1
	for slot in range(world.hero.inventory.size()):
		if not world.hero.inventory[slot].is_empty() and world.hero.inventory[slot].id == ItemData.ANCESTRAL_TOTEM_ID:
			index = slot
	assert_gte(index, 0)
	if index < 0:
		return
	_game.menu.open_bags()
	_game.menu._item_detail(index)
	var use_button: Button
	for button in _game.menu._buttons:
		if button.text == "Use once (1 turn)":
			use_button = button
	assert_not_null(use_button)
	if use_button == null:
		return
	use_button.pressed.emit()
	assert_false(_game.menu.visible)
	assert_eq(world.turn_count, 1)
	assert_not_null(SummonRules.active(world, "earth_elemental"))
	assert_false(world.has_ancestral_totem())
	assert_true(_game.hotbar_panel.slots[0].disabled)
	_game._cast_skill(ItemData.ANCESTRAL_TOTEM_HOTBAR_ID)
	assert_eq(world.turn_count, 1, "Consumed hotbar shortcuts cannot summon again.")


func test_banner_hotbar_use_and_hud_follow_protection_range() -> void:
	_game.set_process(false)
	var world := _game.world
	world.actors.clear()
	world.stalker_schedule = false
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_BANNER_ID)))
	assert_true(world.assign_hotbar(0, ItemData.WAR_BANNER_HOTBAR_ID))
	_game.refresh_view()
	assert_string_contains(_game.hotbar_panel.slots[0].tooltip_text, "Wartorn Banner")
	_game._cast_skill(ItemData.WAR_BANNER_HOTBAR_ID)
	assert_eq(world.turn_count, 1)
	assert_true(WarBannerRules.active(world))
	assert_true(_game.hotbar_panel.slots[0].disabled)
	var aura: Control
	for entry in _game.get_node("HUD/Auras").get_children():
		if entry.tooltip_text.begins_with("Wartorn Banner"):
			aura = entry
	assert_not_null(aura)
	if aura != null:
		assert_string_contains(aura.tooltip_text, "10% less damage taken")
	world.player_tile = world.war_banner.tile + Vector2i(4, 0)
	_game.refresh_view()
	for entry in _game.get_node("HUD/Auras").get_children():
		if entry.tooltip_text.begins_with("Wartorn Banner"):
			assert_string_contains(entry.tooltip_text, "Outside protection range")
	_game._cast_skill(ItemData.WAR_BANNER_HOTBAR_ID)
	assert_eq(world.turn_count, 1)
	# Let the normal draw path run; visual quality remains for human playtesting.
	await get_tree().process_frame


func test_startup_creates_the_playable_world() -> void:
	assert_true(_main.is_node_ready())
	assert_eq(_game.world.player_tile, ValleyRoute.SPAWN)
	assert_eq(_game.world.turn_count, 0)
	assert_gt(_game.world.actors.size(), 0)


func test_combo_bar_unlocks_with_retained_passive_and_fades_when_points_are_spent() -> void:
	var bar := _game.get_node("HUD/ComboPointBar") as Control
	_game.refresh_view()
	assert_false(bar.visible, "A new Warrior has not unlocked combo points.")
	_game.world.hero.selected_class = &"Rogue"
	_game.refresh_view()
	assert_false(bar.visible, "Class selection alone does not teach the combo passive.")
	_game.world.hero.learn_skill(SkillDefinition.catalog(&"relentless_assault_1"))
	_game.world.hero.learn_skill(SkillDefinition.catalog(&"eviscerate_1"))
	_game.world.hero.selected_class = &"Warrior"
	_game.refresh_view()
	assert_true(bar.visible, "Retained Rogue learning exposes points in every class.")
	var empty_alpha := bar.modulate.a
	_game.world.hero.gain_combo_point()
	_game.refresh_view()
	assert_gt(bar.modulate.a, empty_alpha)
	assert_lt(bar.modulate.a, 1.0)
	var enemy := GridActor.new(_game.world.player_tile + Vector2i.RIGHT)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.health = 10000
	enemy.max_health = 10000
	enemy.stunned_until = 999
	_game.world.actors.append(enemy)
	_game.world.hero.swing.remaining = 100.0
	_game.world.hero.swing._active = true
	assert_true(_game.world.cast_skill(&"eviscerate_1", enemy))
	_game.refresh_view()
	assert_true(bar.visible)
	assert_almost_eq(bar.modulate.a, empty_alpha, 0.001, "Spending the last point fades the bar.")
	_game.world.hero.combo_points = HeroState.MAX_COMBO_POINTS
	_game.refresh_view()
	assert_gt(bar.modulate.a, empty_alpha)
	_game.world.hero.health = 0
	_game.refresh_view()
	assert_true(bar.visible, "Death retains the learned passive.")
	assert_eq(_game.world.hero.combo_points, 0)
	assert_almost_eq(bar.modulate.a, empty_alpha, 0.001)
	_game.start_new_game()
	assert_false(bar.visible, "A fresh game clears the Rogue unlock.")


func test_combo_bar_follows_gameplay_hud_visibility() -> void:
	var bar := _game.get_node("HUD/ComboPointBar") as Control
	_game.world.hero.learn_skill(SkillDefinition.catalog(&"relentless_assault_1"))
	_game.refresh_view()
	assert_true(bar.visible)
	_game.menu.open_player()
	assert_false(bar.visible)
	_game.menu.close()
	assert_true(bar.visible)
	await _tap_key(KEY_K)
	assert_false(bar.visible)
	await _tap_key(KEY_ESCAPE)
	assert_true(bar.visible)
	_game._return_to_menu()
	assert_false(bar.visible)


func test_maelstrom_bar_unlocks_fades_after_spending_and_follows_hud_visibility() -> void:
	var bar := _game.get_node("HUD/MaelstromWeaponBar") as Control
	_game.refresh_view()
	assert_false(bar.visible)
	_game.world.hero.learn_skill(SkillDefinition.catalog(&"maelstrom_weapon_1"))
	_game.refresh_view()
	assert_true(bar.visible, "Retained learning shows the empty bar in every class.")
	var empty_alpha := bar.modulate.a
	_game.world.hero.buffs[&"maelstrom_weapon_1"] = {"until": 0, "armor": 0, "charges": 5}
	_game.refresh_view()
	for aura in _game.get_node("HUD/Auras").get_children():
		assert_false((aura as Control).tooltip_text.contains("Maelstrom"), "The bar replaces the duplicate aura.")
	assert_gt(bar.modulate.a, empty_alpha)
	assert_lt(bar.modulate.a, 1.0)
	_game.menu.open_player()
	assert_false(bar.visible)
	_game.menu.close()
	assert_true(bar.visible)
	await _tap_key(KEY_K)
	assert_false(bar.visible)
	await _tap_key(KEY_ESCAPE)
	assert_true(bar.visible)
	ClassToolkitRules.spend_maelstrom(_game.world.hero, 5)
	_game.refresh_view()
	assert_true(bar.visible)
	assert_almost_eq(bar.modulate.a, empty_alpha, 0.001)
	_game.world.hero.health = 0
	_game.refresh_view()
	assert_true(bar.visible, "Death retains the passive, with empty stacks.")
	assert_almost_eq(bar.modulate.a, empty_alpha, 0.001)
	_game._return_to_menu()
	assert_false(bar.visible)
	_game.start_new_game()
	assert_false(bar.visible)


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
	assert_eq(_game.world.player_tile, ValleyRoute.SPAWN)


func test_key_echo_does_not_advance_time() -> void:
	_send_key(KEY_PERIOD, true, true)
	await get_tree().process_frame
	assert_eq(_game.world.turn_count, 0)


func test_held_movement_waits_half_second_then_repeats_every_150ms_until_release() -> void:
	_prepare_held_movement()
	_send_key(KEY_D, true)
	_game._process(0.0)
	assert_eq(_game.world.player_tile, Vector2i(21, 14))
	_game._process(0.45)
	assert_eq(_game.world.turn_count, 1)
	_send_key(KEY_D, true, true)
	_game._process(0.05)
	assert_eq(_game.world.player_tile, Vector2i(22, 14))
	_game._process(0.1)
	assert_eq(_game.world.turn_count, 2)
	_game._process(0.05)
	assert_eq(_game.world.turn_count, 3)
	_send_key(KEY_D, false)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 3)


func test_held_arrow_diagonal_changes_to_remaining_key_without_catchup_bursts() -> void:
	_prepare_held_movement()
	_send_key(KEY_UP, true)
	_send_key(KEY_RIGHT, true)
	_game._process(0.0)
	_game._process(2.0)
	assert_eq(_game.world.player_tile, Vector2i(22, 12))
	_send_key(KEY_UP, false)
	_game._process(10.0)
	assert_eq(_game.world.player_tile, Vector2i(23, 12))
	assert_eq(_game.world.turn_count, 3)
	_send_key(KEY_RIGHT, false)


func test_menu_focus_and_world_replacement_cancel_held_movement() -> void:
	_prepare_held_movement()
	_send_key(KEY_D, true)
	_game._process(0.0)
	_game.menu.open_player()
	_game._process(3.0)
	_game.menu.close()
	_game._process(3.0)
	assert_eq(_game.world.turn_count, 1)
	_send_key(KEY_D, false)
	_send_key(KEY_D, true)
	_game._process(0.0)
	_game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_game._process(3.0)
	assert_eq(_game.world.turn_count, 2)
	_send_key(KEY_D, false)
	_send_key(KEY_D, true)
	_game._process(0.0)
	_game.start_new_game()
	_game._process(3.0)
	assert_eq(_game.world.turn_count, 0)
	_send_key(KEY_D, false)
	await get_tree().process_frame


func test_rebound_movement_repeats_but_held_wait_does_not() -> void:
	_prepare_held_movement()
	InputMap.action_erase_events(&"move_east")
	InputMap.action_add_event(&"move_east", GlobalOptions.key_event(KEY_H))
	_send_key(KEY_H, true)
	_game._process(0.0)
	_game._process(2.0)
	assert_eq(_game.world.player_tile, Vector2i(22, 14))
	_send_key(KEY_H, false)
	_send_key(KEY_PERIOD, true)
	_game._process(0.0)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 3)
	_send_key(KEY_PERIOD, false)


func _prepare_held_movement() -> void:
	_game.set_process(false)
	_game.world = GridWorld.new(Rect2i(0, 0, 40, 28), Vector2i(20, 14))
	_game.grid_view.world = _game.world


func test_focused_hud_controls_suppress_gameplay_until_escape() -> void:
	var button := _game.get_node("HUD/PlayerMenu/Buttons/PlayerMenu") as Button
	button.grab_focus()
	await _tap_key(KEY_S)
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	assert_null(_game_viewport.gui_get_focus_owner())
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)


func test_player_menu_cancels_queued_movement_and_reset_restores_start() -> void:
	_send_key(KEY_S, true)
	_send_key(KEY_M, true)
	await get_tree().process_frame
	_send_key(KEY_S, false)
	_send_key(KEY_M, false)
	assert_eq(_game.menu.page, "player")
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	_game.world.movement_credit = 0.5
	_game.world.wait_turn()
	_game.reset_fixture()
	assert_eq(_game.world.movement_credit, 0.0)
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.player_tile, ValleyRoute.SPAWN)
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
	var event := GlobalOptions.key_event(key)
	event.keycode = event.physical_keycode
	event.pressed = pressed
	event.echo = echo
	_viewport.push_input(event)


func test_character_and_spell_book_keyboard_flow_casts_and_levels() -> void:
	_prepare_melee(GridActor.Relationship.HOSTILE)
	_game.set_process(true)
	await _tap_key(KEY_P)
	assert_true(_game.hero_panel.visible)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
	assert_true(_game.hero_panel.visible)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Mortal Strike")
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
	assert_eq(_game.world.player_tile, ValleyRoute.SPAWN)
	var chat := _game.get_node("HUD/Bottom/Rows/Chat") as RichTextLabel
	assert_string_contains(chat.text, "450 XP")
	assert_string_contains(chat.text, "level 2")
	var status := _game.get_node("HUD/Top/Rows/HeroStatus") as Label
	assert_string_contains(status.text, "Lv 2")
	assert_string_contains(status.text, "Rage")
	_game.grid_view._process(1.0)
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
	_game._open_player_menu()
	_game.menu._buttons[1].pressed.emit()
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
	_game._open_player_menu()
	_game.menu._buttons[0].pressed.emit()
	assert_true(_game.hero_panel.visible)

	await get_tree().process_frame


func test_release_spell_book_has_no_development_tab_or_controls() -> void:
	_game.hero_panel.open(HeroState.new(false), true)
	var tabs := _game.hero_panel.find_children("*", "TabContainer", true, false)[0] as TabContainer
	assert_eq(tabs.get_tab_count(), 2)
	assert_eq(tabs.get_tab_title(1), "Warrior")
	for button: Button in _game.hero_panel.find_children("*", "Button", true, false):
		assert_false(button.text.contains("450 XP"))
		assert_false(button.text.contains("Death trigger"))
		assert_false(button.text.contains("Kill stalker"))


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
	_game._process(Gameplay.MELEE_BOUNDARY_SECONDS / 2.0)
	assert_eq(_game.world.turn_count, 1, "The presentation gap leaves time to cancel.")
	for expected_turn in [2, 3, 4]:
		_game._process(Gameplay.MELEE_BOUNDARY_SECONDS)
		assert_eq(_game.world.turn_count, expected_turn)
	assert_null(_game.world.pending_melee)
	assert_eq(actor.swing.remaining, 6.0, "Each elapsed boundary grants the NPC its phase.")
	assert_string_contains("\n".join(_game.world.messages), "You ->")
	assert_false(_game.combat_panel.visible)
	assert_false((_game.get_node("HUD/Top/Rows/CancelAttack") as Button).visible)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 4, "Finishing a request does not start another attack.")


func test_melee_bumps_block_keyboard_mouse_actions_and_held_movement_until_finished() -> void:
	_prepare_melee(GridActor.Relationship.HOSTILE)
	_game.grid_view.set_process(false)
	await _tap_key(KEY_F)
	assert_null(_game.world.pending_melee)
	assert_true(_game.grid_view.is_melee_bumping())
	var tile := _game.world.player_tile
	var turn := _game.world.turn_count
	for key in [KEY_PERIOD, KEY_K, KEY_I, KEY_M, KEY_1]:
		await _tap_key(key)
	_send_key(KEY_S, true)
	_game._hotbar_slot_pressed(0)
	_game._open_inventory()
	_game._open_hero_panel(true)
	_game._process(1.0)
	assert_eq(_game.world.turn_count, turn)
	assert_eq(_game.world.player_tile, tile)
	assert_false(_game.hero_panel.visible)
	assert_false(_game.menu.visible)
	assert_false(_game._hotbar_can_edit())
	_game.grid_view._process(GridView.MELEE_BUMP_SECONDS * 10.0)
	assert_true(_game._hotbar_can_edit())
	_game._process(1.0)
	assert_eq(_game.world.turn_count, turn, "Blocked keys must not queue a later action.")
	_send_key(KEY_S, false)
	await _tap_key(KEY_PERIOD)
	_game._process(0.0)
	assert_eq(_game.world.turn_count, turn + 1)


func test_automatic_melee_can_be_canceled_between_boundaries_with_escape_or_mouse() -> void:
	var actor := _prepare_melee(GridActor.Relationship.HOSTILE)
	_game.grid_view.set_process(false)
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	_game.grid_view._process(1.0)
	_game._process(Gameplay.MELEE_BOUNDARY_SECONDS)
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.world.turn_count, 2)
	assert_null(_game.world.pending_melee)
	assert_eq(_game.world.hero.swing.remaining, 1.5)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 2)
	_game.grid_view._process(1.0)
	await _tap_key(KEY_F)
	assert_same(_game.world.pending_melee, actor)
	assert_true(_game.grid_view.is_melee_bumping())
	var cancel := _game.get_node("HUD/Top/Rows/CancelAttack") as Button
	assert_true(cancel.is_visible_in_tree())
	await _click_button(cancel)
	assert_null(_game.world.pending_melee)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 3)


func test_pending_melee_stops_on_invalid_target_reset_and_death() -> void:
	var actor := _prepare_melee(GridActor.Relationship.HOSTILE)
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	actor.tile += Vector2i(5, 0)
	_game.grid_view._process(1.0)
	_game._process(Gameplay.MELEE_BOUNDARY_SECONDS)
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
	actor.melee.hit = 100.0
	_game.world.hero.swing.remaining = 3.5
	await _tap_key(KEY_F)
	assert_false(_game.world.is_player_dead())
	assert_null(_game.world.pending_melee)
	assert_false(_game.combat_panel.visible)
	assert_eq(_game.session.loop_count, 2)
	_game._process(10.0)
	assert_eq(_game.world.turn_count, 0)


func test_friendly_interaction_and_empty_corpse_cleanup_skip_attack_dialogue() -> void:
	_game.world.actors.clear()
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible)
	assert_string_contains(_game.world.messages[-1], "No one")
	var actor := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	_game.world.actors.append(actor)
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible)
	var chat := _game.get_node("HUD/Bottom/Rows/Chat") as RichTextLabel
	assert_string_contains(chat.text, "Hello adventurer.")
	actor.alive = false
	await _tap_key(KEY_F)
	assert_false(_game.combat_panel.visible)
	assert_false(actor.corpse_visible)
	assert_false(_game.world.interaction_candidates().has(actor))
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.player_tile, ValleyRoute.SPAWN)
	var other := GridActor.new(actor.tile)
	_game.world.actors.append(other)
	var friend := GridActor.new(_game.world.player_tile + Vector2i.UP)
	_game.world.actors.append(friend)
	await _tap_key(KEY_F)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.SELECT)
	await _tap_key(KEY_W)
	assert_same(_game.combat_panel.selected, friend)
	await _tap_key(KEY_ENTER)
	assert_false(_game.combat_panel.visible, "Choosing a friendly adds no second dialogue.")
	assert_string_contains(_game.world.messages[-1], "Hello adventurer.")
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
	assert_string_contains(status.text, "Rage")
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)


func test_combat_mouse_buttons_choose_cancel_and_attack() -> void:
	_game.set_process(false)
	_game.world.actors.clear()
	var first := GridActor.new(_game.world.player_tile + Vector2i.LEFT)
	var second := GridActor.new(_game.world.player_tile + Vector2i.DOWN)
	second.relationship = GridActor.Relationship.NEUTRAL
	_game.world.actors.assign([first, second])
	_game.combat_panel.open_interaction(_game.world)
	_game.combat_panel.select_tile(second.tile)
	assert_same(_game.combat_panel.selected, second)
	for mode in [CombatPanel.Mode.SELECT, CombatPanel.Mode.CONFIRM_ATTACK]:
		assert_eq(_game.combat_panel.mode, mode)
		await get_tree().process_frame
		await get_tree().process_frame
		for control: Control in _game.combat_panel.find_children("*", "Control", true, false):
			if control.is_visible_in_tree():
				if control is Button:
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
	assert_false(_game.active_game)
	assert_eq(_game.menu.page, "world_seeds")
	assert_eq(_game.menu._buttons.size(), 6)
	for index in range(GameSession.WORLD_SEEDS.size()):
		var candidate := GameSession.WORLD_SEEDS[index]
		var suffix := " (HARD)" if candidate == GameSession.HARD_WORLD_SEED else ""
		assert_eq(_game.menu._buttons[index].text, candidate + suffix)
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.menu.page, "main")
	assert_null(_game.session.world)
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_S)
	await _tap_key(KEY_ENTER)
	assert_true(_game.active_game)
	assert_false(_game.menu.visible)
	assert_eq(_game.session.seed_name(), GameSession.WORLD_SEEDS[1])
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
	_prepare_melee(GridActor.Relationship.HOSTILE)
	_game.world.hero.find_skill(&"mortal_strike_1").cast_seconds = 2.0
	_game.set_process(false)
	await _tap_key(KEY_K)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.SPELL)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.turn_count, 1)
	assert_not_null(_game.world.pending_skill)
	assert_eq(_game.world.hero.rage, 100)
	await _tap_key(KEY_ESCAPE)
	assert_null(_game.world.pending_skill)
	_game._process(1.0)
	assert_eq(_game.world.turn_count, 1)
	assert_eq(_game.world.hero.rage, 100)


func test_enemy_spell_target_stays_selected_across_spells_until_it_dies() -> void:
	_game.set_process(false)
	var world := _game.world
	world.actors.clear()
	world.population.clear()
	world.blocked_tiles.clear()
	world.sight_blockers.clear()
	var near := GridActor.new(world.player_tile + Vector2i.RIGHT)
	near.relationship = GridActor.Relationship.HOSTILE
	near.health = 1000
	near.max_health = 1000
	near.stunned_until = 1000
	var far := GridActor.new(world.player_tile + Vector2i(3, 0))
	far.relationship = GridActor.Relationship.HOSTILE
	far.health = 1000
	far.max_health = 1000
	far.stunned_until = 1000
	world.actors.append_array([near, far])
	world.hero.add_experience(2700)
	assert_eq(world.hero.level, 4)
	assert_true(world.hero.learn_skill(SkillDefinition.catalog(&"charge_1")))
	var attack := world.hero.find_skill(&"mortal_strike_1")
	attack.range_tiles = 7
	attack.cast_seconds = 2.0
	var other_attack := world.hero.find_skill(&"charge_1")
	var panel := _game.combat_panel

	panel.open_spell(world, attack)
	assert_same(panel.selected, near, "The first cast starts with the nearest valid enemy.")
	panel.select_tile(far.tile)
	panel.confirm()
	assert_same(world.pending_target, far)
	world.cancel_cast()
	panel.open_spell(world, attack)
	assert_same(panel.selected, far, "The second Mortal Strike remembers the confirmed target.")
	panel.confirm()
	assert_same(world.pending_target, far)
	world.cancel_cast()

	panel.open_spell(world, other_attack)
	assert_same(panel.selected, far, "Another enemy spell shares the target.")
	panel.select_tile(near.tile)
	panel.cancel()
	panel.open_spell(world, other_attack)
	assert_same(panel.selected, far, "Canceling a new selection keeps the last confirmed target.")
	panel.cancel()
	far.alive = false
	panel.open_spell(world, attack)
	assert_same(panel.selected, near, "A dead target falls back to the nearest living enemy.")
	panel.cancel()


func test_warrior_trainer_visit_unlocks_passive_without_advancing_time() -> void:
	var world := _game.world
	StarterGear.exchange(world.hero, &"Warrior")
	world.hero.learned_skills.clear()
	for skill in SkillDefinition.starting_skills():
		world.hero.learn_skill(skill)
	world.player_tile = NpcDefinition.find(911).tile + Vector2i.UP
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "trainer")
	var passive: Button
	for button in _game.menu._buttons:
		if button.text.begins_with("Anger Management"):
			passive = button
	assert_not_null(passive)
	assert_false(passive.disabled, "Locked skills remain focusable for inspection.")
	passive.grab_focus()
	assert_true(_game.menu._preview.text.contains("Passive"))
	await _tap_key(KEY_ENTER)
	assert_null(world.hero.find_skill(&"anger_management_1"))
	world.hero.level = SkillDefinition.catalog(&"anger_management_1").training_level
	world.hero.copper = SkillDefinition.catalog(&"anger_management_1").training_copper
	_game.menu.open_trainer(&"Warrior")
	for button in _game.menu._buttons:
		if button.text.begins_with("Anger Management"):
			button.grab_focus()
	await _tap_key(KEY_ENTER)
	assert_not_null(world.hero.find_skill(&"anger_management_1"))
	assert_eq(_game_viewport.gui_get_focus_owner().get_meta("skill_id"), &"weapon_mastery_1",
		"With no affordable unlocks left, inspect the next unlearned skill below.")
	assert_string_contains(_game.menu._preview.text, "Passive")
	assert_eq(world.turn_count, 0)


func test_ingame_menus_wrap_keyboard_focus_without_advancing_time() -> void:
	for open_page: Callable in [
		_game.menu.open_options, _game.menu.open_slots, _game.menu.open_bindings,
		_game.menu.open_marshal, _game.menu.open_inventory,
	]:
		open_page.call()
		await get_tree().process_frame
		await get_tree().process_frame
		# Wrapping upward must reveal a distant final item, not just its nearest neighbor.
		await _tap_key(KEY_W)
		var last_focused := _game_viewport.gui_get_focus_owner() as Button
		assert_eq(last_focused.text, _game.menu._buttons[-1].text)
		await _tap_key(KEY_S)
		var count := _game.menu._buttons.size()
		for step in range(count):
			var focused := _game_viewport.gui_get_focus_owner() as Button
			assert_not_null(focused)
			await get_tree().process_frame
			await get_tree().process_frame
			await _tap_key(KEY_S)
		assert_eq(_game.world.turn_count, 0)
	_game.menu.close()


func test_lone_neutral_mortal_strike_casts_directly_from_all_eight_adjacent_tiles() -> void:
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
		_game.world.hero.rage = 30
		_game.world.combat_random.seed = 1
		await _tap_key(KEY_K)
		await _tap_key(KEY_ENTER)
		assert_false(_game.combat_panel.visible)
		assert_eq(_game.world.turn_count, 1)
		assert_true(target.engaged)
		_game._process(Gameplay.MELEE_BOUNDARY_SECONDS)
		assert_eq(_game.world.turn_count, 1)
		assert_eq(_game.world.hero.rage, 20)
		assert_lt(target.health, target.max_health)
		assert_null(_game.world.pending_skill)


func test_mortal_strike_with_insufficient_rage_reports_the_cost_instead_of_no_target() -> void:
	var target := _prepare_melee(GridActor.Relationship.NEUTRAL)
	_game.world.hero.rage = 29
	await _tap_key(KEY_K)
	await _tap_key(KEY_ENTER)
	assert_false(_game.combat_panel.visible)
	var chat := _game.get_node("HUD/Bottom/Rows/Chat") as RichTextLabel
	assert_string_contains(chat.text, "Not enough rage for Mortal Strike: requires 30, have 29.")
	assert_false(chat.text.contains("No valid target"))
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.hero.rage, 29)
	assert_false(target.engaged)
	assert_null(_game.world.pending_skill)


func test_supply_chest_keyboard_looting_is_free_and_empty_chest_cannot_duplicate_rewards() -> void:
	var chest := _game.world.actors[-1]
	assert_true(chest.chest)
	# Loot a fixed consumable; random gear may auto-equip instead of filling inventory.
	chest.loot_assigned = true
	chest.loot_copper = 12
	chest.loot = [ItemData.instance(118, 2)]
	_game.world.player_tile = chest.tile + Vector2i.LEFT
	_game.refresh_view()
	await _tap_key(KEY_D)
	assert_eq(_game.menu.page, "loot")
	assert_true(_game.menu.visible)
	assert_eq(chest.loot_copper, 12)
	assert_eq(chest.loot, [ItemData.instance(118, 2)])
	assert_eq(_game.world.hero.copper, 0)
	assert_eq(_game.world.player_tile, chest.tile + Vector2i.LEFT)
	await _tap_key(KEY_ESCAPE)
	assert_false(_game.menu.visible)
	await _tap_key(KEY_D)
	assert_eq(_game.menu.page, "loot")
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
	assert_eq(_game.world.hero.equipment.armor.id, 85)
	assert_eq(_game.world.turn_count, 1)
	assert_eq(_game.menu.page, "bags")
	_game.menu.close()
	_game.world.hero.health = 1
	_game.world.player_tile = Vector2i(40, 20)
	var attacker := GridActor.new(Vector2i(41, 20))
	attacker.relationship = GridActor.Relationship.HOSTILE
	attacker.engaged = true
	attacker.melee.level = 60
	attacker.melee.hit = 100.0
	attacker.melee.damage_min = 1000
	attacker.melee.damage_max = 1000
	_game.world.actors.append(attacker)
	_game.world.hero.inventory[1] = ItemData.instance(2129)
	_game.menu._item_detail(1)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.session.loop_count, 2)
	assert_false(_game.menu.visible)
	assert_eq(_game.world.hero.equipment.weapons.id, 35)


func test_empty_equipment_slot_filters_bags_and_equips_into_the_selected_ring_slot() -> void:
	var hero := _game.world.hero
	hero.inventory[0] = ItemData.instance(70002)
	hero.inventory[1] = ItemData.instance(70001)
	_game.menu.open_inventory()
	_game.menu._buttons[0].pressed.emit()
	assert_eq(_game.menu.page, "equipment_list")
	var ring := _game.menu._buttons[3]
	assert_false(ring.disabled)
	ring.pressed.emit()
	assert_eq(_game.menu.page, "equipment")
	var equip := _game.menu._buttons[0]
	assert_string_contains(equip.text, "Steady Band")
	assert_false(_game.menu._buttons.any(func(button: Button) -> bool:
		return button.text.contains("Patrol Amulet")))
	equip.grab_focus()
	assert_string_contains(_game.menu._preview.text, "strength")
	assert_eq(_game.world.turn_count, 0, "Inspection spends no turns.")
	equip.pressed.emit()
	assert_eq(hero.equipment.ring_2.id, 70002)
	assert_false(hero.equipment.has("ring_1"))
	assert_eq(_game.world.turn_count, 1)


func test_lone_neutral_keeps_spell_picker_when_another_actor_is_in_melee() -> void:
	var target := _prepare_melee(GridActor.Relationship.NEUTRAL)
	var friend := GridActor.new(_game.world.player_tile + Vector2i.LEFT)
	_game.world.actors.append(friend)
	_game._cast_skill(&"mortal_strike_1")
	assert_true(_game.combat_panel.visible)
	assert_same(_game.combat_panel.selected, target)
	assert_eq(_game.world.turn_count, 0)
	assert_false(target.engaged)


func test_trader_keyboard_quantity_purchase_never_moves_player_or_advances_time() -> void:
	_game.world.hero.inventory.fill({})
	_game.world.player_tile = _test_merchant(900003).tile + Vector2i.DOWN
	_game.world.hero.copper = 200
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	await _tap_key(KEY_S)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "trade")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "buy_list")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "buy")
	assert_true(_game.menu._buttons[0].text.begins_with("Buy 1 /"))
	await _tap_key(KEY_ENTER)
	assert_eq(_game.world.hero.inventory[0].id, 85)
	assert_eq(_game.world.hero.copper, 0)
	assert_eq(_game.world.player_tile, _test_merchant(900003).tile + Vector2i.DOWN)
	assert_eq(_game.world.turn_count, 0)


func test_spell_book_remembers_each_class_selection_across_close_and_loop() -> void:
	var hero := _game.world.hero
	assert_true(hero.learn_skill(SkillDefinition.catalog(&"lightning_shield_1")))
	assert_true(hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1")))
	await _tap_key(KEY_K)
	var shout :=  _game.hero_panel._skill_buttons.filter(func(button: Button) -> bool:
		return button.text.begins_with("Battle Shout"))[0] as Button
	shout.grab_focus()
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
	assert_eq(_game_viewport.gui_get_focus_owner().get_meta("skill_id"), &"battle_shout_1")
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Battle Shout")
	_game.hero_panel.change_tab(2)
	var healing := _game.hero_panel._skill_buttons.filter(func(button: Button) -> bool:
		return button.text.begins_with("Lava Burst"))[0] as Button
	healing.grab_focus()
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_K)
	assert_eq(_game.hero_panel._tabs.get_tab_title(_game.hero_panel._tabs.current_tab), "Shaman")
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Lava Burst")
	_game.hero_panel.change_tab(-2)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Battle Shout")
	_game.hero_panel.close()
	_game.world.cast_skill(&"death_1")
	_game.refresh_view()
	await _tap_key(KEY_K)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Battle Shout")
	_game.start_new_game()
	await _tap_key(KEY_K)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Mortal Strike")


func test_player_menu_inventory_entry_shows_binding_and_opens_without_time() -> void:
	for entry in [["Character", "P"], ["Spells", "K"], ["Inventory", "I"], ["Quests", "J"], ["Interact", "F"]]:
		var hud_button := _game.get_node("HUD/PlayerMenu/Buttons/" + entry[0]) as Button
		assert_eq(hud_button.text, "%s (%s)" % entry)
	_game._open_player_menu()
	var button := _game.menu._buttons[2]
	assert_eq(button.text, "Inventory (I)")
	button.pressed.emit()
	assert_eq(_game.menu.page, "inventory")
	assert_eq(_game.world.turn_count, 0)
	_game.menu.close()
	_game.menu.options.bindings["inventory"] = [KEY_B]
	_game.menu.options.apply_bindings()
	_game.refresh_view()
	assert_eq((_game.get_node("HUD/PlayerMenu/Buttons/Inventory") as Button).text, "Inventory (B)")
	_game._open_player_menu()
	assert_eq(_game.menu._buttons[2].text, "Inventory (B)")


func test_quest_tracker_updates_multiple_objectives_and_removes_hand_ins_and_abandoned_quests() -> void:
	var tracker := _game.get_node("HUD/QuestTracker") as Control
	var text := tracker.get_node("Text") as Label
	assert_false(tracker.visible, "No quests are tracked before accepting them.")
	var world := _game.world
	var marshal := world.actors[0]
	world.player_tile = marshal.tile + Vector2i.DOWN
	world.hero.level = 2
	assert_true(QuestRules.accept(world, "valley_mine", marshal))
	assert_true(QuestRules.accept(world, "valley_camp", marshal))
	_game.refresh_view()
	assert_true(tracker.visible)
	assert_string_contains(text.text, "Into Echo Ridge")
	assert_string_contains(text.text, "Kobold Worker: 0/2")
	assert_string_contains(text.text, "The Northern Camp")
	QuestRules.record_kill(world, 257)
	QuestRules.record_kill(world, 80)
	_game.refresh_view()
	assert_string_contains(text.text, "Kobold Worker: 1/2")
	assert_string_contains(text.text, "Kobold Laborer: Completed")
	assert_false(text.text.contains("Into Echo Ridge — Completed"))
	QuestRules.record_kill(world, 257)
	_game.refresh_view()
	assert_string_contains(text.text, "Into Echo Ridge — Completed")
	assert_string_contains(text.text, "Kobold Worker: Completed")
	assert_true(QuestRules.hand_in(world, "valley_mine", marshal))
	_game.refresh_view()
	assert_false(text.text.contains("Into Echo Ridge"))
	assert_string_contains(text.text, "The Northern Camp")
	assert_true(QuestRules.abandon(world, "valley_camp"))
	_game.refresh_view()
	assert_false(tracker.visible)
	assert_eq(text.text, "")
	assert_eq(world.turn_count, 0, "Tracking and quest transactions spend no turns.")


func test_quest_tracker_restores_progress_follows_hud_visibility_and_clears_on_death() -> void:
	var tracker := _game.get_node("HUD/QuestTracker") as Control
	var text := tracker.get_node("Text") as Label
	var world := _game.world
	var marshal := world.actors[0]
	world.player_tile = marshal.tile + Vector2i.DOWN
	assert_true(QuestRules.accept(world, "valley_wolves", marshal))
	QuestRules.record_kill(world, 299)
	QuestRules.record_kill(world, 299)
	var restored := SaveCodec.restore(SaveCodec.capture(_game.session), true)
	assert_not_null(restored)
	if restored == null:
		return
	_game.session.restore(restored, _game.session.seed_value, _game.session.loop_count)
	assert_true(tracker.visible)
	assert_string_contains(text.text, "Young Wolf: 2/8")
	_game.menu.open_player()
	assert_false(tracker.visible)
	_game.menu.close()
	assert_true(tracker.visible)
	await _tap_key(KEY_K)
	assert_false(tracker.visible)
	await _tap_key(KEY_ESCAPE)
	assert_true(tracker.visible)
	_game.world.hero.health = 0
	_game.refresh_view()
	assert_false(tracker.visible)
	assert_eq(text.text, "", "Quest state belongs to the previous Loop.")
	assert_eq(_game.world.turn_count, 0)


func test_quest_log_keyboard_accept_hand_in_abandon_and_focus_do_not_advance_time() -> void:
	var marshal := _game.world.actors[0]
	_game.world.player_tile = marshal.tile + Vector2i.DOWN
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "quest_detail")
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.quests.has("valley_wolves"))
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_J)
	assert_eq(_game.menu.page, "quests")
	assert_string_contains(_game.menu._buttons[0].text, "? ")
	var position := _game.world.player_tile
	await _tap_key(KEY_S)
	assert_eq(_game.world.player_tile, position)
	await _tap_key(KEY_ESCAPE)
	for count in range(8):
		QuestRules.record_kill(_game.world, 299)
	for count in range(5):
		QuestRules.record_kill(_game.world, 69)
	await _tap_key(KEY_F)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "quest_detail")
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.quests["valley_wolves"].handed_in)
	_game.world.hero.level = 10
	_game.menu._quest_detail("valley_camp", marshal)
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.quests.has("valley_camp"))
	_game.menu._quest_detail("valley_camp", null)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "confirm")
	await _tap_key(KEY_ESCAPE)
	assert_true(_game.world.quests.has("valley_camp"))
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_ENTER)
	assert_false(_game.world.quests.has("valley_camp"))
	assert_true(_game.world.ever_accepted_quest)
	assert_eq(_game.world.turn_count, 0)


func test_accepting_quests_focuses_the_next_available_quest_until_all_are_accepted() -> void:
	var marshal := _game.world.actors[0]
	_game.world.hero.level = 2
	_game.world.player_tile = marshal.tile + Vector2i.DOWN
	_game.menu.open_conversation(marshal)
	for identifier: String in ["valley_wolves", "valley_camp", "valley_mine"]:
		var focus := _game_viewport.gui_get_focus_owner() as Button
		assert_string_contains(focus.text, "! " + String(QuestData.QUESTS[identifier].title))
		await _tap_key(KEY_ENTER)
		assert_eq(_game.menu.page, "quest_detail")
		await _tap_key(KEY_ENTER)
		assert_true(_game.world.quests.has(identifier))
		assert_eq(_game.menu.page, "conversation")
	assert_eq((_game_viewport.gui_get_focus_owner() as Button).text, "Leave (Esc)")
	assert_eq(_game.world.turn_count, 0)


func test_quest_pages_support_keyboard_and_mouse_navigation() -> void:
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
	assert_eq(_game.world.turn_count, 0)


func _complete_demo_fixture() -> GridWorld:
	var world := _game.world
	world.turn_count = ValleyRoute.STALKER_DEADLINES[0]
	world._arrive_stalker()
	assert_true(world.cast_skill(&"kill_stalker_1"))
	_game.refresh_view()
	return world


func test_completion_keyboard_navigation_cannot_resume_and_main_menu_works() -> void:
	_game._pending_action = true
	var world := _complete_demo_fixture()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_game.menu.page, "completion")
	assert_eq((_game.menu._rows.get_child(0) as Label).text, "Beyond the valley")
	assert_eq(_game.menu._buttons.size(), 2)
	assert_eq(_game.menu._buttons[0].text, "Load")
	assert_eq(_game.menu._buttons[1].text, "Main Menu")
	assert_false(_game._pending_action)
	assert_false(_game.hero_panel.visible)
	assert_false(_game.combat_panel.visible)
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.menu.page, "completion")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "slots")
	for button in _game.menu._buttons:
		assert_false(button.text.begins_with("Save"))
	_game.refresh_view()
	assert_eq(_game.menu.page, "slots", "Repeated refresh preserves completion navigation.")
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.menu.page, "completion")
	_game._process(1.0)
	_game._cast_skill(&"battle_shout_1")
	assert_eq(world.turn_count, ValleyRoute.STALKER_DEADLINES[0] + 1)
	assert_eq(_game.session.loop_count, 1)
	await _tap_key(KEY_S)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "main")
	assert_null(_game.session.world)
	assert_false(_game.active_game)


func test_last_boss_death_during_item_turn_preserves_completion_menu() -> void:
	_game.world.hero.inventory.fill({})
	var world := _game.world
	var stalker := GridActor.new(world.player_tile + Vector2i.RIGHT)
	stalker.stalker = true
	stalker.relationship = GridActor.Relationship.HOSTILE
	world.actors.append(stalker)
	stalker.health = 1
	stalker.engaged = true
	stalker.melee.hit = 100
	stalker.melee.critical = 0
	world.hero.learn_skill(SkillDefinition.catalog(&"lightning_shield_1"))
	world.hero.buffs[&"lightning_shield_1"] = {"armor": 0, "charges": 3, "ready": 0, "until": 100}
	assert_true(InventoryRules.add(world.hero.inventory, ItemData.instance(118)))
	_game.menu.open_inventory()
	_game.menu._transaction(world.consume_item.bind(0), _game.menu.open_inventory)
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
	assert_false(stalker.alive)
	assert_eq(_game.menu.page, "completion")
	assert_true(_game.menu.visible)
	await get_tree().process_frame
	await get_tree().process_frame


func test_completion_load_returns_to_saved_game_and_clears_queued_input() -> void:
	var directory := "user://test_completion_ui_" + Crypto.new().generate_random_bytes(8).hex_encode()
	_game.menu.saves = SaveStore.new(directory)
	assert_true(_game.menu.saves.save_slot(_game.session, 1))
	var ended := _complete_demo_fixture()
	_game.menu._buttons[0].pressed.emit()
	_game.menu._request_load(1)
	assert_false(_game.menu.visible)
	assert_eq(_game.world.attempt_state, GridWorld.AttemptState.ACTIVE)
	assert_ne(_game.world, ended)
	assert_false(_game._pending_action)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_PERIOD)
	assert_eq(_game.world.turn_count, 1)
	assert_eq(ended.turn_count, ValleyRoute.STALKER_DEADLINES[0] + 1)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)


func test_simultaneous_player_and_boss_death_resets_loop_without_completion() -> void:
	_game.menu.open_inventory()
	var stale := _game.menu._buttons[-1]
	var world := _game.world
	var stalker := GridActor.new(world.player_tile + Vector2i.RIGHT)
	stalker.stalker = true
	stalker.health = 0
	world.actors.append(stalker)
	world.hero.health = 0
	world._check_npc_death(stalker)
	_game.refresh_view()
	stale.pressed.emit()
	_game.refresh_view()
	assert_ne(_game.menu.page, "completion")
	assert_ne(_game.session.world, world)
	assert_eq(_game.session.loop_count, 2)
	await get_tree().process_frame
	await get_tree().process_frame


func test_development_kill_last_stalker_completes_from_keyboard_and_mouse() -> void:
	for use_mouse in [false, true]:
		_game.start_new_game()
		for boundary in range(ValleyRoute.STALKER_DEADLINES[0]):
			_game.world.wait_turn()
		assert_true(_game.world.stalkers_arrived > 0)
		_game.refresh_view()
		await _tap_key(KEY_K)
		await _tap_key(KEY_D)
		for selection in range(4):
			await _tap_key(KEY_S)
		var button := _game_viewport.gui_get_focus_owner() as Button
		assert_not_null(button)
		assert_eq(button.get_meta("skill_id"), &"kill_stalker_1")
		assert_eq(_game.world.turn_count, ValleyRoute.STALKER_DEADLINES[0], "Navigation never spends a turn.")
		if use_mouse:
			await _click_button(button)
		else:
			await _tap_key(KEY_ENTER)
		assert_eq(_game.world.attempt_state, GridWorld.AttemptState.COMPLETED)
		assert_eq(_game.world.turn_count, ValleyRoute.STALKER_DEADLINES[0] + 1)
		assert_eq(_game.session.loop_count, 1)
		assert_eq(_game.menu.page, "completion")
		assert_true(_game.menu.visible)
		assert_false(_game.hero_panel.visible)


func test_hotbar_keyboard_assign_lock_activate_clear_and_cancel() -> void:
	await _tap_key(KEY_K)
	var panel := _game.hero_panel
	# W/S keeps skill navigation; Tab also reaches the assignment controls.
	await _tap_key(KEY_S)
	await _tap_key(KEY_S)
	await _tap_key(KEY_TAB)
	assert_same(_game_viewport.gui_get_focus_owner(), panel._assign)
	await _tap_key(KEY_ENTER)
	assert_true(panel.choosing_slot)
	await _tap_key(KEY_KP_1)
	assert_eq(_game.world.hotbar[0], &"mortal_strike_1", "Numpad movement is not slot selection.")
	await _tap_key(KEY_1)
	assert_eq(_game.world.hotbar[0], &"battle_shout_1")
	assert_false(panel.choosing_slot)
	assert_eq(_game.world.turn_count, 0)
	panel.begin_assignment()
	await _tap_key(KEY_ESCAPE)
	assert_true(panel.visible)
	assert_false(panel.choosing_slot)
	panel._lock.pressed.emit()
	assert_true(_game.world.hotbar_locked)
	assert_true(panel._assign.disabled)
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_1)
	assert_eq(_game.world.turn_count, 1, "Locking preserves activation.")
	assert_lt(_game.world.hero.rage, HeroState.MAX_RAGE)
	assert_false(_game.hero_panel.visible)
	_game.hotbar_panel.lock_button.pressed.emit()
	await _tap_key(KEY_K)
	panel.begin_assignment(true)
	await _tap_key(KEY_1)
	assert_eq(_game.world.hotbar[0], &"")
	assert_eq(_game.world.turn_count, 1)


func test_hotbar_uses_spell_book_targeting_and_rejects_activation_with_modal_owners() -> void:
	_prepare_melee(GridActor.Relationship.HOSTILE)
	_game.world.hero.find_skill(&"mortal_strike_1").cast_seconds = 2.0
	assert_true(_game.world.assign_hotbar(0, &"mortal_strike_1"))
	assert_true(_game.world.assign_hotbar(4, &"practice_1"))
	_game.refresh_view()
	await _tap_key(KEY_1)
	assert_true(_game.combat_panel.visible)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_5)
	assert_eq(_game.world.turn_count, 0, "Target selector owns hotbar keys.")
	await _tap_key(KEY_ENTER)
	assert_not_null(_game.world.pending_skill)
	var turns := _game.world.turn_count
	await _tap_key(KEY_5)
	assert_eq(_game.world.turn_count, turns, "Pending casts own hotbar keys.")
	await _tap_key(KEY_ESCAPE)
	_game.grid_view._process(1.0)
	_game.menu.open_options()
	await _tap_key(KEY_5)
	assert_eq(_game.world.turn_count, turns)
	_game.menu.close()
	await _tap_key(KEY_K)
	await _tap_key(KEY_5)
	assert_eq(_game.world.turn_count, turns, "The book does not activate slots.")
	await _tap_key(KEY_ESCAPE)
	var chat := _game.get_node("HUD/Bottom/Rows/Chat") as Control
	chat.grab_focus()
	await _tap_key(KEY_5)
	assert_eq(_game.world.turn_count, turns, "Focused chat suppresses gameplay keys.")
	chat.release_focus()
	await _tap_key(KEY_5)
	assert_eq(_game.world.turn_count, turns + 1)


func test_hotbar_rebinding_changes_activation_and_labels_but_not_slot_assignment_numbers() -> void:
	assert_true(_game.world.assign_hotbar(0, &"practice_1"))
	assert_true(_game.menu.options.rebind(&"hotbar_1", KEY_R, true))
	_game.refresh_view()
	assert_true(_game.hotbar_panel.slots[0].text.begins_with("R"))
	await _tap_key(KEY_1)
	assert_eq(_game.world.turn_count, 0)
	await _tap_key(KEY_R)
	assert_eq(_game.world.turn_count, 1)
	await _tap_key(KEY_K)
	_game.hero_panel.begin_assignment()
	await _tap_key(KEY_1)
	assert_eq(_game.world.hotbar[0], &"mortal_strike_1")
	assert_eq(_game.world.turn_count, 1)


func test_hotbar_drop_validates_skill_lock_and_world() -> void:
	await _tap_key(KEY_K)
	var bar := _game.hotbar_panel
	var skill := _game.world.hero.find_skill(&"mortal_strike_1")
	var data := {"skill_id": skill.id, "hero": _game.world.hero}
	assert_true(bar._can_drop(Vector2.ZERO, data, 0))
	bar._drop(Vector2.ZERO, data, 0)
	assert_eq(_game.world.hotbar[0], skill.id)
	assert_string_contains(bar.slots[0].tooltip_text, "Mortal Strike")
	assert_string_contains(bar.slots[0].tooltip_text, "30 rage")
	assert_string_contains(bar.slots[0].tooltip_text, "damage")
	assert_false(bar._can_drop(Vector2.ZERO, {"skill_id": &"fireball_2", "hero": _game.world.hero}, 0))
	_game._toggle_hotbar_lock()
	assert_false(bar._can_drop(Vector2.ZERO, data, 1))
	bar._drop(Vector2.ZERO, data, 1)
	assert_eq(_game.world.hotbar[1], &"whirlwind_1")
	assert_eq(_game.world.turn_count, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	_game.start_new_game()
	assert_false(bar._can_drop(Vector2.ZERO, data, 0), "A drag from an abandoned world is invalid.")
	assert_eq(_game.world.hotbar, [
		&"mortal_strike_1", &"whirlwind_1", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", GridWorld.FOOD_HOTBAR_ID,
	])


func test_native_drag_from_spell_book_and_mouse_assignment_activate_exact_skill() -> void:
	await _tap_key(KEY_K)
	var button := _game.hero_panel._skill_buttons.filter(func(skill: Button) -> bool:
		return skill.get_meta("skill_id") == &"battle_shout_1")[0] as SkillButton
	var destination := _game.hotbar_panel.slots[3].get_global_rect().get_center()
	var origin := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = origin
	motion.global_position = origin
	_viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.position = origin
	press.global_position = origin
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(press, true)
	motion.position = origin + Vector2(16, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(16, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(motion, true)
	await get_tree().process_frame
	assert_true(_game_viewport.gui_is_dragging(), "Godot started a native skill drag.")
	motion.relative = destination - motion.position
	motion.position = destination
	motion.global_position = destination
	_viewport.push_input(motion, true)
	await get_tree().process_frame
	press.position = destination
	press.global_position = destination
	press.pressed = false
	press.button_mask = 0
	_viewport.push_input(press, true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_game.world.hotbar[3], &"battle_shout_1")
	assert_eq(_game.world.turn_count, 0, "Dragging does not activate the source spell.")
	await _tap_key(KEY_ESCAPE)
	await _click_button(_game.hotbar_panel.slots[3])
	assert_eq(_game.world.turn_count, 1)
	assert_lt(_game.world.hero.rage, HeroState.MAX_RAGE)


func test_tab_to_assign_keeps_first_skill_and_details_can_scroll_with_keyboard() -> void:
	_game.world.hero.level = 10
	for identifier in SkillDefinition.all_skills():
		_game.world.hero.learn_skill(SkillDefinition.catalog(StringName(identifier)))
	await _tap_key(KEY_K)
	await _tap_key(KEY_TAB)
	assert_same(_game_viewport.gui_get_focus_owner(), _game.hero_panel._assign)
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_2)
	assert_eq(_game.world.hotbar[1], &"mortal_strike_1", "Tab to Assign must preserve the selected skill.")
	var details := _game.hero_panel._details
	details.text = "Long skill effect details.\n".repeat(20)
	details.grab_focus()
	await get_tree().process_frame
	await _tap_key(KEY_S)
	assert_gt(details.get_v_scroll_bar().value, 0.0)
	assert_same(_game_viewport.gui_get_focus_owner(), details)
	assert_eq(_game.world.turn_count, 0)


func test_merchant_interaction_keeps_identity_through_keyboard_buy_cancel_and_mouse_sell() -> void:
	_game.world.hero.inventory.fill({})
	var danil := _test_merchant(152)
	_game.world.player_tile = danil.tile + Vector2i.DOWN
	_game.world.hero.copper = 100
	_game.refresh_view()
	await _tap_key(KEY_F)
	assert_eq(_game.menu.page, "conversation")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "trade")
	assert_eq(_game.menu._buttons.map(func(button: Button) -> String: return button.text),
		["Buy", "Sell", "Leave (Esc)"])
	assert_string_contains((_game.menu._rows.get_child(0) as Label).text, "Brother Danil")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "buy_list")
	assert_eq(_game.menu._buttons.size(), 2, "Buying shows only this merchant's catalog and Back.")
	assert_string_contains(_game.menu._buttons[0].text, "Tough Jerky / 0g 0s 5c each")
	assert_eq(_game.menu._buttons[1].text, "Back (Esc)")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "buy")
	assert_eq(_game.menu._buttons.map(func(button: Button) -> String: return button.text),
		["Buy 1 / 0g 0s 5c", "Buy 10 / 0g 0s 50c", "Buy stack (20) / 0g 1s 0c", "Back (Esc)"])
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.menu.page, "buy_list")
	assert_same(_game.menu._merchant, danil)
	assert_eq(_game.world.hero.copper, 100, "Backing out never purchases.")
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_S)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "buy_list")
	assert_eq(_game.world.hero.inventory[0], ItemData.instance(117, 10))
	assert_eq(_game.world.hero.copper, 50)
	await _tap_key(KEY_ESCAPE)
	assert_eq(_game.menu.page, "trade")
	for frame in range(4):
		await get_tree().process_frame
	await _click_button(_game.menu._buttons[1])
	assert_eq(_game.menu.page, "sell")
	var sell := _game_viewport.gui_get_focus_owner() as Button
	assert_eq(sell.text, "Sell slot 1: Tough Jerky x10 / 0g 0s 10c total")
	for frame in range(4):
		await get_tree().process_frame
	await _click_button(sell)
	assert_eq(_game.menu.page, "sell", "A click sells the whole stack without another menu.")
	assert_same(_game.menu._merchant, danil)
	assert_true(_game.world.hero.inventory[0].is_empty())
	assert_eq(_game.world.hero.copper, 60)
	assert_eq((_game_viewport.gui_get_focus_owner() as Button).text, "Back (Esc)")
	assert_eq(_game.world.turn_count, 0)
	assert_eq(_game.world.player_tile, danil.tile + Vector2i.DOWN)


func test_every_merchant_catalog_and_full_bag_remain_keyboard_accessible() -> void:
	for index in range(40):
		_game.world.hero.inventory[index] = ItemData.instance(117, 20)
	for npc_id in [152, 190, 1213, 78, 900003]:
		var merchant := _test_merchant(npc_id)
		for direction in GridWorld.DIRECTIONS:
			if _game.world.is_open(merchant.tile + direction):
				_game.world.player_tile = merchant.tile + direction
				break
		_game.menu.open_conversation(merchant)
		if npc_id == 900003:
			await _tap_key(KEY_S)
		await _tap_key(KEY_ENTER)
		assert_eq(_game.menu.page, "trade")
		assert_eq(_game.menu._buttons.size(), 3, "A full bag does not clutter the trade entry page.")
		for open_page in [_game.menu.open_buy.bind(merchant), _game.menu.open_sell.bind(merchant)]:
			open_page.call()
			assert_same(_game.menu._merchant, merchant)
			var expected := MerchantData.catalog(npc_id).size() + 1 if (
				_game.menu.page == "buy_list") else 42
			assert_eq(_game.menu._buttons.size(), expected)
			for button in _game.menu._buttons:
				button.grab_focus()
				assert_same(_game_viewport.gui_get_focus_owner(), button)
			await _tap_key(KEY_ESCAPE)
			assert_eq(_game.menu.page, "trade")
		assert_eq(_game.world.turn_count, 0)


func test_trade_stack_options_respect_money_and_stock() -> void:
	var merchant := _game.world.actors.filter(func(actor: GridActor) -> bool:
		return actor.npc_id == 900003)[0] as GridActor
	_game.world.player_tile = _test_merchant(900003).tile + Vector2i.DOWN
	_game.world.hero.copper = 200
	_game.menu.open_trade(merchant)
	_game.menu._buy_options(118)
	assert_eq(_game.menu._buttons.size(), 3, "Potions offer 1 and stack, without 10.")
	assert_true(_game.menu._buttons[1].text.begins_with("Buy stack (5)"))
	assert_true(_game.menu._buttons[1].disabled, "Stock of three cannot fill a stack of five.")
	_game.menu._buy_options(117)
	_game.menu._buttons[2].grab_focus()
	for frame in range(4):
		await get_tree().process_frame
	await _click_button(_game.menu._buttons[2])
	assert_eq(_game.world.hero.inventory[0], ItemData.instance(117, 20))
	assert_eq(_game.world.hero.copper, 100)
	_game.world.hero.copper = 4
	_game.menu._buy_options(117)
	for index in range(3):
		assert_true(_game.menu._buttons[index].disabled)
	_game.menu.open_sell(merchant)
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.hero.inventory[0].is_empty())
	assert_eq(_game.world.hero.copper, 24)
	assert_eq(_game.world.turn_count, 0)


func test_mouse_loot_all_and_keyboard_sell_all_grey_are_free() -> void:
	_game.world.hero.inventory.fill({})
	var chest := _game.world.actors.filter(func(actor: GridActor) -> bool:
		return actor.chest and actor.loot_table == 2843)[0] as GridActor
	_game.world.player_tile = chest.tile
	chest.loot_assigned = true
	chest.loot_copper = 8
	chest.loot = [ItemData.instance(7073, 2), ItemData.instance(117, 3)]
	_game.menu.open_loot(chest)
	assert_eq(_game.menu._buttons[0].text, "Loot All")
	for frame in range(4):
		await get_tree().process_frame
	await _click_button(_game.menu._buttons[0])
	assert_false(_game.menu.visible)
	assert_false(chest.corpse_visible)
	assert_eq(_game.world.hero.copper, 8)
	var merchant := _test_merchant(152)
	_game.world.player_tile = merchant.tile + Vector2i.DOWN
	_game.menu.open_sell(merchant)
	var sell := _game.menu._buttons.filter(func(button: Button) -> bool:
		return button.text == "Sell All Grey Items")[0] as Button
	sell.grab_focus()
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "sell")
	assert_true(_game.world.hero.inventory[0].is_empty())
	assert_eq(_game.world.hero.inventory[1], ItemData.instance(117, 3))
	assert_eq(_game.world.hero.copper, 20)
	assert_eq(_game.world.turn_count, 0)


func test_consecutive_sales_select_next_sellable_slot_and_wrap_after_the_last() -> void:
	var merchant := _test_merchant(152)
	_game.world.player_tile = merchant.tile + Vector2i.DOWN
	for index in range(40):
		_game.world.hero.inventory[index] = {}
	_game.world.hero.inventory[0] = ItemData.instance(35)
	_game.world.hero.inventory[1] = ItemData.instance(750)
	_game.world.hero.inventory[3] = ItemData.instance(117, 20)
	_game.world.hero.inventory[25] = ItemData.instance(117, 7)
	_game.world.hero.inventory[39] = ItemData.instance(117)
	var stock := _game.world.vendor_stock.duplicate(true)
	_game.menu.open_trade(merchant)
	await _tap_key(KEY_S)
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "sell")
	var water := _game.menu._buttons.filter(func(button: Button) -> bool:
		return button.text.begins_with("Sell slot 4:"))[0] as Button
	water.grab_focus()
	var proceeds := 0
	for entry in [[3, 20, "Tough Jerky"], [25, 7, "Tough Jerky"],
		[39, 1, "Tough Jerky"]]:
		var focused := _game_viewport.gui_get_focus_owner() as Button
		assert_string_contains(focused.text, "%s x%d" % [entry[2], int(entry[1])])
		for frame in range(4):
			await get_tree().process_frame
		await _tap_key(KEY_ENTER)
		proceeds += int(entry[1])
		assert_true(_game.world.hero.inventory[int(entry[0])].is_empty())
		assert_eq(_game.world.hero.copper, proceeds)
		assert_eq(_game.menu.page, "sell")
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Sell slot 1:")
	await _tap_key(KEY_ENTER)
	assert_true(_game.world.hero.inventory[0].is_empty())
	assert_eq((_game_viewport.gui_get_focus_owner() as Button).text, "Back (Esc)")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "trade")
	assert_eq(_game.world.hero.inventory[1], ItemData.instance(750))
	assert_eq(_game.world.vendor_stock, stock)
	assert_eq(_game.world.hero.copper, 30)
	assert_eq(_game.world.player_tile, merchant.tile + Vector2i.DOWN)
	assert_eq(_game.world.turn_count, 0)


func test_sell_page_excludes_untradable_items_and_handles_empty_and_single_item_stacks() -> void:
	var merchant := _test_merchant(152)
	_game.world.player_tile = merchant.tile + Vector2i.DOWN
	_game.world.hero.inventory[0] = ItemData.instance(750, 2)
	_game.world.hero.inventory[1] = ItemData.instance(750, 4)
	_game.menu.open_sell(merchant)
	assert_eq(_game.menu._buttons.size(), 2)
	assert_true(_game.menu._buttons[0].disabled, "No grey goods to sell.")
	assert_eq((_game_viewport.gui_get_focus_owner() as Button).text, "Back (Esc)")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "trade")
	_game.world.hero.inventory[2] = ItemData.instance(35)
	_game.menu.open_sell(merchant)
	assert_string_contains((_game_viewport.gui_get_focus_owner() as Button).text, "Bent Staff x1")
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "sell")
	assert_true(_game.world.hero.inventory[2].is_empty())
	assert_eq(_game.world.hero.copper, 2)
	assert_eq(_game.world.hero.inventory[0], ItemData.instance(750, 2))
	assert_eq(_game.world.hero.inventory[1], ItemData.instance(750, 4))
	assert_eq(_game.world.turn_count, 0)


func test_direct_sell_revalidates_merchant_range_and_rejects_buttons_from_replaced_world() -> void:
	var merchant := _test_merchant(152)
	_game.world.player_tile = merchant.tile + Vector2i.DOWN
	_game.world.hero.inventory[0] = ItemData.instance(117, 7)
	_game.menu.open_sell(merchant)
	_game.world.player_tile = ValleyRoute.SPAWN
	await _tap_key(KEY_ENTER)
	assert_eq(_game.menu.page, "notice")
	assert_eq(_game.world.hero.inventory[0], ItemData.instance(117, 7))
	assert_eq(_game.world.hero.copper, 0)
	await _tap_key(KEY_ENTER)
	assert_false(_game.menu.visible)
	_game.world.player_tile = merchant.tile + Vector2i.DOWN
	_game.menu.open_sell(merchant)
	var stale := _game_viewport.gui_get_focus_owner() as Button
	var previous := _game.world
	_game.start_new_game()
	stale.pressed.emit()
	assert_eq(previous.hero.inventory[0], ItemData.instance(117, 7))
	assert_eq(previous.hero.copper, 0)
	assert_eq(_game.world.hero.copper, 0)
	assert_eq(_game.world.turn_count, 0)


func test_extended_hotbar_keys_assign_and_activate_without_numpad_conflicts() -> void:
	_game.world.actors.clear()
	for index in range(5, 20):
		assert_true(_game.world.assign_hotbar(index, &"practice_1"))
		await _tap_key(GlobalOptions.HOTBAR_KEYS[index])
		assert_eq(_game.world.turn_count, index - 4)
	await _tap_key(KEY_K)
	_game.hero_panel.begin_assignment()
	await _tap_key(KEY_V | KEY_MASK_SHIFT)
	assert_eq(_game.world.hotbar[19], &"mortal_strike_1")
	assert_eq(_game.world.turn_count, 15, "Assignment is free.")


func test_interact_button_opens_selection_and_cancels_queued_movement_for_free() -> void:
	_game.world.actors.clear()
	var actor := GridActor.new(_game.world.player_tile + Vector2i.UP)
	actor.relationship = GridActor.Relationship.NEUTRAL
	_game.world.actors.append(actor)
	_send_key(KEY_S, true)
	var button := _game.get_node("HUD/PlayerMenu/Buttons/Interact") as Button
	await _click_button(button)
	_send_key(KEY_S, false)
	assert_same(_game.combat_panel.selected, actor)
	assert_true(_game.combat_panel.visible)
	assert_false(_game._pending_action)
	assert_eq(_game.world.turn_count, 0)
	assert_false(actor.engaged)
	await _tap_key(KEY_ESCAPE)
	assert_false(_game.combat_panel.visible)
	assert_null(_game_viewport.gui_get_focus_owner())


func test_new_game_launches_the_valley_with_the_hard_worlds_original_seed() -> void:
	_game._return_to_menu()
	_game.menu.open_main()
	_game.menu._buttons[0].pressed.emit()
	assert_eq(_game.menu.page, "world_seeds")
	var hard_index := GameSession.WORLD_SEEDS.find(GameSession.HARD_WORLD_SEED)
	assert_eq(_game.menu._buttons[hard_index].text, "solemnly-moonwell (HARD)")
	_game.menu._buttons[hard_index].pressed.emit()
	await get_tree().process_frame
	assert_true(_game.active_game)
	assert_false(_game.menu.visible)
	assert_eq(_game.session.seed_value, GameSession.HARD_WORLD_SEED.hash())
	assert_eq(_game.session.seed_name(), GameSession.HARD_WORLD_SEED)
	assert_true(_game.world.valley_route)
	assert_eq(_game.world.player_tile, ValleyRoute.SPAWN)
	assert_true(_game.grid_view.visible)
	await _tap_key(KEY_W)
	assert_eq(_game.world.player_tile, ValleyRoute.SPAWN + Vector2i.UP)
	assert_eq(_game.world.turn_count, 1)


func test_poison_hotbar_keyboard_selects_hands_and_single_weapon_casts_directly() -> void:
	var world := _game.world
	world.actors.clear()
	world.hero.equipment.weapons = ItemData.instance(2224)
	for identifier in PoisonRules.COATINGS:
		world.hero.learn_skill(SkillDefinition.catalog(identifier))
	world.hero.refresh_stats()
	world.hotbar[0] = &"deadly_poison_1"
	world.hotbar[1] = &"instant_poison_1"
	await _tap_key(KEY_1)
	assert_eq(_game.combat_panel.mode, CombatPanel.Mode.POISON)
	assert_true(_game.combat_panel.visible)
	await _tap_key(KEY_D)
	assert_eq(_game.combat_panel._poison_hands, PoisonRules.Hands.MAIN)
	await _tap_key(KEY_ESCAPE)
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 100)
	await _tap_key(KEY_1)
	await _tap_key(KEY_D)
	await _tap_key(KEY_ENTER)
	assert_false(_game.combat_panel.visible)
	assert_eq(world.turn_count, 1)
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"deadly_poison_1")
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, true), &"")
	await _tap_key(KEY_2)
	await _tap_key(KEY_A)
	await _tap_key(KEY_ENTER)
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"deadly_poison_1")
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, true), &"instant_poison_1")
	world.hero.equipment.weapons = ItemData.instance(35)
	world.hero.refresh_stats()
	await _tap_key(KEY_2)
	assert_false(_game.combat_panel.visible)
	assert_eq(world.turn_count, 3)
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"instant_poison_1")


func test_hud_refresh_does_not_advance_casts_expire_buffs_or_change_world_state() -> void:
	var world := _game.world
	world.hero.buffs[&"battle_shout_1"] = {"armor": 0, "until": world.turn_count,
		"physical_percent": 10}
	world.pending_skill = world.hero.find_skill(&"mortal_strike_1")
	world.cast_elapsed = 0
	var snapshot := SaveCodec.capture(_game.session)
	for index in range(3):
		_game.hud.refresh(world, _game.session.loop_count, _game.menu.options)
		_game.hud.refresh_resources(world, true)
	assert_eq(SaveCodec.capture(_game.session), snapshot)
	assert_eq(world.cast_elapsed, 0)
	assert_not_null(world.pending_skill)
	assert_true(world.hero.buffs.has(&"battle_shout_1"))
	assert_eq(_game.get_node("HUD/Auras").get_child_count(), 1)


func _test_merchant(identity: int) -> GridActor:
	for actor in _game.world.actors:
		if actor.npc_id == identity:
			return actor
	var merchant := GridActor.new(Vector2i(27, 55))
	merchant.npc_id = identity
	merchant.title = "Brother Danil" if identity == 152 else "Test merchant"
	merchant.spawn_id = "test/merchant/%d" % identity
	merchant.service = &"Trader"
	_game.world.actors.append(merchant)
	_game.world.vendor_stock.merge(MerchantData.initial_stock([merchant]))
	return merchant


func test_food_shortcut_displays_eating_healing_and_stops_on_movement() -> void:
	var world := _game.world
	world.stalker_schedule = false
	world.hero.health = 1
	await _tap_key(KEY_V | KEY_MASK_SHIFT)
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.inventory[0].quantity, 4)
	var auras := _game.get_node("HUD/Auras")
	var eating: Control
	for aura in auras.get_children():
		if aura.tooltip_text.begins_with("Eating"):
			eating = aura
	assert_not_null(eating)
	if eating == null:
		return
	assert_string_contains(eating.tooltip_text, "HP next turn")
	assert_string_contains((eating.get_node("Healing") as Label).text, "+")
	await _tap_key(KEY_PERIOD)
	assert_gt(int(world.hero.restoration.food.delivered), 0)
	await _tap_key(KEY_S)
	assert_true(world.hero.restoration.is_empty())
	for aura in auras.get_children():
		assert_false(aura.tooltip_text.begins_with("Eating"))


func test_engaged_enemy_frame_tracks_target_health_and_unfinished_quest_objectives() -> void:
	var world := _game.world
	var marshal := world.actors[0]
	world.player_tile = marshal.tile + Vector2i.DOWN
	assert_true(QuestRules.accept(world, "valley_wolves", marshal))
	var wolf: GridActor = world.actors.filter(func(actor: GridActor) -> bool:
		return actor.npc_id == 299)[0]
	var timber: GridActor = world.actors.filter(func(actor: GridActor) -> bool:
		return actor.npc_id == 69)[0]
	wolf.engaged = true
	timber.engaged = true
	world.auto_attack_target = wolf
	_game.refresh_view()
	var frame := _game.get_node("HUD/Enemy") as Control
	var marker := frame.get_node("Rows/Heading/Objective") as Label
	assert_true(frame.visible)
	assert_eq((frame.get_node("Rows/Heading/Name") as Label).text, wolf.title)
	assert_true(marker.visible)
	wolf.health -= 5
	_game.refresh_view()
	assert_eq((frame.get_node("Rows/Health") as ProgressBar).value, float(wolf.health))
	for count in range(8):
		QuestRules.record_kill(world, 299)
	_game.refresh_view()
	assert_false(marker.visible)
	world.auto_attack_target = timber
	_game.refresh_view()
	assert_eq((frame.get_node("Rows/Heading/Name") as Label).text, timber.title)
	assert_true(marker.visible)
	assert_true(QuestRules.abandon(world, "valley_wolves"))
	_game.refresh_view()
	assert_false(marker.visible)
	timber.alive = false
	_game.refresh_view()
	assert_false(frame.visible)


func test_equipment_preview_compares_against_the_exact_selected_ring_slot() -> void:
	var hero := _game.world.hero
	hero.equipment.ring_1 = ItemData.instance(70002)
	hero.equipment.ring_2 = ItemData.instance(70003)
	hero.inventory[1] = ItemData.instance(70012)
	_game.menu._equipped_detail("ring_1")
	var candidate: Button = _game.menu._buttons.filter(func(button: Button) -> bool:
		return button.text.begins_with("Wolfstone Ring"))[0]
	candidate.grab_focus()
	assert_string_contains(_game.menu._preview.text, "(+1)")
	assert_false(_game.menu._preview.text.contains("haste"))
	assert_string_contains((candidate.get_node("ItemText") as RichTextLabel).text,
		"[color=#1eff00]Wolfstone Ring[/color] (1 turn)")
	_game.menu._equipped_detail("ring_2")
	candidate = _game.menu._buttons.filter(func(button: Button) -> bool:
		return button.text.begins_with("Wolfstone Ring"))[0]
	candidate.grab_focus()
	assert_string_contains(_game.menu._preview.text, "(-2.00% haste)")
	assert_string_contains(_game.menu._preview.text, "(+2 strength)")
	assert_eq(_game.world.turn_count, 0)


func test_sentence_hotkey_casts_on_engaged_enemy_without_opening_target_picker() -> void:
	var enemy := _prepare_melee(GridActor.Relationship.HOSTILE)
	var world := _game.world
	enemy.engaged = true
	enemy.health = 10000
	enemy.max_health = 10000
	enemy.melee.dodge = 0
	enemy.stunned_until = 999
	world.hero.melee.hit = 100
	world.hero.swing.remaining = 100
	world.hero.swing._active = true
	world.hero.learn_skill(SkillDefinition.catalog(&"seal_of_command_1"))
	world.hero.learn_skill(SkillDefinition.catalog(&"judgement_1"))
	world.auto_attack_target = enemy
	world.last_attacked_enemy = enemy
	assert_true(world.assign_hotbar(0, &"judgement_1"))
	await _tap_key(KEY_1)
	assert_eq(world.turn_count, 1)
	assert_false(_game.combat_panel.visible)
	assert_true(enemy.debuffs.has(&"judgement_1"))
	assert_eq(enemy.health, 10000)
