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
var _preview: RichTextLabel


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
	content.custom_minimum_size.x = 696
	_panel.add_child(content)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_preview_panel = PanelContainer.new()
	_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_panel.custom_minimum_size.x = 680
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color("182a26")
	preview_style.border_width_top = 1
	preview_style.border_color = Color("50665f")
	preview_style.set_content_margin_all(6)
	_preview_panel.add_theme_stylebox_override("panel", preview_style)
	content.add_child(_preview_panel)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.add_theme_color_override("default_color", Color.WHITE)
	_preview.fit_content = true
	_preview.scroll_active = false
	_preview.custom_minimum_size = Vector2(668, 46)
	_preview.size.x = 668
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func _request_spare_gear(actor: GridActor) -> void:
	if not QuestRules.in_range(session.world, actor, NpcDefinition.JANOS_ID):
		close()
		return
	if session.world.starter_gear_received:
		_show_conversation(actor)
		return
	if not session.world.receive_starter_gear(actor):
		notice("Cannot exchange gear; make inventory space and try again.",
			_show_conversation.bind(actor))
		return
	_begin("spare_gear", actor.title, _show_conversation.bind(actor))
	_label("I can find some left overs if you are not picky.")
	_button("Back (Esc)", _show_conversation.bind(actor))
	_finish()
	refreshed.emit()


func open_trainer(category: StringName, selected_skill: StringName = &"") -> void:
	_trainer = category
	_begin("trainer", "%s training" % category, close)
	var selected_button: Button
	if category not in ClassSkillData.PLAYABLE_CLASSES:
		_label("Training for this class is not available yet.")
	elif session.world.hero.selected_class != category:
		_label("Select %s before learning here. Retained skills remain usable." % category)
	else:
		_label("Level %d / %s. Learning is permanent; starter skills are free." % [
			session.world.hero.level, InventoryRules.money(session.world.hero.copper)])
		for skill in SkillDefinition.trainer_skills(category):
			var known := session.world.hero.find_skill(skill.id) != null
			var price := "Free" if skill.training_copper == 0 else InventoryRules.money(skill.training_copper)
			var status := "Learned" if known else price
			var button := _button("%s / %s" % [skill.title, status],
				_train.bind(skill.id))
			button.set_meta("skill_id", skill.id)
			if skill.id == selected_skill:
				selected_button = button
			var failure := session.world.training_failure(category, skill)
			button.text += " / Lv %d" % skill.training_level
			button.set_meta("preview", skill.description + " " + failure)
			# Locked skills stay focusable so keyboard players can inspect them.
			if known or failure != "":
				for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
					button.add_theme_color_override(state, Color.GRAY if known else Color("ff7777"))
	_button("Leave (Esc)", close)
	if selected_button != null:
		selected_button.grab_focus()
	else:
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
		_item_label(int(item.id))
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
		button.set_meta("preview", ItemData.describe_rich(int(candidate.id),
			0 if item.is_empty() else int(item.id)))
	if not eligible:
		_label("No matching items in bags.")
	_button("Back (Esc)", open_equipment)
	_finish()


func _item_detail(index: int) -> void:
	var item := session.world.hero.inventory[index]
	var data := ItemData.get_item(int(item.id))
	_begin("item", "%s x%d" % [data.title, item.quantity], open_bags)
	_item_label(int(item.id))
	if data.slot != "":
		if data.slot == "ring":
			for suffix in ["_1", "_2"]:
				_button("Equip in %s%s (1 turn)" % [data.slot, suffix],
					_transaction.bind(session.world.equip_item.bind(index, data.slot + suffix), open_bags))
		else:
			_button("Equip (1 turn)",
				_transaction.bind(session.world.equip_item.bind(index), open_bags))
	if data.use != "":
		if data.use in ["war_horn", "ancestral_totem", "war_banner"]:
			var remaining := maxi(0, int(session.world.hero.cooldowns.get("war_horn", 0))
				- session.world.turn_count)
			if data.use == "war_horn" and remaining > 0:
				_label("Ready in %d turns." % remaining)
			var use_text := "Use (2-turn cast)" if data.use == "war_horn" else "Use once (1 turn)"
			_button(use_text, _transaction.bind(
				session.world.consume_item.bind(index), close))
			var assign := _button("Assign to hotbar", _assign_active_item.bind(index))
			assign.disabled = session.world.hotbar_locked
		else:
			_button("Use one (1 turn)", _transaction.bind(session.world.consume_item.bind(index), open_bags))
	_button("Move / split stack", func() -> void:
		_quantity = 1
		_quantity_menu("Move quantity", int(item.quantity), _move_destination.bind(index),
			_item_detail.bind(index)))
	_button("Back (Esc)", open_bags)
	_finish()


