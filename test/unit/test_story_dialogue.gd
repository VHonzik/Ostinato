extends GutTest

const TALK_QUEST: String = "conversation_test"


func after_each() -> void:
	QuestData.QUESTS.erase(TALK_QUEST)


func _talk_quest(world: GridWorld, target: GridActor, receiver: int = 0) -> void:
	var contact := target.npc_id if receiver == 0 else receiver
	QuestData.QUESTS[TALK_QUEST] = {"title": "Conversation test", "minimum": 1,
		"category": "", "previous": [], "giver": contact, "receiver": contact,
		"level": 1, "xp": 0, "copper": 0, "choices": [], "rewards": [], "source_item": 0,
		"objectives": [QuestObjective.talk(target.npc_id, 3)]}
	world.quests[TALK_QUEST] = {"handed_in": false, "counts": [0]}
	world.loot_quests.append(TALK_QUEST)
	world.ever_accepted_quest = true


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
	assert_eq(world.hero.equipment.size(), 2)
	assert_eq(world.hero.equipment.weapons.id, 35)
	assert_eq(world.hero.equipment.armor.id, 44)
	_beside(world, janos)
	world.hero.health = 7
	world.hero.rage = 23
	world.hero.copper = 19
	var stock := world.vendor_stock.duplicate(true)
	assert_true(world.receive_starter_gear(janos))
	assert_eq(world.hero.equipment.size(), 2)
	for pair in [["weapons", 2361], ["armor", 2379]]:
		assert_eq(world.hero.equipment[pair[0]].id, pair[1])
		assert_true(world.hero.equipment[pair[0]].starter)
	assert_false(ItemData.get_item(2361).two_handed, "The granted hammer fits beside a shield.")
	assert_gte(world.hero.melee.armor, 35, "Equipped shield contributes armor.")
	assert_eq([world.hero.health, world.hero.rage, world.hero.copper], [7, 23, 19])
	assert_eq(world.turn_count, 0)
	assert_eq(world.vendor_stock, stock)
	assert_false(world.receive_starter_gear(janos), "Reopening must not replenish free gear.")
	assert_eq(world.hero.inventory[0], ItemData.instance(117, 5))


func test_janos_exchange_is_atomic_and_keeps_acquired_two_handed_weapon() -> void:
	var world := _session().world
	var janos := _contact(world, 900003)
	_beside(world, janos)
	# The same item ID acquired normally must survive removal of granted travel clothes.
	world.hero.equipment.weapons = ItemData.instance(35)
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
	assert_eq(world.hero.equipment.weapons, ItemData.instance(35))
	assert_false(world.hero.equipment.has("off_hand"), "An acquired staff still uses both hands.")
	assert_eq(world.hero.inventory[0].id, 2361)


func test_janos_requires_living_nearby_trader_matching_class_and_no_pending_action() -> void:
	var world := _session().world
	var janos := _contact(world, 900003)
	assert_false(world.receive_starter_gear(janos), "Cannot claim gear remotely.")
	_beside(world, janos)
	janos.alive = false
	assert_false(world.receive_starter_gear(janos))
	janos.alive = true
	world.hero.selected_class = &"Unknown"
	assert_false(world.receive_starter_gear(janos))
	world.hero.selected_class = &"Warrior"
	world.pending_skill = SkillDefinition.catalog(&"mortal_strike_1")
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
	assert_eq(restored.hero.equipment.weapons.id, 2361)
	restored.hero.health = 0
	assert_true(session.restart_after_death())
	assert_false(session.world.starter_gear_received)
	assert_eq(session.world.hero.equipment.weapons.id, 35)
	assert_eq(session.world.hero.equipment.armor.id, 44)
	var marshal := _contact(session.world, NpcDefinition.MARSHAL_ID)
	_beside(session.world, marshal)
	assert_true(session.select_class(&"Warrior", marshal))
	janos = _contact(session.world, 900003)
	_beside(session.world, janos)
	assert_true(session.world.receive_starter_gear(janos))


