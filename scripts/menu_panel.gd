class_name MenuPanel
extends Control

## Shared keyboard/mouse menus. No menu operation advances simulation.
signal new_game_requested
signal return_to_menu_requested
signal refreshed
signal fullscreen_changed

var session: GameSession
var saves := SaveStore.new()
var options := GlobalOptions.new()
var page: String = ""
var active_game: bool = false
var _rows: VBoxContainer
var _panel: PanelContainer
var _buttons: Array[Button] = []
var _footer: HBoxContainer
var _back: Callable
var _capture_action: StringName = &""
var _trainer: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-250, -132)
	_panel.size = Vector2(500, 264)
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101d1b")
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_footer = HBoxContainer.new()
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -24
	_footer.offset_left = 8
	_footer.offset_right = -8
	add_child(_footer)
	var copyright := Label.new()
	copyright.text = "Copyright Postperson studio, 2026"
	copyright.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(copyright)
	var version := Label.new()
	version.text = "0.1." + BuildVersion.short_commit()
	_footer.add_child(version)
	hide()


func open_main() -> void:
	active_game = false
	_begin("main", "OSTINATO", Callable())
	_button("New Game", _new_game)
	_button("Load", open_slots)
	_button("Options", open_options)
	_button("Exit", _exit)
	_finish()


func open_options() -> void:
	_begin("options", "Options", close if active_game else open_main)
	_button("Save / Load" if active_game else "Load", open_slots)
	_button("Keybindings", open_bindings)
	_button("Fullscreen: %s" % ("On" if options.fullscreen else "Off"), toggle_fullscreen)
	_button("Relationship palette: %s" % (
		"Blue / yellow / vermilion" if options.alternate_palette else "Green / yellow / red"),
		_toggle_palette)
	if active_game:
		_button("Main Menu", func() -> void:
			_discard("Return to Main Menu?", func() -> void:
				return_to_menu_requested.emit()
				open_main()))
	_button("Back (Esc)", _back)
	_finish()


func open_slots() -> void:
	_begin("slots", "Five save slots", open_options if active_game else open_main)
	if active_game and not session.world.can_save():
		_label("Saving unavailable during combat or a pending action. Loading is available.")
	for slot in range(1, SaveStore.SLOT_COUNT + 1):
		var metadata := saves.metadata(slot)
		var detail: String = metadata.status
		if metadata.status == "Occupied":
			detail = "%s / Loop %d" % [metadata.timestamp, metadata.loop]
		elif metadata.has("file"):
			detail += " / " + metadata.file
		_label("Slot %d: %s" % [slot, detail])
		var row := HBoxContainer.new()
		_rows.add_child(row)
		if active_game:
			var save := _button("Save %d" % slot, _request_save.bind(slot), row)
			save.disabled = not session.world.can_save()
		var load_button := _button("Load %d" % slot, _request_load.bind(slot), row)
		load_button.disabled = metadata.status == "Empty" or (
			metadata.status == "Damaged" and metadata.has("file"))
	_button("Back (Esc)", _back)
	_finish()


func open_bindings() -> void:
	_capture_action = &""
	_begin("bindings", "Keybindings", open_options)
	_label("Choose an action, then press its new key. Enter/Tab stay reserved.")
	for action in GlobalOptions.ACTIONS:
		_button("%s: %s" % [String(action).replace("_", " "), options.key_label(action)],
			_capture.bind(action))
	_button("Back (Esc)", open_options)
	_finish()


func open_marshal() -> void:
	_begin("marshal", "Marshal McBride", close)
	_label("The Legion has reached Northshire. Do I know you? These clothes may help.")
	if session.can_select_class():
		for category: StringName in [&"Mage", &"Druid"]:
			if category == session.world.hero.selected_class:
				continue
			_button("Choose " + String(category), _select_class.bind(category))
	else:
		_label("Class selection: once per Loop from Loop 2, at level 1, before accepting any quest.")
	_button("Leave (Esc)", close)
	_finish()


func open_trainer(category: StringName) -> void:
	_trainer = category
	_begin("trainer", "%s training" % category, close)
	if session.world.hero.selected_class != category:
		_label("Select %s before learning here. Retained skills remain usable." % category)
	else:
		for skill in SkillRank.trainer_skills(category):
			var known := session.world.hero.find_skill(skill.id) != null
			var button := _button("%s rank %d / %s" % [
				skill.title, skill.rank, "Learned" if known else "Free"],
				_train.bind(skill.id))
			button.tooltip_text = skill.description
			button.disabled = known or session.world.hero.level < skill.training_level
	_button("Leave (Esc)", close)
	_finish()


func open_inventory() -> void:
	_begin("inventory", "Starter equipment / Inventory", close)
	var hero := session.world.hero
	_label("%s / %d copper / 40 inventory slots" % [hero.selected_class, hero.copper])
	for slot in hero.equipment:
		var item: Dictionary = hero.equipment[slot]
		_label("%s: %s" % [slot, StarterGear.ITEMS[int(item.id)].title])
	for index in range(hero.inventory.size()):
		var item: Dictionary = hero.inventory[index]
		if not item.is_empty():
			_label("Slot %d: %s" % [index + 1, StarterGear.ITEMS[int(item.id)].title])
	_button("Close (Esc)", close)
	_finish()


