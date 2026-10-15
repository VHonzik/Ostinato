class_name MenuPanel
extends Control

## Shared keyboard/mouse menus; only committed equipment/use actions advance simulation.
signal new_game_requested
signal return_to_menu_requested
signal refreshed
signal fullscreen_changed
signal hero_requested(spell_book: bool)

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
var _loot_source: GridActor
var _merchant: GridActor
var _quantity: int = 1
var _preview_panel: PanelContainer
var _preview: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-360, -240)
	_panel.size = Vector2(720, 480)
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101d1b")
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	_panel.add_child(content)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_preview_panel = PanelContainer.new()
	_preview_panel.custom_minimum_size.x = 680
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color("182a26")
	preview_style.border_width_top = 1
	preview_style.border_color = Color("50665f")
	preview_style.set_content_margin_all(6)
	_preview_panel.add_theme_stylebox_override("panel", preview_style)
	content.add_child(_preview_panel)
	_preview = Label.new()
	_preview.custom_minimum_size.y = 46
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.max_lines_visible = 2
	_preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_preview.clip_text = true
	_preview_panel.add_child(_preview)
	_preview_panel.hide()
	_footer = HBoxContainer.new()
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -32
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


func open_completion() -> void:
	active_game = false
	_begin("completion", "Beyond the valley", Callable())
	_label("The last stalker falls. You leave Northshire behind and escape into the world beyond.")
	_button("Load", open_slots)
	_button("Main Menu", func() -> void:
		return_to_menu_requested.emit()
		open_main())
	_finish()


func _completed() -> bool:
	return session.world != null and session.world.attempt_state == GridWorld.AttemptState.COMPLETED


func open_player() -> void:
	_begin("player", "Player menu", close)
	_button("Character (" + options.key_label(&"character") + ")", _open_hero.bind(false))
	_button("Spell book (" + options.key_label(&"spell_book") + ")", _open_hero.bind(true))
	_button("Inventory (" + options.key_label(&"inventory") + ")", open_inventory)
	_button("Quest log (" + options.key_label(&"quest_log") + ")", open_quest_log)
	_button("Options / Save / Load", open_options)
	_label("Move: WASD + QEZC / arrows / numpad. Wait: period / numpad 5. F interacts.")
	_button("Return to game (Esc)", close)
	_finish()


func _open_hero(spell_book: bool) -> void:
	close()
	hero_requested.emit(spell_book)


func open_options() -> void:
	if _completed():
		open_completion()
		return
	_begin("options", "Options", close if active_game else open_main)
	_button("Save / Load" if active_game else "Load", open_slots)
	if active_game:
		_button("Quest log (" + options.key_label(&"quest_log") + ")", open_quest_log)
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
	var back := open_completion if _completed() else (open_options if active_game else open_main)
	_begin("slots", "Five save slots", back)
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
	session.world.trainer_referral_received = true
	_begin("marshal", "Marshal McBride", close)
	_label("Speak with Llane Beshere inside the abbey. " +
		"Also check with Janos inside, he might give you some arms and armor.")
	_button("Leave (Esc)", close)
	_finish()


func _confirm_class(category: StringName, marshal: GridActor) -> void:
	confirm("Advance %s for Loop %d? This locks your choice until death. Visit its trainer to learn starter skills." % [category, session.loop_count],
		_select_class.bind(category, marshal), open_conversation.bind(marshal))


func _request_spare_gear(actor: GridActor) -> void:
	if not QuestRules.in_range(session.world, actor, 900003):
		close()
		return
	if session.world.starter_gear_received:
		open_conversation(actor)
		return
	if not session.world.receive_starter_gear(actor):
		notice("Cannot exchange gear; make inventory space and try again.",
			open_conversation.bind(actor))
		return
	_begin("spare_gear", actor.title, open_conversation.bind(actor))
	_label("I can find some left overs if you are not picky.")
	_button("Back (Esc)", open_conversation.bind(actor))
	_finish()
	refreshed.emit()