func test_every_class_gets_its_starter_gear_once_in_any_returning_loop() -> void:
	var session := _session()
	for category: StringName in [&"Paladin", &"Rogue", &"Shaman", &"Warrior", &"Paladin"]:
		session.world.hero.health = 0
		assert_true(session.restart_after_death())
		var world := session.world
		var marshal := _contact(world, NpcDefinition.MARSHAL_ID)
		_beside(world, marshal)
		assert_true(session.select_class(category, marshal))
		var janos := _contact(world, NpcDefinition.JANOS_ID)
		_beside(world, janos)
		var conversation := NpcConversation.build(session, janos)
		assert_true(conversation.choices.any(func(choice: NpcConversation.Choice) -> bool:
			return (choice.action == NpcConversation.Action.SPARE_GEAR
				and choice.title.contains(String(category).to_lower()))))
		assert_true(world.receive_starter_gear(janos))
		for identifier in StarterGear.outfit(category):
			assert_eq(world.hero.equipment[ItemData.get_item(identifier).slot].id, identifier)
		assert_false(world.receive_starter_gear(janos))
		assert_eq(world.hero.copper, 0)
		assert_eq(world.turn_count, 0)


func test_warrior_choice_is_confident_in_every_returning_loop() -> void:
	var session := _session()
	for loop in range(2, 6):
		session.world.hero.health = 0
		assert_true(session.restart_after_death())
		var marshal := _contact(session.world, NpcDefinition.MARSHAL_ID)
		_beside(session.world, marshal)
		var conversation := NpcConversation.build(session, marshal)
		for choice in conversation.choices:
			if choice.action != NpcConversation.Action.SELECT_CLASS:
				continue
			if choice.category == &"Warrior":
				assert_eq(choice.title, "I am warrior")
			elif loop == 2:
				assert_true(choice.title.begins_with("Uhm..."))
			elif loop == 3:
				assert_true(choice.title.begins_with("I am ...."))


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


func test_marshal_paladin_choice_confirms_class_and_unlocks_free_trainer_starters() -> void:
	var session := _session()
	var world := session.world
	var marshal := _contact(world, 197)
	_beside(world, marshal)
	var menu := _menu(session)
	menu.open_conversation(marshal)
	assert_false(_text(menu).contains("Other classes"))
	assert_null(_button(menu, "Uhm... I seek paladin teaching"))
	assert_null(_button(menu, "It's been a long journey, is there a warrior master?"))
	var restored := SaveCodec.restore(SaveCodec.capture(session), false)
	assert_not_null(restored)
	if restored != null:
		assert_false(restored.trainer_referral_received)
	world.hero.health = 0
	assert_true(session.restart_after_death())
	world = session.world
	assert_false(world.trainer_referral_received)
	marshal = _contact(world, 197)
	_beside(world, marshal)
	menu.open_conversation(marshal)
	assert_not_null(_button(menu, "I am warrior"))
	assert_null(_button(menu, "It's been a long journey, is there a warrior master?"))
	var equipment := world.hero.equipment.duplicate(true)
	_button(menu, "Uhm... I seek paladin teaching").pressed.emit()
	assert_eq(menu.page, "conversation")
	assert_string_contains("\n".join(world.messages), "Speak with Brother Sammuel inside the abbey.")
	assert_eq(world.hero.selected_class, &"Paladin")
	assert_eq(world.hero.equipment, equipment)
	assert_eq(world.turn_count, 0)
	menu.open_conversation(marshal)
	assert_null(_button(menu, "It's been a long journey, is there a warrior master?"))
	assert_null(_button(menu, "Uhm... I seek paladin teaching"))
	var trainer := _contact(world, 925)
	_beside(world, trainer)
	menu.open_conversation(trainer)
	_button(menu, "Train").pressed.emit()
	for identifier: StringName in ClassSkillData.STARTERS[&"Paladin"]:
		var skill := SkillDefinition.catalog(identifier)
		for button in menu._buttons:
			if button.text.begins_with(skill.title + " / Free"):
				assert_false(button.disabled)
				button.pressed.emit()
				break
		assert_not_null(world.hero.find_skill(identifier))
		assert_true(world.hotbar.has(identifier))
	assert_eq(world.hero.copper, 0)

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
	var contact := _contact(session.world, 198)
	_beside(session.world, contact)
	menu.open_conversation(contact)
	assert_false(menu.visible)
	assert_eq(session.world.messages[-1], contact.title + ": " + NpcDefinition.greeting_for(198))
	assert_eq(session.world.turn_count, 0)