func close() -> void:
	hide()
	_capture_action = &""
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func handle_key(event: InputEventKey) -> void:
	if _capture_action != &"":
		if event.physical_keycode == KEY_ESCAPE:
			open_bindings()
			return
		var action := _capture_action
		_capture_action = &""
		var key := int(event.physical_keycode)
		var other := options.conflict(action, key)
		if other != &"":
			confirm("Swap %s with %s?" % [action, other], func() -> void:
				if options.rebind(action, key, true):
					open_bindings()
				else:
					notice(options.last_error, open_bindings), open_bindings)
		elif options.rebind(action, key):
			open_bindings()
		else:
			notice(options.last_error, open_bindings)
		return
	if event.is_action_pressed("ui_cancel"):
		if _back.is_valid():
			_back.call()
		return
	if event.is_action_pressed("ui_accept"):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Button and _buttons.has(focus) and not focus.disabled:
			focus.pressed.emit()
		return
	var backward := event.is_action_pressed("move_north") or event.is_action_pressed("move_west")
	if (backward or event.is_action_pressed("move_south") or event.is_action_pressed("move_east")
		or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev")):
		var step := -1 if backward or event.shift_pressed else 1
		var index := _buttons.find(get_viewport().gui_get_focus_owner())
		for attempt in range(_buttons.size()):
			index = posmod(index + step, _buttons.size())
			if not _buttons[index].disabled:
				_buttons[index].grab_focus()
				return


func confirm(text: String, action: Callable, cancel_action: Callable) -> void:
	_begin("confirm", text, cancel_action)
	_button("Confirm", action)
	_button("Cancel (Esc)", cancel_action)
	_finish()


func notice(text: String, back: Callable) -> void:
	_begin("notice", "Ostinato", back)
	_label(text)
	_button("OK", back)
	_finish()


func toggle_fullscreen() -> void:
	options.fullscreen = not options.fullscreen
	var saved := options.save_options()
	fullscreen_changed.emit()
	if not saved:
		notice(options.last_error, open_options)
	elif page == "options":
		open_options()


func _begin(next_page: String, title: String, back: Callable) -> void:
	page = next_page
	_panel.position = size * 0.5 + Vector2(-250, -86 if active_game else -100)
	_panel.size = Vector2(500, 248 if active_game else 200)
	_back = back
	_buttons.clear()
	(_rows.get_parent() as ScrollContainer).scroll_vertical = 0
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_label(title)
	(_rows.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.visible = page == "main"
	show()


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 460
	_rows.add_child(label)


func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	# Defer until container layout settles, including a wrap from first to last.
	button.focus_entered.connect(func() -> void:
		(_rows.get_parent() as ScrollContainer).ensure_control_visible.call_deferred(button))
	(parent if parent != null else _rows).add_child(button)
	_buttons.append(button)
	return button


func _finish() -> void:
	for button in _buttons:
		if not button.disabled:
			button.grab_focus()
			break


func _new_game() -> void:
	_discard("Start a new game?", func() -> void:
		new_game_requested.emit()
		active_game = true
		close())


func _exit() -> void:
	_discard("Exit without saving?", func() -> void: get_tree().quit())


func request_exit() -> void:
	_exit()


func _discard(text: String, action: Callable) -> void:
	if active_game and session.has_unsaved_changes():
		confirm(text + " Unsaved changes will be discarded.", action, open_options)
	else:
		action.call()


func _request_save(slot: int) -> void:
	if saves.metadata(slot).status != "Empty":
		confirm("Overwrite slot %d?" % slot, _save.bind(slot, true), open_slots)
	else:
		_save(slot, false)


func _save(slot: int, confirmed: bool) -> void:
	if saves.save_slot(session, slot, confirmed):
		session.mark_saved()
		notice("Saved to slot %d." % slot, open_slots)
	else:
		notice(saves.last_error, open_slots)


func _request_load(slot: int) -> void:
	_discard("Load slot %d?" % slot, func() -> void:
		if saves.load_slot(session, slot):
			session.mark_saved()
			active_game = true
			close()
			refreshed.emit()
		else:
			notice(saves.last_error, open_slots))


func _capture(action: StringName) -> void:
	_capture_action = action
	_begin("capture", "Press a key for %s (Esc cancels)." % action, open_bindings)


func _select_class(category: StringName) -> void:
	if session.select_class(category):
		refreshed.emit()
		close()
	else:
		notice("Cannot exchange clothes; make inventory space and try again.", open_marshal)


func _train(identifier: StringName) -> void:
	session.world.train(_trainer, identifier)
	refreshed.emit()
	open_trainer(_trainer)


func _toggle_palette() -> void:
	options.alternate_palette = not options.alternate_palette
	var saved := options.save_options()
	refreshed.emit()
	if saved:
		open_options()
	else:
		notice(options.last_error, open_options)
