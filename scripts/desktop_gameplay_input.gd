class_name DesktopGameplayInput
extends GameplayInput

var _held_move_keys: Dictionary[Key, Vector2i] = {}
var _repeat_key: Key = KEY_NONE
var _repeat_seconds: float = 0.0
var _repeat_arrow: bool = false


func clear() -> void:
	_held_move_keys.clear()
	_repeat_key = KEY_NONE
	_repeat_seconds = 0.0
	_repeat_arrow = false


func process_movement(delta: float) -> void:
	if not game._pending_action and _repeat_key != KEY_NONE:
		_repeat_seconds -= delta
		if _repeat_seconds <= 0.0 or is_zero_approx(_repeat_seconds):
			game._pending_direction = _held_move_keys[_repeat_key]
			game._pending_arrow = _repeat_arrow
			game._pending_action = true
			_repeat_seconds = Gameplay.MOVE_REPEAT_INTERVAL_SECONDS


func resolve_direction(direction: Vector2i) -> Vector2i:
	if game._pending_arrow:
		var arrows := Vector2i(
			int(_held_move_keys.has(KEY_RIGHT)) - int(_held_move_keys.has(KEY_LEFT)),
			int(_held_move_keys.has(KEY_DOWN)) - int(_held_move_keys.has(KEY_UP)))
		if arrows != Vector2i.ZERO:
			return arrows
	return direction


func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.is_pressed():
		_release_movement_key(event.physical_keycode)
	if game.active_game and game.world.is_charging():
		game._pending_action = false
		game.get_viewport().set_input_as_handled()
		return
	if game.active_game and game.grid_view.is_melee_bumping():
		game._pending_action = false
		if event is InputEventKey:
			if event.is_action_pressed("ui_cancel") and (
				game.world.pending_melee != null or game.world.pending_skill != null):
				game._cancel_pending_melee()
			game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var movement_key := false
		for action in Gameplay.MOVE_ACTIONS:
			if event.is_action_pressed(action, false, true):
				movement_key = true
				break
		if not movement_key:
			game._clear_movement_hold()
		if event.is_action_pressed("fullscreen", false, true) and game.menu._capture_action == &"":
			game.menu.toggle_fullscreen()
			game.get_viewport().set_input_as_handled()
			return
		if game.menu.visible:
			game._pending_action = false
			game.menu.handle_key(event)
			game.get_viewport().set_input_as_handled()
			return
	if game.menu.visible or not game.active_game or game.world.is_terminal():
		return
	if game.world.pending_skill != null:
		game._pending_action = false
		if event is InputEventKey and event.is_pressed():
			if not event.is_echo() and event.is_action_pressed("ui_cancel", false, true):
				game.world.cancel_cast()
				game.refresh_view()
			game.get_viewport().set_input_as_handled()
		return
	if game.world.pending_melee != null:
		game._pending_action = false
		if event is InputEventKey and event.is_pressed():
			if not event.is_echo() and event.is_action_pressed("ui_cancel", false, true):
				game._cancel_pending_melee()
			game.get_viewport().set_input_as_handled()
		return
	if game.combat_panel.visible:
		_handle_combat_input(event)
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if game.hero_panel.visible:
		game._pending_action = false
		if game.hero_panel.handle_assignment_key(event):
			game.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel", false, true) or event.is_action_pressed("spell_book", false, true):
			game.hero_panel.close()
		elif event.is_action_pressed("character", false, true):
			game._open_hero_panel(false)
		elif event.is_action_pressed("ui_focus_next", false, true):
			game.hero_panel.navigate(true, true)
		elif event.is_action_pressed("ui_focus_prev", false, true):
			game.hero_panel.navigate(false, true)
		elif event.is_action_pressed("move_east", false, true):
			game.hero_panel.change_tab(1)
		elif event.is_action_pressed("move_west", false, true):
			game.hero_panel.change_tab(-1)
		elif event.is_action_pressed("wait", false, true):
			pass
		else:
			var matched := false
			for index in range(Gameplay.MOVE_ACTIONS.size()):
				if event.is_action_pressed(Gameplay.MOVE_ACTIONS[index], false, true):
					game.hero_panel.navigate(index in [3, 4, 5])
					matched = true
					break
			if not matched:
				return
		game.get_viewport().set_input_as_handled()
	elif not game.world.is_terminal() and game.get_viewport().gui_get_focus_owner() == null:
		if event.is_action_pressed("character", false, true) or event.is_action_pressed("spell_book", false, true):
			game._open_hero_panel(event.is_action_pressed("spell_book", false, true))
			game.get_viewport().set_input_as_handled()