func open_trainer(category: StringName) -> void:
	_trainer = category
	_begin("trainer", "%s training" % category, close)
	if category not in ClassSkillData.PLAYABLE_CLASSES:
		_label("Training for this class is not available yet.")
	elif session.world.hero.selected_class != category:
		_label("Select %s before learning here. Retained skills remain usable." % category)
	else:
		_label("%s class XP: %d (cumulative; learning does not spend XP)" % [
			category, session.world.hero.progression_points(category)])
		if category != &"Warrior":
			_label("Learn these starter skills for free, with no class XP requirement. Further abilities unlock with class XP.")
		for skill in SkillRank.trainer_skills(category):
			var known := session.world.hero.find_skill(skill.id) != null
			var price := "Free"
			var status := "Learned" if known else ("Unlock at %d class XP" % skill.progress_required
				if skill.progress_required > 0 else price)
			var button := _button("%s rank %d / %s" % [skill.title, skill.rank, status],
				_train.bind(skill.id))
			var failure := session.world.training_failure(category, skill)
			button.text += " / Lv %d" % skill.training_level
			button.set_meta("preview", skill.description + " " + failure)
			# Locked skills stay focusable so keyboard players can inspect them.
			if failure != "" and not known:
				for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
					button.add_theme_color_override(state, Color("ff7777"))
	_button("Leave (Esc)", close)
	_finish()


func open_inventory() -> void:
	_begin("inventory", "Items", close)
	_button("Equipment", open_equipment)
	_button("Bags", open_bags)
	_button("Close (Esc)", close)
	_finish()


func open_equipment() -> void:
	_begin("equipment_list", "Equipment", open_inventory)
	var hero := session.world.hero
	_label("%s / %s / 40 slots" % [hero.selected_class, InventoryRules.money(hero.copper)])
	for slot in InventoryRules.SLOTS:
		var item: Dictionary = hero.equipment.get(slot, {})
		var title := "Empty" if item.is_empty() else String(ItemData.get_item(int(item.id)).title)
		var button := _button("%s: %s" % [ItemData.slot_name(slot), title],
			_equipped_detail.bind(slot))
		if not item.is_empty():
			_item_color(button, int(item.id))
	_button("Bags", open_bags)
	_button("Back (Esc)", open_inventory)
	_finish()


func open_bags() -> void:
	_begin("bags", "Bags / " + InventoryRules.money(session.world.hero.copper), open_inventory)
	var hero := session.world.hero
	for index in range(40):
		var item := hero.inventory[index]
		var title := "Empty" if item.is_empty() else "%s x%d" % [
			ItemData.get_item(int(item.id)).title, item.quantity]
		var button := _button("Slot %d: %s" % [index + 1, title], _item_detail.bind(index))
		button.disabled = item.is_empty()
		if not item.is_empty():
			_item_color(button, int(item.id))
	_button("Equipment", open_equipment)
	_button("Back (Esc)", open_inventory)
	_finish()


func _equipped_detail(slot: String) -> void:
	var hero := session.world.hero
	var item: Dictionary = hero.equipment.get(slot, {})
	_begin("equipment", ItemData.slot_name(slot), open_equipment)
	if item.is_empty():
		_label("Nothing equipped.")
	else:
		_item_color(_label(ItemData.describe(int(item.id))), int(item.id))
		_button("Unequip (1 turn)", _transaction.bind(session.world.unequip_item.bind(slot),
			_equipped_detail.bind(slot)))
	_label("Equip from bags:")
	var eligible := false
	for index in range(hero.inventory.size()):
		var candidate := hero.inventory[index]
		if candidate.is_empty():
			continue
		var data := ItemData.get_item(int(candidate.id))
		if not InventoryRules.fits_slot(data, slot):
			continue
		eligible = true
		var button := _button(data.title + " (1 turn)", _transaction.bind(
			session.world.equip_item.bind(index, slot), _equipped_detail.bind(slot)))
		_item_color(button, int(candidate.id))
	if not eligible:
		_label("No matching items in bags.")
	_button("Back (Esc)", open_equipment)
	_finish()


