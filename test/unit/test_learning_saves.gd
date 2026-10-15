extends GutTest


func test_passive_eviscerate_and_slice_and_dice_roundtrip_and_loop_reset() -> void:
	var game := GameSession.new()
	game.new_game(79)
	var world := game.world
	world.hero.class_progress[&"Rogue"] = 1000
	for identifier: StringName in [&"slice_and_dice_1", &"eviscerate_1"]:
		assert_true(world.hero.learn_skill(SkillDefinition.catalog(identifier)))
	assert_false(world.assign_hotbar(0, &"eviscerate_1"))
	world.hero.rage = 100
	world.hero.combo_points = 3
	assert_true(world.cast_skill(&"slice_and_dice_1"))
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), true)
	assert_not_null(restored)
	if restored == null:
		return
	game.restore(restored, game.seed_value, game.loop_count)
	assert_eq(restored.hero.find_skill(&"eviscerate_1").effect, SkillDefinition.Effect.PASSIVE)
	assert_eq(restored.hero.combo_points, 0)
	assert_eq(int(restored.hero.buffs[&"slice_and_dice_1"].until) - restored.turn_count, 14)
	restored.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.find_skill(&"eviscerate_1").effect, SkillDefinition.Effect.PASSIVE)
	assert_eq(game.world.hero.combo_points, 0)
	assert_false(game.world.hero.buffs.has(&"slice_and_dice_1"))


func test_waiting_proc_roundtrip_preserves_consumption_and_loop_reset() -> void:
	var game := GameSession.new()
	game.new_game(79)
	var world := game.world
	world.hero.warrior_progress = 100
	assert_true(world.hero.learn_skill(SkillDefinition.catalog(&"incite_1")))
	ClassToolkitRules.apply(world, &"incite_1", {"charges": 1})
	for turn in range(25):
		world.wait_turn()
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), true)
	assert_not_null(restored)
	if restored == null:
		return
	assert_true(restored.hero.buffs.has(&"incite_1"))
	var target := GridActor.new(restored.player_tile + Vector2i.RIGHT)
	restored.hero.melee.hit = 100
	target.melee.dodge = 0
	var strike := restored.hero.find_skill(&"heroic_strike_1")
	assert_true(ClassToolkitRules.weapon_outcome(restored, target, strike, restored.hero.melee).critical)
	assert_false(restored.hero.buffs.has(&"incite_1"))
	world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_true(game.world.hero.buffs.is_empty())


func test_save_round_trip_restores_equipment_loot_stock_cooldowns_and_buff_expiry() -> void:
	var game := GameSession.new()
	game.new_game(79)
	var world := game.world
	world.hero.level = 10
	world.hero._apply_level_stats()
	world.hero.copper = 3000
	world.hero.warrior_progress = 20
	assert_true(world.train(&"Warrior", &"battle_shout_1"))
	world.hero.inventory[0] = ItemData.instance(2572)
	assert_true(world.equip_item(0))
	var chest := world.actors[-1]
	world.player_tile = chest.tile + Vector2i.RIGHT
	assert_true(world.open_loot(chest))
	assert_true(world.loot_item(chest, 0))
	assert_true(world.loot_money(chest))
	# Real treasure is near hostiles; return to the safe spawn before advancing time.
	world.player_tile = ValleyRoute.SPAWN
	world.vendor_stock["fixed/900003"]["118"] = 2
	world.hero.potion_ready_turn = 120
	world.hero.cooldowns["mortal_strike"] = 8
	assert_true(world.cast_skill(&"battle_shout_1"))
	assert_true(world.can_save())
	var before := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(before)), true)
	assert_not_null(restored)
	if restored == null:
		return
	var copy := GameSession.new()
	copy.restore(restored, game.seed_value, game.loop_count)
	assert_eq(JSON.stringify(SaveCodec.capture(copy)), JSON.stringify(before))
	for count in range(12):
		world.wait_turn()
		restored.wait_turn()
	assert_eq(JSON.stringify(SaveCodec.capture(copy)), JSON.stringify(SaveCodec.capture(game)))


func test_invalid_equipment_stacks_effects_and_stock_are_rejected_without_partial_restore() -> void:
	var game := GameSession.new()
	game.new_game(79)
	var state := SaveCodec.capture(game)
	var bad := state.duplicate(true)
	bad.inventory[0] = ItemData.instance(118, 6)
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.equipment.off_hand = ItemData.instance(2129)
	assert_null(SaveCodec.restore(bad, true), "A staff occupies both hands.")
	bad = state.duplicate(true)
	bad.vendor_stock["fixed/900003"]["118"] = -2
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.restoration = {"water": {"total": 10, "duration": 0, "started": 0, "delivered": 0}}
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.actors[0].loot = [ItemData.instance(999999)]
	assert_null(SaveCodec.restore(bad, true))


func test_revision_one_save_is_incompatible_and_preserved_without_renaming() -> void:
	var directory := "user://test_m5_revision_" + Crypto.new().generate_random_bytes(8).hex_encode()
	var saves := SaveStore.new(directory)
	var game := GameSession.new()
	game.new_game(79)
	assert_true(saves.save_slot(game, 1), saves.last_error)
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(1)))
	record.revision = 1
	var file := FileAccess.open(saves.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	var bytes := FileAccess.get_file_as_bytes(saves.slot_path(1))
	var world := game.world
	assert_false(saves.load_slot(game, 1))
	assert_same(game.world, world)
	assert_eq(saves.metadata(1).status, "Incompatible")
	assert_eq(FileAccess.get_file_as_bytes(saves.slot_path(1)), bytes)
	assert_eq(DirAccess.get_files_at(directory).size(), 1)
	DirAccess.remove_absolute(saves.slot_path(1))
	DirAccess.remove_absolute(directory)
