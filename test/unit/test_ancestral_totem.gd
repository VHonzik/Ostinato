extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(8, 8), 97, false)
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.ANCESTRAL_TOTEM_ID))
	return world


func test_totem_is_consumed_in_one_turn_without_rage_cooldown_or_proc_consumption() -> void:
	var world := _world()
	world.hero.learn_skill(SkillDefinition.catalog(&"battle_trance_1"))
	ClassToolkitRules.apply(world, &"battle_trance_1", {"charges": 1})
	world.hero.rage = 0
	assert_true(world.consume_item(0))
	assert_eq(world.turn_count, 1)
	assert_false(world.has_ancestral_totem())
	assert_true(world.hero.inventory[0].is_empty())
	assert_eq(world.hero.rage, 0)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_true(world.hero.cooldowns.is_empty())
	assert_null(world.pending_skill)
	var elemental := SummonRules.active(world, "earth_elemental")
	assert_not_null(elemental)
	if elemental == null:
		return
	assert_eq(elemental.max_health, 40)
	assert_eq(elemental.title, "Earth Elemental")
	assert_eq(elemental.melee.damage_min, 2.0)
	assert_eq(elemental.melee.damage_max, 4.0)
	assert_eq(elemental.melee.interval, 2.5)
	assert_eq(SummonRules.definition(elemental).id, ItemData.ANCESTRAL_TOTEM_HOTBAR_ID)
	assert_false(world.use_ancestral_totem())
	assert_eq(world.turn_count, 1)
	assert_null(SkillDefinition.catalog(&"earth_elemental_1"))
	assert_false(world.cast_skill(&"earth_elemental_1"))


func test_rejected_use_preserves_item_and_time_for_blocked_busy_and_existing_summon() -> void:
	var world := _world()
	for direction in GridWorld.DIRECTIONS:
		world.blocked_tiles[world.player_tile + direction] = true
	assert_false(world.consume_item(0))
	assert_true(world.has_ancestral_totem())
	assert_eq(world.turn_count, 0)
	world.blocked_tiles.clear()
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_HORN_ID))
	assert_true(world.use_war_horn())
	assert_false(world.use_ancestral_totem())
	assert_true(world.has_ancestral_totem())
	world.cancel_cast()
	assert_true(world.use_ancestral_totem())
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.ANCESTRAL_TOTEM_ID))
	assert_false(world.use_ancestral_totem())
	assert_true(world.has_ancestral_totem())
	assert_eq(world.turn_count, 2)


func test_unspent_and_consumed_totem_saves_preserve_claim_and_hotbar() -> void:
	var game := GameSession.new()
	game.world = _world()
	game.world.ancestral_totem_received = true
	assert_true(game.world.assign_hotbar(0, ItemData.ANCESTRAL_TOTEM_HOTBAR_ID))
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_true(restored.has_ancestral_totem())
	assert_true(restored.ancestral_totem_received)
	assert_eq(restored.hotbar[0], ItemData.ANCESTRAL_TOTEM_HOTBAR_ID)
	assert_true(restored.use_ancestral_totem())
	game.world = restored
	var consumed := SaveCodec.restore(SaveCodec.capture(game), false)
	assert_not_null(consumed)
	if consumed != null:
		assert_false(consumed.has_ancestral_totem())
		assert_true(consumed.ancestral_totem_received)
		assert_not_null(SummonRules.active(consumed, "earth_elemental"))
	var malformed := snapshot.duplicate(true)
	malformed.ancestral_totem_received = "yes"
	assert_null(SaveCodec.restore(malformed, false))