func _item_detail(index: int) -> void:
	var item := session.world.hero.inventory[index]
	var data := ItemData.get_item(int(item.id))
	_begin("item", "%s x%d" % [data.title, item.quantity], open_bags)
	_item_color(_label(ItemData.describe(int(item.id))), int(item.id))
	if data.slot != "":
		if data.slot == "ring":
			for suffix in ["_1", "_2"]:
				_button("Equip in %s%s (1 turn)" % [data.slot, suffix],
					_transaction.bind(session.world.equip_item.bind(index, data.slot + suffix), open_bags))
		else:
			_button("Equip (1 turn)",
				_transaction.bind(session.world.equip_item.bind(index), open_bags))
	if data.use != "":
		_button("Use one (1 turn)", _transaction.bind(session.world.consume_item.bind(index), open_bags))
	_button("Move / split stack", func() -> void:
		_quantity = 1
		_quantity_menu("Move quantity", int(item.quantity), _move_destination.bind(index),
			_item_detail.bind(index)))
	_button("Back (Esc)", open_bags)
	_finish()


func _move_destination(quantity: int, source: int) -> void:
	_begin("move", "Choose destination for %d item(s)" % quantity, open_bags)
	for index in range(40):
		var item := session.world.hero.inventory[index]
		var label := "Empty" if item.is_empty() else "%s x%d" % [
			ItemData.get_item(int(item.id)).title, item.quantity]
		var button := _button("Slot %d: %s" % [index + 1, label], _transaction.bind(
			InventoryRules.move.bind(session.world.hero, source, index, quantity), open_bags))
		button.disabled = index == source
		if not item.is_empty():
			_item_color(button, int(item.id))
	_button("Back (Esc)", open_bags)
	_finish()


func open_loot(source: GridActor) -> void:
	if not session.world.open_loot(source):
		close()
		return
	_loot_source = source
	_begin("loot", source.title, close)
	_button("Loot All", _transaction.bind(session.world.loot_all.bind(source), _refresh_loot))
	if source.loot_copper > 0:
		_button("Take " + InventoryRules.money(source.loot_copper),
			_transaction.bind(session.world.loot_money.bind(source), _refresh_loot))
	for index in range(source.loot.size()):
		var item := source.loot[index]
		if not LootData.collectable(session.world, item):
			continue
		var button := _button("Take %s x%d" % [ItemData.get_item(int(item.id)).title, item.quantity],
			_transaction.bind(session.world.loot_item.bind(source, index), _refresh_loot))
		_item_color(button, int(item.id))
	_button("Leave (Esc)", close)
	_finish()


func _refresh_loot() -> void:
	if not _loot_source.corpse_visible:
		close()
	else:
		open_loot(_loot_source)


func open_trade(merchant: GridActor) -> void:
	if session.world == null or not session.world.trader_in_range(merchant):
		close()
		return
	_merchant = merchant
	_begin("trade", merchant.title + " / " + InventoryRules.money(session.world.hero.copper), close)
	_button("Buy", open_buy.bind(merchant))
	_button("Sell", open_sell.bind(merchant))
	_button("Leave (Esc)", close)
	_finish()


func open_buy(merchant: GridActor) -> void:
	if session.world == null or not session.world.trader_in_range(merchant):
		close()
		return
	_merchant = merchant
	_begin("buy_list", merchant.title + " / Buy / " + InventoryRules.money(session.world.hero.copper),
		open_trade.bind(merchant))
	for key in MerchantData.catalog(merchant.npc_id):
		var data := ItemData.get_item(int(key))
		var stock := int(session.world.vendor_stock[merchant.spawn_id][key])
		var button := _button("Buy %s / %s each / %s" % [data.title,
			InventoryRules.money(MerchantData.unit_price(merchant.npc_id, int(key))),
			"Unlimited" if stock == -1 else str(stock) + " left"],
			_buy_options.bind(int(key)))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_item_color(button, int(key))
		button.disabled = stock == 0
	_button("Back (Esc)", open_trade.bind(merchant))
	_finish()


