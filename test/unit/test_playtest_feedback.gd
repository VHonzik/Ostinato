extends GutTest


func test_regeneration_is_halved_at_early_levels_and_one_tenth_afterwards() -> void:
	for level in [1, 2, 3, 5]:
		var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(5, 5), 97, false)
		world.hero.level = level
		world.hero.refresh_stats()
		world.hero.health = 10
		for turn in range(10):
			world.wait_turn()
		assert_eq(world.hero.health, 25 if level <= 2 else 13)
		var enemy := GridActor.new(Vector2i(6, 5))
		enemy.relationship = GridActor.Relationship.HOSTILE
		enemy.engaged = true
		enemy.stunned_until = 100
		world.actors.append(enemy)
		var health := world.hero.health
		for turn in range(10):
			world.wait_turn()
		assert_eq(world.hero.health, health, "Combat still prevents natural healing.")


func test_corpse_bump_opens_loot_until_player_moves_and_survives_save() -> void:
	var session := GameSession.new()
	session.seed_value = 97
	session.world = GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(5, 5), 97, false)
	var world := session.world
	var enemy := GridActor.new(Vector2i(6, 5))
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.awards_experience = false
	enemy.loot_assigned = true
	enemy.loot_copper = 1
	enemy.health = 0
	world.actors.append(enemy)
	world._check_npc_death(enemy)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), false)
	assert_not_null(restored)
	if restored == null:
		return
	var opened: Array[GridActor] = []
	restored.loot_interaction_requested.connect(func(actor: GridActor) -> void: opened.append(actor))
	assert_false(restored.move_player(Vector2i.RIGHT))
	assert_eq(opened.size(), 1)
	assert_eq(restored.turn_count, 0)
	assert_true(restored.move_player(Vector2i.UP))
	assert_true(restored.move_player(Vector2i.DOWN))
	assert_true(restored.move_player(Vector2i.RIGHT))
	assert_eq(opened.size(), 1, "Returning to the death position does not rearm the shortcut.")


func test_bag_upgrade_compares_quality_against_each_matching_slot() -> void:
	var hero := HeroState.new()
	assert_false(InventoryRules.has_quality_upgrade(hero))
	assert_true(InventoryRules.receive(hero, ItemData.instance(85)))
	assert_true(InventoryRules.has_quality_upgrade(hero), "Occupied armor is not replaced automatically.")
	assert_true(InventoryRules.equip(hero, 0))
	assert_false(InventoryRules.has_quality_upgrade(hero))
	assert_true(InventoryRules.receive(hero, ItemData.instance(70012)))
	assert_false(InventoryRules.has_quality_upgrade(hero), "An empty ring slot auto-equips.")
	assert_true(InventoryRules.receive(hero, ItemData.instance(70003)))
	assert_true(InventoryRules.receive(hero, ItemData.instance(70013)))
	assert_true(InventoryRules.has_quality_upgrade(hero), "Either ring slot may be improved.")
	var ring_index := -1
	for index in range(hero.inventory.size()):
		if hero.inventory[index].get("id", 0) == 70013:
			ring_index = index
	assert_true(InventoryRules.equip(hero, ring_index, "ring_2"))
	assert_false(InventoryRules.has_quality_upgrade(hero))


func test_cooldown_cast_never_opens_target_selection_or_spends_a_turn() -> void:
	var game := (load("res://scenes/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	add_child_autofree(game)
	game.set_process(false)
	game.start_new_game()
	var world := game.world
	world.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	world.hero.rage = 100
	world.hero.cooldowns["lava_burst"] = 10
	game._cast_skill(&"lava_burst_1")
	assert_false(game.combat_panel.visible)
	assert_null(world.pending_skill)
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 100)
	game.combat_panel.open_spell(world, world.hero.find_skill(&"lava_burst_1"))
	assert_false(game.combat_panel.visible)
	assert_string_contains(world.messages[-1], "cooldown")


func test_quest_offer_cancel_accept_progress_and_completion_return_to_list() -> void:
	var session := GameSession.new()
	session.new_game(97)
	var world := session.world
	var marshal := world.actor_at(NpcDefinition.find(NpcDefinition.MARSHAL_ID).tile)
	world.player_tile = marshal.tile + Vector2i.DOWN
	var menu := MenuPanel.new()
	menu.session = session
	add_child_autofree(menu)
	menu.open_conversation(marshal)
	var title := "Wolves of the Western Woods"
	_button(menu, "! " + title).pressed.emit()
	assert_eq(menu.page, "quest_detail")
	assert_true(_has_label(menu, QuestData.dialogue("valley_wolves", 0)))
	_button(menu, "Cancel (Esc)").pressed.emit()
	assert_false(world.quests.has("valley_wolves"))
	_button(menu, "! " + title).pressed.emit()
	_button(menu, "Accept").pressed.emit()
	assert_eq(menu.page, "conversation")
	assert_eq(_button(menu, "? " + title).get_theme_color("font_color"), Color.GRAY)
	_button(menu, "? " + title).pressed.emit()
	assert_true(_has_label(menu, QuestData.dialogue("valley_wolves", 1)))
	assert_null(_button(menu, "Complete"))
	for index in range(8):
		QuestRules.record_kill(world, 299)
	for index in range(5):
		QuestRules.record_kill(world, 69)
	menu.open_conversation(marshal)
	assert_eq(_button(menu, "? " + title).get_theme_color("font_color"), Color("ffdd66"))
	_button(menu, "? " + title).pressed.emit()
	assert_true(_has_label(menu, QuestData.dialogue("valley_wolves", 2)))
	_button(menu, "Complete").pressed.emit()
	assert_true(world.quests.valley_wolves.handed_in)
	assert_eq(menu.page, "conversation")
	assert_null(_button(menu, "? " + title))
	assert_eq(world.turn_count, 0)


func test_trainer_puts_unlearned_skills_before_known_starters_and_orders_unlocks() -> void:
	var session := GameSession.new()
	session.new_game(97)
	session.world.hero.learn_skill(SkillDefinition.catalog(&"charge_1"))
	var menu := MenuPanel.new()
	menu.session = session
	add_child_autofree(menu)
	menu.open_trainer(&"Warrior")
	var ids: Array[StringName] = []
	for button in menu._buttons:
		if button.has_meta("skill_id"):
			ids.append(button.get_meta("skill_id"))
	assert_eq(ids.slice(0, 3), [&"enrage_1", &"battle_shout_1", &"recklessness_1"])
	assert_eq(ids.slice(-3), [&"mortal_strike_1", &"whirlwind_1", &"charge_1"])


func _button(menu: MenuPanel, text: String) -> Button:
	for button in menu._buttons:
		if button.text == text:
			return button
	return null


func _has_label(menu: MenuPanel, text: String) -> bool:
	for child in menu._rows.get_children():
		if child is Label and child.text == text:
			return true
	return false