func test_new_class_contacts_keep_greetings_and_open_only_implemented_training() -> void:
	var session := _session()
	var menu := _menu(session)
	for identity in [915, 925, 900002]:
		var contact := _contact(session.world, identity)
		_beside(session.world, contact)
		menu.open_conversation(contact)
		assert_true(menu.visible)
		assert_string_contains(_text(menu), NpcDefinition.greeting_for(identity))
		var train := _button(menu, "Train")
		assert_not_null(train)
		if train == null:
			continue
		train.pressed.emit()
		assert_eq(menu.page, "trainer")
		assert_string_contains(_text(menu), "Select %s before learning here." % contact.service)
		assert_eq(session.world.hero.learned_skills.size(), 2)
	assert_eq(session.world.turn_count, 0)


func test_building_conversation_choices_does_not_record_talking_or_change_world_state() -> void:
	var session := _session()
	var world := session.world
	var janos := _contact(world, NpcDefinition.JANOS_ID)
	_beside(world, janos)
	_talk_quest(world, janos)
	var snapshot := SaveCodec.capture(session)
	var messages := world.messages.duplicate()
	for index in range(3):
		var conversation := NpcConversation.build(session, janos)
		assert_not_null(conversation)
		assert_true(conversation.keep_open)
	assert_eq(SaveCodec.capture(session), snapshot)
	assert_eq(world.messages, messages)
	assert_eq(QuestRules.progress(world, TALK_QUEST, 0), 0)


func test_new_conversation_records_one_talk_but_returning_from_a_service_records_none() -> void:
	var session := _session()
	var world := session.world
	var janos := _contact(world, NpcDefinition.JANOS_ID)
	_beside(world, janos)
	_talk_quest(world, janos)
	var menu := _menu(session)
	menu.open_conversation(janos)
	assert_eq(QuestRules.progress(world, TALK_QUEST, 0), 1)
	_button(menu, "Do you have any spare gear for warrior?").pressed.emit()
	assert_eq(menu.page, "spare_gear")
	menu._back.call()
	assert_eq(menu.page, "conversation")
	assert_eq(QuestRules.progress(world, TALK_QUEST, 0), 1)
	menu.open_conversation(janos)
	assert_eq(QuestRules.progress(world, TALK_QUEST, 0), 2)
	assert_eq(world.turn_count, 0)


func test_greeting_without_menu_choices_records_only_one_talk() -> void:
	var session := _session()
	var world := session.world
	var contact := _contact(world, 198)
	_beside(world, contact)
	_talk_quest(world, contact, NpcDefinition.MARSHAL_ID)
	var menu := _menu(session)
	menu.open_conversation(contact)
	assert_false(menu.visible)
	assert_eq(QuestRules.progress(world, TALK_QUEST, 0), 1)
	assert_eq(world.messages[-1], world.contact_greeting(contact))


func test_conversation_button_from_previous_loop_cannot_grant_gear_in_new_world() -> void:
	var session := _session()
	var janos := _contact(session.world, NpcDefinition.JANOS_ID)
	_beside(session.world, janos)
	var menu := _menu(session)
	menu.open_conversation(janos)
	var spare := _button(menu, "Do you have any spare gear for warrior?")
	session.world.hero.health = 0
	assert_true(session.restart_after_death())
	_beside(session.world, _contact(session.world, NpcDefinition.JANOS_ID))
	spare.pressed.emit()
	assert_false(menu.visible)
	assert_false(session.world.starter_gear_received)
	assert_eq(session.world.hero.equipment.weapons.id, 35)
	assert_eq(session.world.turn_count, 0)


func test_saved_contact_keeps_actor_stats_when_definition_refreshes_its_display_name() -> void:
	var session := _session()
	var janos := _contact(session.world, NpcDefinition.JANOS_ID)
	janos.title = "Old supply trader"
	janos.max_health = 123
	janos.health = 111
	janos.melee.level = 4
	janos.melee.damage_min = 24.0
	janos.melee.damage_max = 30.0
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), false)
	assert_not_null(restored)
	if restored == null:
		return
	var saved := _contact(restored, NpcDefinition.JANOS_ID)
	assert_eq(saved.title, "Janos Hammerknuckle")
	assert_eq([saved.max_health, saved.health, saved.melee.level], [123, 111, 4])
	assert_eq([saved.melee.damage_min, saved.melee.damage_max], [24.0, 30.0])
