extends HotbarPanel


func _ready() -> void:
	super._ready()
	anchor_left = 0.0
	anchor_right = 1.0
	offset_left = 304
	offset_right = -126
	offset_top = -196
	offset_bottom = -16
	for button in slots:
		button.custom_minimum_size = Vector2(48, 88)
		button.add_theme_font_size_override("font_size", 18)
	lock_button.size = Vector2(112, 48)
	lock_button.add_theme_font_size_override("font_size", 20)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	for row in [slots[0].get_parent(), slots[10].get_parent()]:
		row.position.y = 92 if row == slots[0].get_parent() else 0
		row.size = Vector2(size.x, 88)
	lock_button.position = Vector2(size.x - 112, -52)


func refresh(world: GridWorld, options: GlobalOptions, can_activate: bool,
	can_edit: bool, choosing_slot: bool) -> void:
	super.refresh(world, options, can_activate, can_edit, choosing_slot)
	for index in range(slots.size()):
		var label := slots[index].text
		var newline := label.find("\n")
		if newline >= 0:
			slots[index].text = str(index + 1) + label.substr(newline)
		# Touch inspection belongs to the spell book, without delayed hover popups.
		slots[index].tooltip_text = ""
