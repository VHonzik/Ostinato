extends GutTest


func _session() -> GameSession:
	var session := GameSession.new()
	session.development_build = false
	session.new_game(619)
	return session


func _contact(world: GridWorld, identity: int) -> GridActor:
	for actor in world.actors:
		if actor.npc_id == identity:
			return actor
	return null


func _beside(world: GridWorld, contact: GridActor) -> void:
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(contact.tile + direction):
			world.player_tile = contact.tile + direction
			return
	fail_test("Contact needs a free neighboring tile.")


func _menu(session: GameSession) -> MenuPanel:
	var menu := MenuPanel.new()
	menu.session = session
	add_child_autofree(menu)
	return menu


func _button(menu: MenuPanel, text: String) -> Button:
	for button in menu._buttons:
		if button.text == text:
			return button
	return null


func _text(menu: MenuPanel) -> String:
	var text := ""
	for row in menu._rows.get_children():
		if row is Label:
			text += row.text + "\n"
	return text


func test_janos_replaces_travel_clothes_once_without_refill_or_spending_time() -> void:
	var session := _session()
	var world := session.world
	var janos := _contact(world, 900003)
	assert_eq(janos.title, "Janos Hammerknuckle")
	assert_eq(_contact(world, 900002).title, "Farseer Lopaa")
	assert_eq(world.hero.equipment.size(), 3)
	assert_eq(world.hero.equipment.main_hand.id, 35)
	assert_eq(world.hero.equipment.legs.id, 44)
	assert_eq(world.hero.equipment.shirt.id, 45)
	_beside(world, janos)
	world.hero.health = 7
	world.hero.rage = 23
	world.hero.copper = 19
	var stock := world.vendor_stock.duplicate(true)
	assert_true(world.receive_starter_gear(janos))
	assert_eq(world.hero.equipment.size(), 5)
	for pair in [["off_hand", 2362], ["main_hand", 2361], ["chest", 2379],
		["legs", 2381], ["feet", 2383]]:
		assert_eq(world.hero.equipment[pair[0]].id, pair[1])
		assert_true(world.hero.equipment[pair[0]].starter)
	assert_false(ItemData.get_item(2361).two_handed, "The granted hammer fits beside a shield.")
	assert_eq(world.hero.melee.block, 5.0, "Equipped shield enables blocking.")
	assert_eq([world.hero.health, world.hero.rage, world.hero.copper], [7, 23, 19])
	assert_eq(world.turn_count, 0)
	assert_eq(world.vendor_stock, stock)
	assert_false(world.receive_starter_gear(janos), "Reopening must not replenish free gear.")
	assert_true(world.hero.inventory.all(func(item: Dictionary) -> bool: return item.is_empty()))


func test_janos_exchange_is_atomic_and_keeps_acquired_two_handed_weapon() -> void:
	var world := _session().world
	var janos := _contact(world, 900003)
	_beside(world, janos)
	# The same item ID acquired normally must survive removal of granted travel clothes.
	world.hero.equipment.main_hand = ItemData.instance(35)
	world.hero.refresh_stats()
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(35)
	var equipment := world.hero.equipment.duplicate(true)
	var inventory := world.hero.inventory.duplicate(true)
	assert_false(world.receive_starter_gear(janos))
	assert_eq(world.hero.equipment, equipment)
	assert_eq(world.hero.inventory, inventory)
	assert_false(world.starter_gear_received)
	world.hero.inventory[0] = {}
	world.hero.inventory[1] = {}
	assert_true(world.receive_starter_gear(janos))
	assert_eq(world.hero.equipment.main_hand, ItemData.instance(35))
	assert_false(world.hero.equipment.has("off_hand"), "An acquired staff still uses both hands.")
	assert_eq(world.hero.inventory[0].id, 2362)
	assert_eq(world.hero.inventory[1].id, 2361)


func test_janos_requires_living_nearby_trader_matching_class_and_no_pending_action() -> void:
	var world := _session().world
	var janos := _contact(world, 900003)
	assert_false(world.receive_starter_gear(janos), "Cannot claim gear remotely.")
	_beside(world, janos)
	janos.alive = false
	assert_false(world.receive_starter_gear(janos))
	janos.alive = true
	world.hero.selected_class = &"Paladin"
	assert_false(world.receive_starter_gear(janos), "Paladin has only a story referral in this slice.")
	world.hero.selected_class = &"Warrior"
	world.pending_skill = SkillRank.catalog(&"mortal_strike_1")
	assert_false(world.receive_starter_gear(janos))
	world.pending_skill = null
	var impostor := GridActor.new(janos.tile)
	impostor.npc_id = janos.npc_id
	impostor.service = janos.service
	impostor.spawn_id = janos.spawn_id
	assert_false(world.receive_starter_gear(impostor))
	assert_true(world.receive_starter_gear(janos))


