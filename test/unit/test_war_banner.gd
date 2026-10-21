extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(8, 8), 97, false)
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_BANNER_ID))
	return world


func _actor(world: GridWorld, tile: Vector2i, kind: String = "wolf") -> GridActor:
	var actor := GridActor.new(tile)
	actor.summon_kind = kind
	actor.max_health = 500
	actor.health = 500
	world.actors.append(actor)
	return actor


func test_banner_use_spends_one_item_and_turn_and_leaves_ground_passable() -> void:
	var world := _world()
	world.hero.rage = 0
	world.hero.learn_skill(SkillDefinition.catalog(&"battle_trance_1"))
	ClassToolkitRules.apply(world, &"battle_trance_1", {"charges": 1})
	assert_true(world.assign_hotbar(0, ItemData.WAR_BANNER_HOTBAR_ID))
	assert_true(world.consume_item(0))
	assert_eq(world.turn_count, 1)
	assert_false(world.has_war_banner())
	assert_eq(world.hero.rage, 0)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_true(world.hero.cooldowns.is_empty())
	assert_eq(GridWorld.tile_distance(world.player_tile, world.war_banner.tile), 1)
	assert_eq(int(world.war_banner.until) - world.turn_count, 10)
	assert_true(world.is_open(world.war_banner.tile))
	assert_true(world.move_player(world.war_banner.tile - world.player_tile))
	assert_true(WarBannerRules.protects(world), "Player can stand on the banner.")
	assert_false(world.use_war_banner())


func test_blocked_busy_and_duplicate_placement_preserve_the_item_and_turn() -> void:
	var world := _world()
	for direction in GridWorld.DIRECTIONS:
		world.blocked_tiles[world.player_tile + direction] = true
	assert_false(world.consume_item(0))
	assert_true(world.has_war_banner())
	assert_eq(world.turn_count, 0)
	world.blocked_tiles.clear()
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_HORN_ID))
	assert_true(world.use_war_horn())
	assert_false(world.use_war_banner())
	assert_true(world.has_war_banner())
	world.cancel_cast()
	assert_true(world.use_war_banner())
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_BANNER_ID))
	assert_false(world.use_war_banner())
	assert_eq(world.turn_count, 2)
	assert_true(world.has_war_banner())


func test_protection_reduces_all_damage_for_player_and_summons_but_not_enemies_or_townsfolk() -> void:
	var world := _world()
	assert_true(world.use_war_banner())
	for kind in ["wolf", "earth_elemental"]:
		var ally := _actor(world, Vector2i(9, 7), kind)
		SpellEffects.damage(world, ally, 100, "Incoming damage", -1, null, false)
		assert_eq(ally.health, 410)
		ally.relationship = GridActor.Relationship.HOSTILE
		assert_eq(ClassSpellEffects.absorb(world, ally, 100, true), 100)
		world.actors.erase(ally)
	var townsperson := _actor(world, Vector2i(9, 7), "")
	assert_eq(ClassSpellEffects.absorb(world, townsperson, 100, false), 100)
	for physical in [true, false]:
		assert_eq(ClassSpellEffects.absorb(world, null, 100, physical), 90)
	assert_eq(ClassSpellEffects.absorb(world, null, 1, true), 1)
	assert_eq(ClassSpellEffects.absorb(world, null, 0, true), 0)


func test_protection_follows_current_positions_at_square_radius_without_sight_requirement() -> void:
	var world := _world()
	assert_true(world.use_war_banner())
	var center: Vector2i = world.war_banner.tile
	world.player_tile = center + Vector2i(3, 3)
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 90)
	world.player_tile += Vector2i.RIGHT
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 100)
	assert_true(world.move_player(Vector2i.LEFT))
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 90)
	world.sight_blockers[center + Vector2i.ONE] = true
	assert_true(WarBannerRules.protects(world))
	var ally := _actor(world, center + Vector2i(4, 0))
	assert_eq(ClassSpellEffects.absorb(world, ally, 100, true), 100)
	ally.tile -= Vector2i.RIGHT
	assert_eq(ClassSpellEffects.absorb(world, ally, 100, true), 90)


