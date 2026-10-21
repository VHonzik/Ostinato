extends GutTest


func test_named_worlds_repeat_loot_after_new_game_death_and_save_load() -> void:
	for candidate in GameSession.WORLD_SEEDS:
		var game := GameSession.new()
		game.development_build = false
		game.new_game(candidate.hash())
		assert_eq(game.seed_name(), candidate)
		# Save before rolling loot: loading must preserve future rolls as well as existing loot.
		var data: Dictionary = JSON.parse_string(JSON.stringify(SaveCodec.capture(game)))
		var original := _loot_snapshot(game.world)
		var restored := SaveCodec.restore(data, false)
		assert_not_null(restored)
		if restored == null:
			game.world.discard()
			continue
		game.restore(restored, int(data.seed), int(data.loop))
		assert_eq(game.seed_name(), candidate)
		assert_eq(_loot_snapshot(game.world), original, candidate + " after load")
		game.world.hero.health = 0
		assert_true(game.restart_after_death())
		assert_eq(game.seed_name(), candidate)
		assert_eq(_loot_snapshot(game.world), original, candidate + " after death")
		game.new_game(candidate.hash())
		assert_eq(_loot_snapshot(game.world), original, candidate + " on a new game")
		game.world.discard()


func test_every_world_pair_has_distinct_chest_gear_and_ordinary_enemy_loot() -> void:
	var snapshots: Array[Dictionary] = []
	for candidate in GameSession.WORLD_SEEDS:
		var world := ValleyRoute.create_world(candidate.hash(), false)
		snapshots.append(_loot_snapshot(world))
		world.discard()
	for first in range(snapshots.size()):
		for second in range(first + 1, snapshots.size()):
			var different_enemies := 0
			var enemy_count := 0
			var different_chests := 0
			for identity: String in snapshots[first]:
				var left: Dictionary = snapshots[first][identity]
				var right: Dictionary = snapshots[second][identity]
				if left.chest:
					if left.gear != right.gear:
						different_chests += 1
				else:
					enemy_count += 1
					if left.items != right.items:
						different_enemies += 1
			var pair := "%s / %s" % [GameSession.WORLD_SEEDS[first], GameSession.WORLD_SEEDS[second]]
			assert_gt(enemy_count, 0)
			assert_gte(different_chests, 2, pair + ": gear differs in at least two of three chests")
			assert_gte(float(different_enemies) / enemy_count, 0.6,
				pair + ": at least 60% of enemies differ in items, excluding coins and quest drops")


func test_named_worlds_cover_all_uncommon_weapon_setups() -> void:
	var styles: Array[String] = []
	assert_has(GameSession.WORLD_SEEDS, GameSession.HARD_WORLD_SEED)
	for candidate in GameSession.WORLD_SEEDS:
		var world := ValleyRoute.create_world(candidate.hash(), false)
		var weapons: Array[String] = []
		var uncommon_count := 0
		for actor in world.actors:
			LootData.assign(world, actor)
			for drop in actor.loot:
				var item := ItemData.get_item(int(drop.id))
				if item.quality != 2:
					continue
				uncommon_count += 1
				if item.slot == "weapons":
					styles.append(item.weapon_style)
					weapons.append("%s (%s)" % [item.title, actor.spawn_id])
		if candidate == GameSession.HARD_WORLD_SEED:
			assert_eq(weapons.size(), 0, "HARD has no uncommon weapons in enemies or chests.")
			assert_lte(uncommon_count, 1, "HARD has scarce uncommon gear across the whole valley.")
		world.discard()
	for style in ["two_hand", "shield_pair", "dual_wield"]:
		assert_has(styles, style)


func _loot_snapshot(world: GridWorld) -> Dictionary:
	var result: Dictionary = {}
	for actor in world.actors:
		if not NorthshireLoot.TABLES.has(str(actor.loot_table)) or actor.loot_table == 161557:
			continue
		LootData.assign(world, actor)
		var ordinary := actor.loot.filter(func(item: Dictionary) -> bool:
			return ItemData.get_item(int(item.id)).quest == "")
		var gear := ordinary.filter(func(item: Dictionary) -> bool:
			return ItemData.get_item(int(item.id)).slot != "")
		result[actor.spawn_id] = {"items": ordinary.duplicate(true), "gear": gear.duplicate(true),
			"copper": actor.loot_copper, "chest": actor.chest}
	return result