func handle_key(event: InputEvent) -> void:
	if game.menu.visible or not game.active_game or game.world.is_terminal() or game.grid_view.is_melee_bumping():
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel", false, true):
		var focused := game.get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		else:
			game._open_options()
		game._pending_action = false
		game.get_viewport().set_input_as_handled()
		return
	if (game.world.is_terminal() or game.world.pending_melee != null
		or game.world.pending_skill != null or game.combat_panel.visible or game.hero_panel.visible
		or game.get_viewport().gui_get_focus_owner() != null):
		return
	for index in range(game.world.hotbar.size()):
		if event.is_action_pressed("hotbar_%d" % (index + 1), false, true):
			game._hotbar_slot_pressed(index)
			game.get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("player_menu", false, true):
		game._open_player_menu()
		game.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("options", false, true):
		game._open_options()
		game.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quest_log", false, true):
		game._pending_action = false
		game.menu.open_quest_log()
		game.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory", false, true):
		game._open_inventory()
		game.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact", false, true):
		game._open_interaction()
		game.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wait", false, true):
		game._pending_direction = Vector2i.ZERO
		game._pending_arrow = false
		game._pending_action = true
	else:
		var matched := false
		for index in range(Gameplay.MOVE_ACTIONS.size()):
			if event.is_action_pressed(Gameplay.MOVE_ACTIONS[index], false, true):
				game._pending_direction = GridWorld.DIRECTIONS[index]
				game._pending_arrow = (event.physical_keycode in [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]
						and _default_arrow_bindings())
				game._pending_action = true
				_held_move_keys[event.physical_keycode] = game._pending_direction
				_repeat_key = event.physical_keycode
				_repeat_arrow = game._pending_arrow
				_repeat_seconds = Gameplay.MOVE_REPEAT_DELAY_SECONDS
				matched = true
				break
		if not matched:
			return
	# Collect same-frame arrow presses into a single diagonal action.
	game.get_viewport().set_input_as_handled()


func _release_movement_key(key: Key) -> void:
	_held_move_keys.erase(key)
	if key != _repeat_key:
		return
	if _held_move_keys.is_empty():
		game._clear_movement_hold()
	else:
		_repeat_key = _held_move_keys.keys()[-1]
		_repeat_arrow = (_repeat_key in [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]
			and _default_arrow_bindings())
		_repeat_seconds = Gameplay.MOVE_REPEAT_DELAY_SECONDS


func _default_arrow_bindings() -> bool:
	for pair in [[&"move_north", KEY_UP], [&"move_east", KEY_RIGHT],
		[&"move_south", KEY_DOWN], [&"move_west", KEY_LEFT]]:
		var bound := false
		for event in InputMap.action_get_events(pair[0]):
			if event is InputEventKey and event.physical_keycode == pair[1]:
				bound = true
		if not bound:
			return false
	return true


func _handle_combat_input(event: InputEvent) -> void:
	game._pending_action = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tile := Vector2i((game.get_global_mouse_position() / GridView.TILE_SIZE).floor())
		game.combat_panel.select_tile(tile)
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel", false, true):
		game.combat_panel.cancel()
	elif event.is_action_pressed("ui_accept", false, true):
		game.combat_panel.confirm()
	else:
		for index in range(Gameplay.MOVE_ACTIONS.size()):
			if event.is_action_pressed(Gameplay.MOVE_ACTIONS[index], false, true):
				game.combat_panel.navigate(GridWorld.DIRECTIONS[index])
				break
	game.get_viewport().set_input_as_handled()
