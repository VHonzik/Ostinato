extends HeroPanel

var _use: Button


func _ready() -> void:
	select_before_use = true
	super._ready()
	_use = Button.new()
	_use.text = "Use"
	_use.custom_minimum_size.y = 48
	_use.pressed.connect(func() -> void:
		var identifier: StringName = _last_spell_by_class.get(_last_class_tab, &"")
		var skill := _hero.find_skill(identifier)
		if skill != null and skill.effect != SkillDefinition.Effect.PASSIVE:
			cast_requested.emit(identifier))
	_assign.get_parent().add_child(_use)
	_close.text = "Close"
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(16, 16)
	_panel.size = Vector2(maxf(960, size.x - 32), maxf(400, size.y - 224))
	for button in [_assign, _clear, _lock, _close]:
		button.custom_minimum_size.y = 48


func refresh() -> void:
	super.refresh()
	if _hero == null:
		return
	if choosing_slot:
		_details.text = "Tap a hotbar slot to assign. Back cancels."
	elif _tabs.current_tab == 0:
		_details.text = "Select a class tab to inspect learned abilities."
	if _use != null:
		var selected: StringName = _last_spell_by_class.get(_last_class_tab, &"")
		var skill := _hero.find_skill(selected)
		_use.disabled = (choosing_slot or _tabs.current_tab == 0 or skill == null
			or skill.effect == SkillDefinition.Effect.PASSIVE)
	for button in _skill_buttons:
		button.custom_minimum_size.y = 48
		(button as SkillButton).drag_enabled = false


func _rebuild_skills() -> void:
	super._rebuild_skills()
	for button in _skill_buttons:
		button.custom_minimum_size.y = 48
