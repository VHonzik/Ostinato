class_name CombatPanel
extends Control

## Interaction and spell targeting with explicit confirmation.
signal action_taken
signal selection_changed(actor: GridActor)
signal service_requested(service: StringName)

enum Mode { SELECT, CONFIRM_ATTACK, SPELL }

var mode: Mode = Mode.SELECT
var selected: GridActor
var _skill: SkillRank
var _self_target: GridActor
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
		Mode.SPELL:
			_world.cast_skill(_skill.id, null if selected == _self_target else selected)
			close()
			action_taken.emit()


func cancel() -> void:
	close()


func navigate(direction: Vector2i) -> void:
	if mode not in [Mode.SELECT, Mode.SPELL] or _candidates.size() < 2:
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
	if mode not in [Mode.SELECT, Mode.SPELL]:
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
	if selected.alive and selected.service != &"":
		var service := selected.service
		close()
		service_requested.emit(service)
		return
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
	_configure_buttons(_candidates.size() > 1,
		"Cast (Enter)" if mode == Mode.SPELL else "Choose (Enter)", true)
	selection_changed.emit(selected)


func _configure_buttons(multiple: bool, confirm_text: String, cancel_visible: bool) -> void:
	# Keep adjacent world targets visible during selection and attack confirmation.
	_panel.position = size * 0.5 + Vector2(-224, 56)
	_panel.size = Vector2(448, 116)
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


func open_spell(world: GridWorld, skill: SkillRank) -> void:
	close()
	_world = world
	_skill = skill
	_candidates = world.spell_candidates(skill)
	_self_target = null
	if skill.target == SkillRank.Target.ALLY and world.valid_spell_target(skill, null):
		_self_target = GridActor.new(world.player_tile)
		_self_target.title = "You"
		_self_target.health = world.hero.health
		_self_target.max_health = world.hero.max_health
		_self_target.melee.level = world.hero.level
		_candidates.push_front(_self_target)
	if _candidates.is_empty():
		world.add_message("No valid target for " + skill.title + ".")
		return
	selected = _candidates[0]
	mode = Mode.SPELL
	show()
	_update_selection()
