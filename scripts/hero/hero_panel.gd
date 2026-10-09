class_name HeroPanel
extends Control

## Keyboard/mouse character and learned-rank view; no simulation runs in this panel.
signal cast_requested(identifier: StringName)
signal assignment_changed
signal slot_chosen(slot: int)
signal lock_requested

var choosing_slot: bool = false
var assignment_id: StringName = &""
var layout_locked: bool = false

var _hero: HeroState
var _tabs: TabContainer
var _stats: Label
var _close: Button
var _panel: PanelContainer
var _skill_buttons: Array[Button] = []
var _last_spell_by_class: Dictionary = {}
var _last_class_tab: StringName = &"Mage"
var _rebuilding: bool = false
var _assign: Button
var _clear: Button
var _lock: Button
var _details: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-300, -90)
	_panel.size = Vector2(600, 216)
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.09, 0.085, 1)
	style.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	var title := Label.new()
	title.text = "Character / Spell book"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_assign = Button.new()
	_assign.text = "Assign"
	_assign.pressed.connect(begin_assignment)
	heading.add_child(_assign)
	_clear = Button.new()
	_clear.text = "Clear slot"
	_clear.pressed.connect(begin_assignment.bind(true))
	heading.add_child(_clear)
	_lock = Button.new()
	_lock.text = "Lock"
	_lock.pressed.connect(func() -> void: lock_requested.emit())
	heading.add_child(_lock)
	_close = Button.new()
	_close.text = "Close (Esc)"
	_close.pressed.connect(close)
	heading.add_child(_close)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_tabs)
	var character := MarginContainer.new()
	character.name = "Character"
	_tabs.add_child(character)
	_stats = Label.new()
	character.add_child(_stats)
	_details = RichTextLabel.new()
	_details.custom_minimum_size.y = 44
	_details.focus_mode = Control.FOCUS_ALL
	rows.add_child(_details)
	_tabs.tab_changed.connect(_on_tab_changed)
	hide()


func open(hero: HeroState, spell_book: bool) -> void:
	_hero = hero
	_rebuild_skills()
	refresh()
	show()
	var selected_tab := 0
	if spell_book:
		selected_tab = 1
		for index in range(1, _tabs.get_tab_count()):
			if _tabs.get_tab_title(index) == String(_last_class_tab):
				selected_tab = index
				break
	_tabs.current_tab = selected_tab
	_focus_tab_content()


func close() -> void:
	choosing_slot = false
	hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func clear_selection() -> void:
	_last_spell_by_class.clear()
	_last_class_tab = &"Mage"


func refresh() -> void:
	if _hero == null:
		return
	_assign.disabled = layout_locked or _tabs.current_tab == 0
	_clear.disabled = layout_locked
	_lock.text = "Unlock" if layout_locked else "Lock"
	if choosing_slot:
		_details.text = "Choose slot: top-row 1–5 or click a slot. Esc cancels."
	elif _tabs.current_tab > 0:
		var identifier: StringName = _last_spell_by_class.get(_last_class_tab, &"")
		var skill := _hero.find_skill(identifier)
		if skill != null:
			_details.text = "%s · Rank %d · %d mana\n%s" % [
				skill.title, skill.rank, skill.cost(_hero), skill.description]
	else:
		_details.text = "A/D: tabs · W/S: skills · Tab: controls · Enter: activate · Esc: close"
	for button in _skill_buttons:
		(button as SkillButton).describe(_hero.find_skill(button.get_meta("skill_id")), _hero)
		(button as SkillButton).drag_enabled = not layout_locked
	_stats.text = (
		"%s  /  Level %d     XP %d / %d\n"
		+ "Health %d / %d     Mana %d / %d\n"
		+ "Strength %d     Agility %d     Stamina %d\n"
		+ "Intellect %d     Spirit %d\n"
		+ "Melee AP %d   Armor %d   Crit %.2f%%   Dodge %.2f%%"
	) % [
		_hero.selected_class, _hero.level, _hero.experience, _hero.experience_to_next_level(),
		_hero.health, _hero.max_health, _hero.mana, _hero.max_mana,
		_hero.strength, _hero.agility, _hero.stamina, _hero.intellect, _hero.spirit,
		_hero.melee.attack_power, _hero.melee.armor, _hero.melee.critical, _hero.melee.dodge,
	]