func test_placement_turn_is_protected_and_expiry_happens_before_enemy_attacks() -> void:
	var world := _world()
	world.hero.equipment.clear()
	world.hero.refresh_stats()
	var enemy := _actor(world, world.player_tile + Vector2i.RIGHT, "")
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.melee.ignores_dodge = true
	enemy.melee.hit = 1000
	enemy.melee.critical = 0
	enemy.melee.damage_min = 20
	enemy.melee.damage_max = 20
	var health := world.hero.health
	assert_true(world.use_war_banner())
	assert_eq(world.hero.health, health - 18)
	enemy.stunned_until = 11
	for turn in range(9):
		world.wait_turn()
	assert_eq(world.turn_count, 10)
	assert_true(WarBannerRules.protects(world))
	health = world.hero.health
	world.wait_turn()
	assert_eq(world.turn_count, 11)
	assert_true(world.war_banner.is_empty())
	assert_eq(world.hero.health, health - 20)


func test_mitigation_precedes_lucky_charm_and_divine_shield_stays_immune() -> void:
	var world := _world()
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.LUCKY_CHARM_ID))
	assert_true(world.use_war_banner())
	world.hero.health = 10
	var target := NpcTarget.new(world, null)
	target.take_damage(ClassSpellEffects.absorb(world, null, 10, true), &"hit")
	assert_eq(world.hero.health, 1)
	assert_eq(world.hero.inventory[1].id, ItemData.LUCKY_CHARM_ID)
	world.hero.learn_skill(SkillDefinition.catalog(&"divine_shield_1"))
	ClassToolkitRules.apply(world, &"divine_shield_1", {})
	target.take_damage(ClassSpellEffects.absorb(world, null, 1000, true), &"hit")
	assert_eq(world.hero.health, 1)
	assert_eq(world.hero.inventory[1].id, ItemData.LUCKY_CHARM_ID)
	world.hero.buffs.erase(&"divine_shield_1")
	target.take_damage(ClassSpellEffects.absorb(world, null, 1000, true), &"hit")
	assert_eq(world.hero.health, 1)
	assert_eq(world.hero.inventory[1].id, ItemData.BROKEN_LUCKY_CHARM_ID)


func test_save_keeps_unspent_item_or_planted_position_and_expiry_and_rejects_invalid_banner() -> void:
	var game := GameSession.new()
	game.world = _world()
	game.world.war_banner_received = true
	assert_true(game.world.assign_hotbar(0, ItemData.WAR_BANNER_HOTBAR_ID))
	var snapshot := SaveCodec.capture(game)
	var unspent := SaveCodec.restore(snapshot, false)
	assert_not_null(unspent)
	if unspent == null:
		return
	assert_true(unspent.has_war_banner())
	assert_true(unspent.war_banner_received)
	assert_true(unspent.use_war_banner())
	unspent.wait_turn()
	game.world = unspent
	snapshot = JSON.parse_string(JSON.stringify(SaveCodec.capture(game)))
	var restored := SaveCodec.restore(snapshot, false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.war_banner, unspent.war_banner)
	assert_eq(restored.hotbar[0], ItemData.WAR_BANNER_HOTBAR_ID)
	assert_false(restored.has_war_banner())
	assert_true(restored.war_banner_received)
	assert_eq(ClassSpellEffects.absorb(restored, null, 100, true), 90)
	for bad_banner in [{"tile": [8, 7], "until": restored.turn_count},
		{"tile": [8, 7], "until": restored.turn_count + 11},
		{"tile": [-1, 7], "until": restored.turn_count + 1},
		{"tile": [8.5, 7], "until": restored.turn_count + 1}, []]:
		var invalid := snapshot.duplicate(true)
		invalid.war_banner = bad_banner
		assert_null(SaveCodec.restore(invalid, false))
	var old_snapshot := snapshot.duplicate(true)
	old_snapshot.erase("war_banner")
	old_snapshot.erase("war_banner_received")
	var old_restored := SaveCodec.restore(old_snapshot, false)
	assert_not_null(old_restored)
	if old_restored != null:
		assert_false(old_restored.war_banner_received)
		assert_true(old_restored.war_banner.is_empty())
