extends Control

var game: Gameplay
var pad: GridContainer
var feedback: Label
var _menu: Button
var _interact: Button
var _message: String = ""
var _feedback_seconds: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad = GridContainer.new()
	pad.columns = 3
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad.position = Vector2(16, size.y - 288)
	add_child(pad)
	var adapter := game.input_adapter as MobileGameplayInput
	adapter.pad = pad
	var labels := ["↖", "↑", "↗", "←", "Wait", "→", "↙", "↓", "↘"]
	var directions: Array[Vector2i] = [Vector2i(-1, -1), Vector2i.UP, Vector2i(1, -1),
		Vector2i.LEFT, Vector2i.ZERO, Vector2i.RIGHT, Vector2i(-1, 1), Vector2i.DOWN, Vector2i(1, 1)]
	for index in range(labels.size()):
		var button := Button.new()
		button.text = labels[index]
		button.custom_minimum_size = Vector2(88, 88)
		button.add_theme_font_size_override("font_size", 30 if index != 4 else 20)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(button)
		adapter.buttons.append(button)
		adapter.directions.append(directions[index])
	_menu = _button("Menu", game.request_menu, -196)
	_interact = _button("Interact", game.request_interact, -104)
	feedback = Label.new()
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	feedback.offset_left = -360
	feedback.offset_right = 360
	feedback.offset_top = 120
	feedback.offset_bottom = 198
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 24)
	feedback.add_theme_color_override("font_shadow_color", Color.BLACK)
	feedback.add_theme_constant_override("shadow_offset_x", 2)
	feedback.add_theme_constant_override("shadow_offset_y", 2)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback)
	game.view_refreshed.connect(refresh)
	game.menu.visibility_changed.connect(refresh)
	game.hero_panel.visibility_changed.connect(refresh)
	game.combat_panel.visibility_changed.connect(refresh)
	game.session.world_changed.connect(_connect_messages)
	resized.connect(func() -> void: pad.position = Vector2(16, size.y - 288))
	refresh()


func _button(title: String, action: Callable, top: float) -> Button:
	var button := Button.new()
	add_child(button)
	button.text = title
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -114
	button.offset_right = -12
	button.offset_top = top
	button.offset_bottom = top + 88
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button


func _connect_messages() -> void:
	game.world.message_added.connect(_announce)


func _announce(message: String) -> void:
	feedback.text = message
	_feedback_seconds = 4.0


func _input(event: InputEvent) -> void:
	if game.suspended:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()
		return
	game.input_adapter.handle_input(event)


func _process(delta: float) -> void:
	# Focus release and the end of an attack animation can happen after a modal's
	# visibility signal. Reconcile availability without relying on another action.
	refresh()
	_feedback_seconds = maxf(0.0, _feedback_seconds - delta)
	feedback.visible = (_feedback_seconds > 0.0 and game.active_game
		and not game.menu.visible and not game.hero_panel.visible)
	if game.hud.feedback.text != _message:
		_message = game.hud.feedback.text
		if not _message.is_empty():
			_announce(_message.replace("Esc cancels", "Cancel stops the action"))


func refresh() -> void:
	if pad == null:
		return
	var available := game.can_move()
	var showing_game := (game.active_game and not game.world.is_terminal()
		and not game.menu.visible and not game.hero_panel.visible and not game.combat_panel.visible)
	pad.visible = showing_game and not game.suspended
	for button in (game.input_adapter as MobileGameplayInput).buttons:
		(button as Button).disabled = not available
	_menu.visible = showing_game
	_interact.visible = _menu.visible
	_interact.disabled = not available
	if not available:
		game.stop_movement()


func back() -> void:
	game.stop_movement()
	if game.suspended:
		return
	if game.hero_panel.visible:
		if game.hero_panel.choosing_slot:
			game.hero_panel.finish_assignment()
		else:
			game.hero_panel.close()
	elif game.combat_panel.visible:
		game.combat_panel.cancel()
	elif game.menu.visible:
		if game.menu._back.is_valid():
			game.menu._back.call()
		else:
			game.menu.request_exit()
	elif game.world.pending_skill != null or game.world.pending_melee != null:
		game._cancel_pending_melee()
	else:
		game.request_menu()
	refresh()
