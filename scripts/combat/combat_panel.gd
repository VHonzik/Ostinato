class_name CombatPanel
extends Control

## Adjacent interaction, cancellation boundaries, and temporary milestone-3 death UI.
signal action_taken
signal selection_changed(actor: GridActor)
signal reset_requested

enum Mode { SELECT, CONVERSATION, PENDING, DEAD }

var mode: Mode = Mode.SELECT
var selected: GridActor
var _world: GridWorld
var _candidates: Array[GridActor] = []
var _panel: PanelContainer
var _heading: Label
var _detail: Label
var _confirm: Button
var _cancel: Button
var _previous: Button
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-224, -76)
	_panel.size = Vector2(448, 152)
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101d1b")
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	_heading = Label.new()
	_heading.name = "Heading"
	rows.add_child(_heading)
	_detail = Label.new()
	_detail.name = "Detail"
	# Give wrapping text its known content width before the first layout pass.
	_detail.custom_minimum_size.x = 428
	_detail.size.x = 428
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_detail)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	_previous = _button(buttons, "Previous", func() -> void: navigate(Vector2i.LEFT))
	_next = _button(buttons, "Next", func() -> void: navigate(Vector2i.RIGHT))
	_confirm = _button(buttons, "Confirm (Enter)", confirm)
	_cancel = _button(buttons, "Cancel (Esc)", cancel)
	hide()


func open_interaction(world: GridWorld) -> void:
	_world = world
	_candidates = world.interaction_candidates()
	if _candidates.is_empty():
		world.add_message("No one is within interaction range.")
		return
	mode = Mode.SELECT
	selected = _candidates[0]
	show()
	_update_selection()
	_confirm.grab_focus()


func show_pending(world: GridWorld) -> void:
	_world = world
	mode = Mode.PENDING
	selected = world.pending_melee
	show()
	_heading.text = "Waiting for your next swing"
	_detail.text = ("Target: %s. Each Continue advances one turn. "
		+ "Esc cancels; elapsed time stays spent.") % selected.title
	_configure_buttons(false, "Continue (Enter)", true)
	_confirm.grab_focus()
	selection_changed.emit(selected)


func show_death() -> void:
	mode = Mode.DEAD
	selected = null
	show()
	_heading.text = "You died"
	_detail.text = ("This attempt has ended. Reset the training fixture to try again. "
		+ "The Loop arrives in milestone 4.")
	_configure_buttons(false, "Reset fixture", false)
	_confirm.grab_focus()
	selection_changed.emit(null)


func close() -> void:
	hide()
	selected = null
	selection_changed.emit(null)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func confirm() -> void:
	match mode:
		Mode.SELECT:
			var message := _world.interact(selected)
			if not message.is_empty():
				mode = Mode.CONVERSATION
				_heading.text = "%s / %s" % [selected.title, selected.relationship_name()]
				_detail.text = message
				_configure_buttons(false, "Close (Enter)", true)
			else:
				close()
				action_taken.emit()
		Mode.PENDING:
			_world.continue_melee()
			close()
			action_taken.emit()
		Mode.CONVERSATION:
			close()
		Mode.DEAD:
			reset_requested.emit()


func cancel() -> void:
	if mode == Mode.DEAD:
		return
	if mode == Mode.PENDING:
		_world.cancel_melee()
	close()


func navigate(direction: Vector2i) -> void:
	if mode != Mode.SELECT or _candidates.size() < 2:
		return
	# Prefer the nearest candidate ahead. If none is ahead, wrap from the far edge.
	var best: GridActor
	var best_score := INF
	for candidate in _candidates:
		if candidate == selected:
			continue
		var delta := candidate.tile - selected.tile
		var forward := direction.x * delta.x + direction.y * delta.y
		var side := absi(direction.x * delta.y - direction.y * delta.x)
		var score := float(forward + side * 2) if forward > 0 else 10000.0 + forward + side
		if score < best_score:
			best = candidate
			best_score = score
	selected = best
	_update_selection()


func select_tile(tile: Vector2i) -> void:
	if mode != Mode.SELECT:
		return
	for candidate in _candidates:
		if candidate.tile == tile:
			selected = candidate
			_update_selection()
			return


func focus_next(backward: bool) -> void:
	var controls: Array[Button] = []
	for button in [_previous, _next, _confirm, _cancel]:
		if button.visible:
			controls.append(button)
	var index := controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(index + (-1 if backward else 1), controls.size())].grab_focus()


func _update_selection() -> void:
	_heading.text = "%s / %s" % [selected.title, selected.relationship_name()]
	_detail.text = "Level %d   Health %d/%d. Directions select; Enter confirms; Esc cancels." % [
		selected.melee.level, selected.health if selected.alive else 0, selected.max_health,
	]
	_configure_buttons(_candidates.size() > 1, "Confirm (Enter)", true)
	selection_changed.emit(selected)


func _configure_buttons(multiple: bool, confirm_text: String, cancel_visible: bool) -> void:
	# Keep adjacent world targets visible while selecting or waiting for a swing.
	var show_world := mode == Mode.SELECT or mode == Mode.PENDING
	_panel.position = size * 0.5 + Vector2(-224, 56 if show_world else -76)
	_panel.size = Vector2(448, 116 if show_world else 152)
	_previous.visible = multiple
	_next.visible = multiple
	_confirm.text = confirm_text
	_cancel.visible = cancel_visible


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