func open_sell(merchant: GridActor, selected_item: int = 0) -> void:
	if session.world == null or not session.world.trader_in_range(merchant):
		close()
		return
	_merchant = merchant
	_begin("sell", merchant.title + " / Sell / " + InventoryRules.money(session.world.hero.copper),
		open_trade.bind(merchant))
	_label("Confirm an item to sell its whole stack. Trading spends no turns.")
	var grey := _button("Sell All Grey Items", _transaction.bind(
		session.world.sell_all_grey.bind(merchant), open_sell.bind(merchant)))
	grey.disabled = true
	var selected: Button
	for index in range(40):
		var item := session.world.hero.inventory[index]
		if item.is_empty():
			continue
		var data := ItemData.get_item(int(item.id))
		if not data.tradable:
			continue
		var button := _button("Sell slot %d: %s x%d / %s total" % [index + 1, data.title,
			item.quantity, InventoryRules.money(int(data.sell) * int(item.quantity))],
			_transaction.bind(session.world.sell_item.bind(merchant, index, int(item.quantity)),
				open_sell.bind(merchant, int(item.id))))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_item_color(button, int(item.id))
		if int(data.quality) == 0:
			grey.disabled = false
		if selected == null and (selected_item == 0 or int(item.id) == selected_item):
			selected = button
	var back := _button("Back (Esc)", open_trade.bind(merchant))
	# Keep consecutive sales on the same item; exhaustion must not select another sale.
	(selected if selected != null else back).grab_focus()


func _buy_options(identifier: int) -> void:
	var merchant := _merchant
	var data := ItemData.get_item(identifier)
	_begin("buy", "Buy " + String(data.title), open_buy.bind(merchant))
	_item_color(_label(ItemData.describe(identifier)), identifier)
	var unit_price := MerchantData.unit_price(merchant.npc_id, identifier)
	var amounts: Array[int] = [1]
	if int(data.stack) > 10:
		amounts.append(10)
	if int(data.stack) > 1:
		amounts.append(int(data.stack))
	var stock := int(session.world.vendor_stock[merchant.spawn_id][str(identifier)])
	for quantity in amounts:
		var label := "Buy stack (%d)" % quantity if quantity == int(data.stack) and quantity > 1 else (
			"Buy %d" % quantity)
		var button := _button("%s / %s" % [label, InventoryRules.money(unit_price * quantity)],
			_transaction.bind(session.world.buy_item.bind(merchant, identifier, quantity),
				open_buy.bind(merchant)))
		button.disabled = (stock >= 0 and stock < quantity) or (
			session.world.hero.copper < unit_price * quantity)
	_button("Back (Esc)", open_buy.bind(merchant))
	_finish()


func _quantity_menu(title: String, maximum: int, action: Callable, back: Callable) -> void:
	_begin("quantity", "%s: %d" % [title, _quantity], back)
	for delta in [-5, -1, 1, 5]:
		_button("%+d" % delta, func() -> void:
			_quantity = clampi(_quantity + delta, 1, maximum)
			_quantity_menu(title, maximum, action, back))
	_button("Confirm %d" % _quantity, func() -> void: action.call(_quantity))
	_button("Cancel (Esc)", back)
	_finish()


func _transaction(action: Callable, back: Callable) -> void:
	if session.world == null or session.world.is_terminal():
		return
	var previous := session.world
	var success: bool = action.call()
	refreshed.emit()
	if session.world != previous:
		close()
	elif previous.is_terminal():
		return
	elif success:
		back.call()
	else:
		notice("Action rejected. Check money, stock, level, cooldown, and free slots; nothing was transferred.", back)


func close() -> void:
	if _completed():
		open_completion()
		return
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
		if event.physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return
		var action := _capture_action
		_capture_action = &""
		var key := int(event.get_physical_keycode_with_modifiers())
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
	_preview.text = ""
	_preview_panel.hide()
	_panel.position = size * 0.5 + Vector2(-360, -230 if active_game else -200)
	_panel.size = Vector2(720, 460 if active_game else 400)
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


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 680
	_rows.add_child(label)
	return label


