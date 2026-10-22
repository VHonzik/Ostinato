class_name MobileGameplayInput
extends GameplayInput

var pad: Control
var buttons: Array[Control] = []
var directions: Array[Vector2i] = []
var pointer: int = -1
var direction := Vector2i.ZERO
var seconds: float = 0.0
var pressed_rect := Rect2()


func clear() -> void:
	pointer = -1
	direction = Vector2i.ZERO
	seconds = 0.0
	for button in buttons:
		button.modulate = Color.WHITE


func process_movement(delta: float) -> void:
	if pointer == -1:
		return
	seconds -= delta
	if seconds <= 0.0 or is_zero_approx(seconds):
		game.request_move(direction)
		seconds = Gameplay.MOVE_REPEAT_INTERVAL_SECONDS


func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_press(event.index, event.position)
		elif event.index == pointer and event.canceled:
			game.stop_movement()
		elif event.index == pointer:
			# Preserve the initial queued step of a quick tap, but stop repetition.
			clear()
	elif event is InputEventScreenDrag and event.index == pointer:
		if not pressed_rect.has_point(event.position):
			game.stop_movement()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(-2, event.position)
			elif pointer == -2:
				clear()
	elif event is InputEventMouseMotion and pointer == -2:
		if not pressed_rect.has_point(event.position):
			game.stop_movement()


func _press(index: int, position: Vector2) -> void:
	if pad.visible and game.can_move():
		for slot in range(buttons.size()):
			var rect := buttons[slot].get_global_rect()
			if rect.has_point(position):
				if pointer != -1:
					return
				direction = directions[slot]
				if game.request_move(direction) and direction != Vector2i.ZERO:
					pointer = index
					pressed_rect = rect
					seconds = Gameplay.MOVE_REPEAT_DELAY_SECONDS
					buttons[slot].modulate = Color("89b8a0")
				return
	# A second finger using another control consumes the movement hold.
	game.stop_movement()
	if game.combat_panel.visible and not game.combat_panel._panel.get_global_rect().has_point(position):
		var ui_size := Vector2(pad.get_viewport_rect().size)
		var world_position := position * Vector2(game.get_viewport_rect().size) / ui_size
		world_position = game.get_viewport().get_canvas_transform().affine_inverse() * world_position
		game.combat_panel.select_tile(Vector2i((world_position / GridView.TILE_SIZE).floor()))
