class_name HeroPanel
extends Control

## Keyboard/mouse character and learned-rank view; no simulation runs in this panel.
signal cast_requested(identifier: StringName)

var _hero: HeroState
var _tabs: TabContainer
var _stats: Label
var _close: Button
var _panel: PanelContainer
var _skill_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-252, -91)
	_panel.size = Vector2(504, 182)
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
	_tabs.tab_changed.connect(_on_tab_changed)
	hide()


func open(hero: HeroState, spell_book: bool) -> void:
	_hero = hero
	_rebuild_skills()
	refresh()
	show()
	_tabs.current_tab = 1 if spell_book else 0
	_focus_tab_content()


func close() -> void:
	hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func refresh() -> void:
	if _hero == null:
		return
	_stats.text = (
		"Mage  /  Level %d     XP %d / %d\n"
		+ "Health %d / %d     Mana %d / %d\n"
		+ "Strength %d     Agility %d     Stamina %d\n"
		+ "Intellect %d     Spirit %d\n"
		+ "Melee AP %d   Armor %d   Crit %.2f%%   Dodge %.2f%%"
	) % [
		_hero.level, _hero.experience, _hero.experience_to_next_level(),
		_hero.health, _hero.max_health, _hero.mana, _hero.max_mana,
		_hero.strength, _hero.agility, _hero.stamina, _hero.intellect, _hero.spirit,
		_hero.melee.attack_power, _hero.melee.armor, _hero.melee.critical, _hero.melee.dodge,
	]


func navigate(forward: bool) -> void:
	# Explicit focus ring keeps Tab and movement keys inside the modal panel.
	var controls: Array[Control] = [_close, _tabs.get_tab_bar()]
	for button in _skill_buttons:
		if button.is_visible_in_tree():
			controls.append(button)
	var index := controls.find(get_viewport().gui_get_focus_owner())
	index = posmod(index + (1 if forward else -1), controls.size())
	controls[index].grab_focus()


func change_tab(direction: int) -> void:
	_tabs.current_tab = posmod(_tabs.current_tab + direction, _tabs.get_tab_count())


func _rebuild_skills() -> void:
	_skill_buttons.clear()
	while _tabs.get_tab_count() > 1:
		var child := _tabs.get_child(1)
		_tabs.remove_child(child)
		child.queue_free()
	var categories: Dictionary[StringName, VBoxContainer] = {}
	for skill in _hero.learned_skills:
		if not categories.has(skill.class_tab):
			var scroll := ScrollContainer.new()
			scroll.name = skill.class_tab
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_tabs.add_child(scroll)
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(rows)
			categories[skill.class_tab] = rows
		var button := Button.new()
		button.text = "%s  ·  Rank %d" % [skill.title, skill.rank]
		if skill.effect == SkillRank.Effect.PREVIEW:
			button.text += "  (preview)"
		else:
			button.text += "  ·  1 turn / 0 mana"
		button.tooltip_text = skill.description
		button.pressed.connect(_request_cast.bind(skill.id))
		categories[skill.class_tab].add_child(button)
		_skill_buttons.append(button)


func _request_cast(identifier: StringName) -> void:
	cast_requested.emit(identifier)
	refresh()


func _on_tab_changed(_tab: int) -> void:
	if visible:
		_focus_tab_content()


func _focus_tab_content() -> void:
	for button in _skill_buttons:
		if button.is_visible_in_tree():
			button.grab_focus()
			return
	_tabs.get_tab_bar().grab_focus()