func _button(text: String, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		if _buttons.has(button):
			action.call())
	# Defer until container layout settles, including a wrap from first to last.
	button.focus_entered.connect(func() -> void:
		_show_preview(button)
		_ensure_button_visible.call_deferred(button))
	button.mouse_entered.connect(_show_preview.bind(button))
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


func _select_class(category: StringName, marshal: GridActor) -> void:
	if session.select_class(category, marshal):
		session.world.trainer_referral_received = true
		refreshed.emit()
		_begin("class_referral", marshal.title, open_conversation.bind(marshal))
		_label(ValleyRoute.trainer_referral(category))
		_label("Visit your trainer to learn skills. Everything you already learned remains usable.")
		_button("Back (Esc)", open_conversation.bind(marshal))
		_button("Leave", close)
		_finish()
	else:
		notice("Class choice is unavailable. Speak to the marshal outside combat before accepting a quest.",
			open_conversation.bind(marshal))


func _train(identifier: StringName) -> void:
	if session.world.training_failure(_trainer, SkillRank.catalog(identifier)) != "":
		return
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


func _ensure_button_visible(button: Button) -> void:
	if is_instance_valid(button) and _rows.is_ancestor_of(button):
		(_rows.get_parent() as ScrollContainer).ensure_control_visible(button)


func open_conversation(actor: GridActor) -> void:
	if not QuestRules.in_range(session.world, actor, actor.npc_id):
		close()
		return
	QuestRules.event(session.world, "talk", str(actor.npc_id))
	_begin("conversation", actor.title, close)
	_label(ValleyRoute.greeting(actor.npc_id))
	var choices := false
	for identifier in QuestData.QUESTS:
		var quest: Dictionary = QuestData.QUESTS[identifier]
		if QuestRules.available(session.world, identifier) and int(quest.giver) == actor.npc_id:
			_quest_button(identifier, "Available: ", _quest_detail.bind(identifier, actor))
			choices = true
		elif (session.world.quests.has(identifier)
			and not session.world.quests[identifier].handed_in
			and int(quest.receiver) == actor.npc_id):
			_quest_button(identifier, "Ready: " if QuestRules.ready(session.world, identifier)
				else "In progress: ", _quest_detail.bind(identifier, actor))
			choices = true
	if actor.service == &"Marshal":
		if session.loop_count > 1 and (session.world.class_selected or session.world.ever_accepted_quest):
			_label("Advancing %s this Loop. Class choice is locked until death." % session.world.hero.selected_class)
		elif session.loop_count > 1 and not session.can_select_class():
			_label("Return outside combat to choose your class before accepting a quest.")
		if session.can_select_class():
			for category: StringName in ClassSkillData.PLAYABLE_CLASSES:
				var button := _button("Uhm... I seek %s teaching" % String(category).to_lower(),
					_confirm_class.bind(category, actor))
				var titles: PackedStringArray = []
				for skill in SkillRank.starting_skills(category):
					titles.append(skill.title)
				button.tooltip_text = "%d class XP. Learn %s for free at the trainer. Gear and learned skills remain." % [
					session.world.hero.progression_points(category), " + ".join(titles)]
		elif (not session.world.class_selected and not session.world.ever_accepted_quest
			and session.world.hero.selected_class == &"Warrior"
			and not session.world.trainer_referral_received):
			_button("It's been a long journey, is there a warrior master?", open_marshal)
		choices = true
	elif actor.service == &"Trader":
		if (actor.npc_id == 900003 and session.world.valley_route
			and session.world.hero.selected_class == &"Warrior"
			and not session.world.starter_gear_received):
			_button("Do you have any spare gear for warrior?", _request_spare_gear.bind(actor))
		_button("Trade", open_trade.bind(actor))
		choices = true
	elif actor.service in ClassSkillData.PLAYABLE_CLASSES:
		_button("Train", open_trainer.bind(actor.service))
		choices = true
	if not choices:
		session.world.add_message(session.world.interact(actor))
		close()
	else:
		_button("Leave (Esc)", close)
		_finish()
	refreshed.emit()