func _assign_active_item(index: int) -> void:
	var item_id := int(session.world.hero.inventory[index].id)
	var item_identifier := (ItemData.WAR_HORN_HOTBAR_ID if item_id == ItemData.WAR_HORN_ID
		else ItemData.ANCESTRAL_TOTEM_HOTBAR_ID)
	if item_id == ItemData.WAR_BANNER_ID:
		item_identifier = ItemData.WAR_BANNER_HOTBAR_ID
	_begin("item_hotbar", "Assign " + ItemData.get_item(item_id).title, _item_detail.bind(index))
	for slot in range(session.world.hotbar.size()):
		var identifier := session.world.hotbar[slot]
		var skill := session.world.hero.find_skill(identifier)
		var title := "Empty" if skill == null else skill.title
		if identifier == GridWorld.FOOD_HOTBAR_ID:
			title = "Food"
		elif identifier == ItemData.WAR_HORN_HOTBAR_ID:
			title = "War Horn"
		elif identifier == ItemData.ANCESTRAL_TOTEM_HOTBAR_ID:
			title = "Ancestral totem"
		elif identifier == ItemData.WAR_BANNER_HOTBAR_ID:
			title = "Wartorn Banner"
		var key := options.key_label(StringName("hotbar_%d" % (slot + 1)))
		_button("%s: %s" % [key, title], _transaction.bind(
			session.world.assign_hotbar.bind(slot, item_identifier),
			_item_detail.bind(index)))
	_button("Back (Esc)", _item_detail.bind(index))
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
	_item_label(identifier)
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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		_show_conversation(marshal)
	else:
		notice("Class choice is unavailable. Speak to the marshal outside combat before accepting a quest.",
			_show_conversation.bind(marshal))


func _train(identifier: StringName) -> void:
	if session.world.training_failure(_trainer, SkillDefinition.catalog(identifier)) != "":
		return
	session.world.train(_trainer, identifier)
	refreshed.emit()
	open_trainer(_trainer, identifier)


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
	session.world.interact(actor)
	_show_conversation(actor)


func _show_conversation(actor: GridActor) -> void:
	var conversation := NpcConversation.build(session, actor)
	if conversation == null:
		close()
		return
	if not conversation.keep_open:
		session.world.add_message(session.world.contact_greeting(actor))
		close()
	else:
		_begin("conversation", actor.title, close)
		var selected_button: Button
		_label(conversation.greeting)
		for line in conversation.lines:
			_label(line)
		for choice in conversation.choices:
			var callback := _conversation_choice.bind(choice, actor)
			if choice.action == NpcConversation.Action.QUEST:
				_quest_button(choice.quest_id, choice.quest_prefix, callback)
			else:
				var button := _button(choice.title, callback)
				button.tooltip_text = choice.tooltip
				if (choice.action == NpcConversation.Action.SELECT_CLASS
					and choice.category == session.world.hero.selected_class):
					selected_button = button
		_button("Leave (Esc)", close)
		if selected_button != null:
			selected_button.grab_focus()
		else:
			_finish()
	refreshed.emit()


func _conversation_choice(choice: NpcConversation.Choice, actor: GridActor) -> void:
	var conversation := NpcConversation.build(session, actor)
	if conversation == null:
		close()
		return
	if not conversation.offers(choice):
		_show_conversation(actor)
		return
	match choice.action:
		NpcConversation.Action.QUEST:
			_quest_detail(choice.quest_id, actor)
		NpcConversation.Action.SELECT_CLASS:
			_select_class(choice.category, actor)
		NpcConversation.Action.REFERRAL:
			open_marshal()
		NpcConversation.Action.SPARE_GEAR:
			_request_spare_gear(actor)
		NpcConversation.Action.TRADE:
			open_trade(actor)
		NpcConversation.Action.TRAIN:
			open_trainer(choice.category)
		NpcConversation.Action.WAR_HORN:
			_transaction(session.world.receive_war_horn.bind(actor),
				_show_conversation.bind(actor))
		NpcConversation.Action.LUCKY_CHARM:
			_transaction(session.world.receive_lucky_charm.bind(actor),
				_show_conversation.bind(actor))
		NpcConversation.Action.ANCESTRAL_TOTEM:
			_transaction(session.world.receive_ancestral_totem.bind(actor),
				_show_conversation.bind(actor))
		NpcConversation.Action.WAR_BANNER:
			_transaction(session.world.receive_war_banner.bind(actor),
				_show_conversation.bind(actor))


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
	var back := open_quest_log if actor == null else _show_conversation.bind(actor)
	var world := session.world
	var quest: Dictionary = QuestData.QUESTS[identifier]
	_begin("quest_detail", quest.title, back)
	_label("Level %d / %s. Return to %s." % [quest.level,
		QuestRules.difficulty(int(quest.level), world.hero.level),
		NpcDefinition.display_name(int(quest.receiver))])
	for index in range(quest.objectives.size()):
		var objective: QuestObjective = quest.objectives[index]
		var amount := QuestRules.progress(world, identifier, index) if world.quests.has(identifier) else 0
		_label("%s: %d/%d" % [objective.label(), amount, objective.count])
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
			_item_label(int(item))
	for item in quest.get("rewards", []):
		_item_label(int(item))
	_button("Back (Esc)", back)
	_finish()


func _item_label(identifier: int) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.add_theme_color_override("default_color", Color.WHITE)
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = 680
	label.text = ItemData.describe_rich(identifier)
	_rows.add_child(label)


func _item_color(button: Button, identifier: int) -> void:
	_item_preview(button, identifier)
	# Keep the native button text for its sizing and accessible name.
	for state in HotbarPanel.LABEL_COLOR_STATES:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	var text := RichTextLabel.new()
	text.name = "ItemText"
	text.bbcode_enabled = true
	text.add_theme_color_override("default_color", Color.WHITE)
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 6
	text.offset_right = -6
	text.offset_top = 4
	text.offset_bottom = -4
	text.text = "[center]" + ItemData.color_name(button.text, identifier) + "[/center]"
	text.modulate.a = 0.5 if button.disabled else 1.0
	button.add_child(text)


func _item_preview(button: Button, identifier: int) -> void:
	button.set_meta("preview", ItemData.describe_rich(identifier))


func _show_preview(button: Button) -> void:
	_preview.text = button.get_meta("preview", "")
	_preview_panel.visible = _preview.text != ""