func navigate(forward: bool, include_actions: bool = false) -> void:
	# W/S selects ranks; Tab leaves the selected rank for Assign without changing it.
	var focused := get_viewport().gui_get_focus_owner()
	if not include_actions and focused == _details:
		_details.get_v_scroll_bar().value += 24 if forward else -24
		return
	var controls: Array[Control] = [_close, _tabs.get_tab_bar()]
	var selected: StringName = _last_spell_by_class.get(_last_class_tab, &"")
	for button in _skill_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			if not include_actions or button.get_meta("skill_id") == selected:
				controls.append(button)
	if include_actions:
		for button in [_assign, _clear, _lock]:
			if not button.disabled:
				controls.append(button)
		controls.append(_details)
	var index := controls.find(get_viewport().gui_get_focus_owner())
	index = posmod(index + (1 if forward else -1), controls.size())
	controls[index].grab_focus()


func change_tab(direction: int) -> void:
	_tabs.current_tab = posmod(_tabs.current_tab + direction, _tabs.get_tab_count())


func _rebuild_skills() -> void:
	_rebuilding = true
	_skill_buttons.clear()
	while _tabs.get_tab_count() > 1:
		var child := _tabs.get_child(1)
		_tabs.remove_child(child)
		child.queue_free()
	var categories: Dictionary[StringName, VBoxContainer] = {}
	var skills := _hero.learned_skills.duplicate()
	if _hero.find_skill(&"pet_attack") != null:
		for identifier: StringName in [&"pet_attack", &"pet_follow", &"pet_dismiss"]:
			skills.append(ClassSkillData.pet_command(identifier))
	for skill in skills:
		if not categories.has(skill.class_tab):
			var scroll := ScrollContainer.new()
			scroll.name = skill.class_tab
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_tabs.add_child(scroll)
			scroll.follow_focus = true
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(rows)
			categories[skill.class_tab] = rows
		var button := SkillButton.new()
		button.text = "%s  ·  Rank %d" % [skill.title, skill.rank]
		button.text += "  ·  %s / %d mana" % ["Free" if skill.free_instant or skill.effect == SkillRank.Effect.PET_COMMAND else "%.1fs" % skill.cast_seconds, skill.cost(_hero)]
		if skill.effect == SkillRank.Effect.PASSIVE:
			button.text = skill.title + " · Passive (learned)"
			button.disabled = true
		button.describe(skill, _hero)
		button.drag_enabled = not layout_locked
		button.clip_text = true
		button.set_meta("skill_id", skill.id)
		button.pressed.connect(_request_cast.bind(skill.id))
		button.focus_entered.connect(_remember_spell.bind(skill.class_tab, skill.id))
		categories[skill.class_tab].add_child(button)
		_skill_buttons.append(button)
	_rebuilding = false


func _request_cast(identifier: StringName) -> void:
	if choosing_slot:
		return
	var skill := _hero.find_skill(identifier)
	if skill != null:
		_remember_spell(skill.class_tab, identifier)
	cast_requested.emit(identifier)
	refresh()


func _remember_spell(category: StringName, identifier: StringName) -> void:
	_last_spell_by_class[category] = identifier
	_last_class_tab = category
	refresh()


func _on_tab_changed(_tab: int) -> void:
	choosing_slot = false
	if visible and not _rebuilding:
		_focus_tab_content()
	refresh()


func _focus_tab_content() -> void:
	if _tabs.current_tab > 0:
		var category := StringName(_tabs.get_tab_title(_tabs.current_tab))
		var remembered: StringName = _last_spell_by_class.get(category, &"")
		for button in _skill_buttons:
			if button.is_visible_in_tree() and not button.disabled and button.get_meta("skill_id") == remembered:
				button.grab_focus()
				return
	for button in _skill_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return
	_tabs.get_tab_bar().grab_focus()


func begin_assignment(clear_slot: bool = false) -> void:
	if layout_locked:
		return
	assignment_id = &"" if clear_slot else _last_spell_by_class.get(_last_class_tab, &"")
	if not clear_slot:
		var skill := _hero.find_skill(assignment_id)
		if skill == null or skill.effect == SkillRank.Effect.PASSIVE:
			return
	choosing_slot = true
	refresh()
	assignment_changed.emit()


func handle_assignment_key(event: InputEventKey) -> bool:
	if not choosing_slot:
		return false
	if event.is_action_pressed("ui_cancel"):
		finish_assignment()
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
		slot_chosen.emit(event.physical_keycode - KEY_1)
	# The slot chooser owns all keys, including rebound gameplay actions.
	return true


func finish_assignment() -> void:
	choosing_slot = false
	_focus_tab_content()
	refresh()
	assignment_changed.emit()