func open_quest_log() -> void:
	_begin("quests", "Quest log", close)
	var count := 0
	for identifier in session.world.quests:
		if not session.world.quests[identifier].handed_in:
			count += 1
			_quest_button(identifier, "Ready: " if QuestRules.ready(session.world, identifier)
				else "In progress: ", _quest_detail.bind(identifier, null))
	if count == 0:
		_label("No active quests. Speak to Deputy Willem beside the abbey.")
	_button("Close (Esc)", close)
	_finish()


func _quest_button(identifier: String, prefix: String, action: Callable) -> void:
	var quest: Dictionary = QuestData.QUESTS[identifier]
	var band := QuestRules.difficulty(int(quest.level), session.world.hero.level)
	var button := _button("%s%s [%s]" % [prefix, quest.title, band], action)
	var colors := {"Gray": Color.GRAY, "Green": Color("#70d779"),
		"Yellow": Color("#ffdd66"), "Orange": Color("#ffa34d"), "Red": Color("#ff7777")}
	button.add_theme_color_override("font_color", colors[band])
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _quest_detail(identifier: String, actor: GridActor) -> void:
	var back := open_quest_log if actor == null else open_conversation.bind(actor)
	var world := session.world
	var quest: Dictionary = QuestData.QUESTS[identifier]
	_begin("quest_detail", quest.title, back)
	_label("Level %d / %s. Return to %s." % [quest.level,
		QuestRules.difficulty(int(quest.level), world.hero.level),
		ValleyRoute.npc_name(int(quest.receiver))])
	for index in range(quest.objectives.size()):
		var objective: Dictionary = quest.objectives[index]
		var amount := QuestRules.progress(world, identifier, index) if world.quests.has(identifier) else 0
		_label("%s: %d/%d" % [QuestRules.objective_label(objective), amount, objective.count])
	_label("Reward: %d XP, %s." % [QuestRules.experience(int(quest.xp),
		int(quest.level), world.hero.level), InventoryRules.money(int(quest.copper))])
	if QuestRules.available(world, identifier) and actor != null:
		_button("Accept", _transaction.bind(QuestRules.accept.bind(world, identifier, actor), back))
	elif world.quests.has(identifier) and not world.quests[identifier].handed_in:
		if QuestRules.ready(world, identifier):
			_label("Objectives complete — ready for hand-in.")
			if actor != null and actor.npc_id == int(quest.receiver):
				if quest.choices.is_empty():
					_button("Hand in", _transaction.bind(
						QuestRules.hand_in.bind(world, identifier, actor), back))
				else:
					for item in quest.choices:
						_button("Choose " + String(ItemData.get_item(int(item)).title),
							_transaction.bind(QuestRules.hand_in.bind(
								world, identifier, actor, int(item)), back))
		_button("Abandon", func() -> void:
			confirm("Abandon " + String(quest.title) + "? Quest items and progress will be removed.",
				_transaction.bind(QuestRules.abandon.bind(world, identifier), back),
				_quest_detail.bind(identifier, actor)))
	if not quest.choices.is_empty():
		for item in quest.choices:
			_item_color(_label(ItemData.describe(int(item))), int(item))
	for item in quest.get("rewards", []):
		_item_color(_label(ItemData.describe(int(item))), int(item))
	_button("Back (Esc)", back)
	_finish()


func _item_color(control: Control, identifier: int) -> void:
	if control is Button:
		_item_preview(control, identifier)
	var color := ItemData.quality_color(int(ItemData.get_item(identifier).quality))
	if control is Label:
		control.add_theme_color_override("font_color", color)
	else:
		for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			control.add_theme_color_override(state, color)


func _item_preview(button: Button, identifier: int) -> void:
	button.set_meta("preview", ItemData.describe(identifier))
	button.set_meta("preview_color", ItemData.quality_color(int(ItemData.get_item(identifier).quality)))


func _show_preview(button: Button) -> void:
	_preview.text = button.get_meta("preview", "")
	_preview.add_theme_color_override("font_color", button.get_meta("preview_color", Color.WHITE))
	_preview_panel.visible = _preview.text != ""
