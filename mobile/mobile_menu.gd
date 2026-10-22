extends MenuPanel

var recovery: MobileRecoveryStore
signal item_assignment_requested(identifier: StringName)


func open_main() -> void:
	active_game = false
	_begin("main", "Ostinato (Demo)", Callable())
	var saved := recovery.metadata(session)
	if saved.status == "Occupied":
		_button("Continue — Loop %d, turn %d" % [saved.loop, saved.turn], _continue)
		_label("Continue restores the last safe save outside combat. Unsaved combat progress may be lost.")
	elif saved.status != "Empty":
		_label("Recovery save is %s. The file has been preserved." % String(saved.status).to_lower())
	_button("New Game", open_world_seeds)
	_button("Load", open_slots)
	_button("Options", open_options)
	_button("Exit", _exit)
	_finish()


func _continue() -> void:
	if recovery.restore(session):
		active_game = true
		close()
		refreshed.emit()
	else:
		notice(recovery.last_error, open_main)


func _new_game(chosen_seed: int) -> void:
	if not active_game and FileAccess.file_exists(recovery.path()):
		confirm("Start a new game and replace recovery? Manual save slots are kept.", func() -> void:
			new_game_requested.emit(chosen_seed)
			active_game = true
			close(), open_world_seeds)
	else:
		super._new_game(chosen_seed)


func open_player() -> void:
	_begin("player", "Player menu", close)
	_label("World: " + session.seed_name())
	_button("Character", _open_hero.bind(false))
	_button("Spells", _open_hero.bind(true))
	_button("Bags", open_inventory)
	_button("Quests", open_quest_log)
	_button("Log", open_log)
	_button("Options / Save / Load", open_options)
	_button("Return to game", close)
	_finish()


func open_log() -> void:
	_begin("log", "Recent messages", open_player)
	for message in session.world.messages:
		_label(message)
	_button("Back", open_player)
	_finish()


func open_options() -> void:
	if _completed():
		open_completion()
		return
	_begin("options", "Options", close if active_game else open_main)
	_button("Save / Load" if active_game else "Load", open_slots)
	_button("Relationship palette: %s" % (
		"Blue / yellow / vermilion" if options.alternate_palette else "Green / yellow / red"), _toggle_palette)
	if active_game:
		_button("Main Menu", func() -> void:
			_discard("Return to Main Menu?", func() -> void:
				return_to_menu_requested.emit()
				open_main()))
	_button("Back", _back)
	_finish()


func _begin(next_page: String, title: String, back: Callable) -> void:
	super._begin(next_page, title, back)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(24, 24)
	_panel.size = size - Vector2(48, 48)
	_rows.get_parent().get_parent().custom_minimum_size.x = 960
	_preview.custom_minimum_size.x = 920
	_preview.size.x = 920
	_preview.scroll_active = true
	_preview.fit_content = false
	_preview.custom_minimum_size.y = 136


func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var title := text.replace(" (Esc)", "").replace(" (Enter)", "")
	var button := super._button(title, action, parent)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 24)
	return button


func _label(text: String) -> Label:
	var label := super._label(text)
	label.custom_minimum_size.x = 920
	label.add_theme_font_size_override("font_size", 24)
	return label


func activate_button(button: Button, action: Callable) -> void:
	if page == "trainer" and button.has_meta("skill_id"):
		confirm(button.text + "\n" + String(button.get_meta("preview", "")),
			action, open_trainer.bind(_trainer))
	else:
		action.call()


func _assign_active_item(index: int) -> void:
	var item_id := int(session.world.hero.inventory[index].id)
	close()
	item_assignment_requested.emit(ItemData.hotbar_id(item_id))