func test_gear_grant_survives_save_load_and_resets_after_death() -> void:
	var session := _session()
	var janos := _contact(session.world, 900003)
	_beside(session.world, janos)
	assert_true(session.world.receive_starter_gear(janos))
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), false)
	assert_not_null(restored)
	if restored == null:
		return
	session.restore(restored, session.seed_value, session.loop_count)
	assert_true(restored.starter_gear_received)
	assert_false(restored.receive_starter_gear(_contact(restored, 900003)))
	assert_eq(restored.hero.equipment.off_hand.id, 2362)
	assert_eq(restored.hero.equipment.main_hand.id, 2361)
	restored.hero.health = 0
	assert_true(session.restart_after_death())
	assert_false(session.world.starter_gear_received)
	assert_eq(session.world.hero.equipment.main_hand.id, 35)
	assert_eq(session.world.hero.equipment.legs.id, 44)
	assert_eq(session.world.hero.equipment.shirt.id, 45)
	janos = _contact(session.world, 900003)
	_beside(session.world, janos)
	assert_true(session.world.receive_starter_gear(janos))


func test_saves_without_grant_field_still_load_and_malformed_flags_are_rejected() -> void:
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(SaveCodec.capture(_session())))
	snapshot.erase("starter_gear_received")
	for actor in snapshot.actors:
		if int(actor.state.npc_id) == 900003:
			actor.state.title = "Abbey supply trader"
		elif int(actor.state.npc_id) == 900002:
			actor.state.title = "Shaman trainer"
	var restored := SaveCodec.restore(snapshot, false)
	assert_not_null(restored)
	if restored != null:
		assert_false(restored.starter_gear_received)
		assert_eq(_contact(restored, 900003).title, "Janos Hammerknuckle")
		assert_eq(_contact(restored, 900002).title, "Farseer Lopaa")
	for invalid in [1, "true", null, []]:
		snapshot.starter_gear_received = invalid
		assert_null(SaveCodec.restore(snapshot, false))


func test_marshal_paladin_option_starts_on_second_loop_and_is_only_a_referral() -> void:
	var session := _session()
	var world := session.world
	var marshal := _contact(world, 197)
	_beside(world, marshal)
	var menu := _menu(session)
	menu.open_conversation(marshal)
	assert_string_contains(_text(menu), "You look worn out from your travels.")
	assert_null(_button(menu, "Uhm... I seek paladin teaching"))
	var warrior := _button(menu, "It's been a long journey, is there a warrior master?")
	assert_not_null(warrior)
	if warrior == null:
		return
	warrior.pressed.emit()
	assert_string_contains(_text(menu), "Speak with Llane Beshere inside the abbey.")
	assert_false(_text(menu).contains("Legion"))
	world.hero.health = 0
	assert_true(session.restart_after_death())
	world = session.world
	marshal = _contact(world, 197)
	_beside(world, marshal)
	menu.open_conversation(marshal)
	var paladin := _button(menu, "Uhm... I seek paladin teaching")
	assert_not_null(paladin)
	if paladin == null:
		return
	var equipment := world.hero.equipment.duplicate(true)
	var learned := world.hero.learned_skills.duplicate()
	paladin.pressed.emit()
	assert_string_contains(_text(menu), "Speak with Brother Sammuel inside the abbey.")
	assert_string_contains(_text(menu), "Also check with Janos inside")
	assert_eq(world.hero.selected_class, &"Warrior")
	assert_eq(world.hero.equipment, equipment)
	assert_eq(world.hero.learned_skills, learned)
	assert_eq(world.turn_count, 0)
	assert_false(world.starter_gear_received)
	assert_false(session.select_class(&"Paladin"))


func test_janos_conversation_awards_gear_once_and_keeps_trade_available() -> void:
	var session := _session()
	var world := session.world
	var janos := _contact(world, 900003)
	_beside(world, janos)
	var menu := _menu(session)
	menu.open_conversation(janos)
	assert_string_contains(_text(menu), "Greetings, what can I get you?")
	var spare := _button(menu, "Do you have any spare gear for warrior?")
	assert_not_null(spare)
	if spare == null:
		return
	spare.pressed.emit()
	assert_eq(menu.page, "spare_gear")
	assert_string_contains(_text(menu), "I can find some left overs if you are not picky.")
	assert_true(world.starter_gear_received)
	menu.open_conversation(janos)
	assert_null(_button(menu, "Do you have any spare gear for warrior?"))
	var trade := _button(menu, "Trade")
	assert_not_null(trade)
	if trade != null:
		trade.pressed.emit()
		assert_eq(menu.page, "trade")
	assert_eq(world.turn_count, 0)


func test_contacts_without_services_log_their_new_greetings() -> void:
	var session := _session()
	var menu := _menu(session)
	for identity in [198, 915, 925, 900002]:
		var contact := _contact(session.world, identity)
		_beside(session.world, contact)
		menu.open_conversation(contact)
		assert_false(menu.visible)
		assert_eq(session.world.messages[-1], contact.title + ": " + ValleyRoute.greeting(identity))
	assert_string_contains(session.world.messages[-1], "Farseer Lopaa, a storm-chaser.")
	assert_eq(session.world.turn_count, 0)
