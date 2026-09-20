class_name CombatPanel
extends Control

## Interaction selection, explicit neutral attack confirmation, and temporary death UI.
signal action_taken
signal selection_changed(actor: GridActor)
signal reset_requested

enum Mode { SELECT, CONFIRM_ATTACK, DEAD }

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
	_confirm = _button(buttons, "Choose (Enter)", confirm)
	_cancel = _button(buttons, "Cancel (Esc)", cancel)
	hide()


func open_interaction(world: GridWorld) -> void:
	close()
	_world = world
	_candidates = world.interaction_candidates()
	if _candidates.is_empty():
		world.add_message("No one is within interaction range.")
		return
	selected = _candidates[0]
	if _candidates.size() == 1:
		_choose_selected()
	else:
		mode = Mode.SELECT
		show()
		_update_selection()


func show_death() -> void:
	mode = Mode.DEAD
	selected = null
	show()
	_heading.text = "You died"
	_detail.text = ("This attempt has ended. Reset the training fixture to try again. "
		+ "The Loop arrives in milestone 4.")
	_configure_buttons(false, "Reset fixture", false)
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
			_choose_selected()
		Mode.CONFIRM_ATTACK:
			_interact_selected()
		Mode.DEAD:
			reset_requested.emit()


func cancel() -> void:
	if mode != Mode.DEAD:
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


func _choose_selected() -> void:
	if selected.alive and selected.relationship == GridActor.Relationship.NEUTRAL:
		mode = Mode.CONFIRM_ATTACK
		show()
		_heading.text = "Attack %s?" % selected.title
		_detail.text = ("This NPC is neutral. Attacking will make it hostile. "
			+ "Enter attacks; Esc cancels without spending time.")
		_configure_buttons(false, "Attack (Enter)", true)
		selection_changed.emit(selected)
	else:
		_interact_selected()


func _interact_selected() -> void:
	var message := _world.interact(selected)
	if not message.is_empty():
		_world.add_message(message)
	close()
	action_taken.emit()


func _update_selection() -> void:
	_heading.text = "%s / %s" % [selected.title, selected.relationship_name()]
	_detail.text = "Level %d   Health %d/%d. Directions select; Enter chooses; Esc cancels." % [
		selected.melee.level, selected.health if selected.alive else 0, selected.max_health,
	]
	_configure_buttons(_candidates.size() > 1, "Choose (Enter)", true)
	selection_changed.emit(selected)


func _configure_buttons(multiple: bool, confirm_text: String, cancel_visible: bool) -> void:
	# Keep adjacent world targets visible during selection and attack confirmation.
	var show_world := mode != Mode.DEAD
	_panel.position = size * 0.5 + Vector2(-224, 56 if show_world else -76)
	_panel.size = Vector2(448, 116 if show_world else 152)
	_previous.visible = multiple
	_next.visible = multiple
	_confirm.text = confirm_text
	_cancel.visible = cancel_visible


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
