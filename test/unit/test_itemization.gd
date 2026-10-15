extends GutTest


func test_equipment_quality_rules_and_starter_loadout() -> void:
	var hero := HeroState.new(false)
	assert_eq(hero.equipment.size(), 2)
	for item in hero.equipment.values():
		var data := ItemData.get_item(int(item.id))
		assert_eq(data.quality, 0)
		assert_true(data.stats.is_empty())
	for catalog in [ItemData.ITEMS, ClassItems.ITEMS, MerchantItems.ITEMS,
		LootItems.ITEMS, NorthshireItems.ITEMS]:
		for data in catalog.values():
			if data.slot == "":
				continue
			assert_has(["armor", "neck", "ring", "weapons"], data.slot)
			match int(data.quality):
				0:
					assert_true(data.stats.is_empty(), data.title)
					assert_false(data.slot in ["neck", "ring"])
				1:
					assert_false(data.stats.is_empty(), data.title)
					if data.slot in ["neck", "ring"]:
						assert_true(data.stats.has("strength") or data.stats.has("agility")
							or data.stats.has("stamina"), data.title)
						assert_true(data.stats.has("crit") or data.stats.has("haste"), data.title)
					else:
						for stat in data.stats:
							assert_has(["crit", "haste"], stat)
				2:
					assert_true(data.stats.has("strength") or data.stats.has("agility")
						or data.stats.has("stamina"), data.title)
					assert_true(data.stats.has("crit") or data.stats.has("haste"), data.title)
				_:
					fail_test("Unsupported equipment quality: " + String(data.title))


func test_quality_upgrades_improve_damage_defense_and_secondary_stats() -> void:
	var hero := HeroState.new(false)
	var target := MeleeProfile.new()
	target.level = 1
	var damage: Array[int] = []
	var armor: Array[int] = []
	for identifier in [2361, 2129, 70022]:
		hero.inventory[0] = ItemData.instance(identifier)
		assert_true(InventoryRules.equip(hero, 0))
		damage.append(MeleeRules.damage(hero.melee, target, &"hit", 0.5))
		armor.append(hero.melee.armor)
	assert_lt(damage[0], damage[1])
	assert_lt(damage[1], damage[2])
	assert_lt(armor[0], armor[1])
	assert_lt(armor[1], armor[2])
	assert_gt(hero.attack_haste(), 1.0)


func test_quest_route_guarantees_all_common_slots_and_each_weapon_setup() -> void:
	var world := ValleyRoute.create_world(91, false)
	world.hero.level = 5
	world.hero._apply_level_stats()
	world.ever_accepted_quest = true
	for identifier in ValleyRoute.QUESTS:
		var quest: Dictionary = QuestData.QUESTS[identifier]
		var counts: Array[int] = []
		for objective in quest.objectives:
			counts.append(int(objective.count))
		world.quests[identifier] = {"handed_in": false, "counts": counts}
		world.loot_quests.append(identifier)
		var receiver: GridActor
		for actor in world.actors:
			if actor.npc_id == int(quest.receiver):
				receiver = actor
		_beside(world, receiver)
		assert_true(QuestRules.hand_in(world, identifier, receiver), identifier)
		assert_false(QuestRules.hand_in(world, identifier, receiver))
	var styles: Array[String] = []
	for item in world.hero.inventory:
		if item.is_empty():
			continue
		var data := ItemData.get_item(int(item.id))
		assert_eq(data.quality, 1)
		if data.weapon:
			styles.append(String(data.weapon_style))
	assert_has(styles, "two_hand")
	assert_has(styles, "shield_pair")
	assert_has(styles, "dual_wield")
	for index in range(world.hero.inventory.size()):
		if world.hero.inventory[index].is_empty():
			continue
		var data := ItemData.get_item(int(world.hero.inventory[index].id))
		if data.slot == "armor" or data.get("weapon_style", "") == "two_hand":
			assert_true(InventoryRules.equip(world.hero, index))
	assert_eq(world.hero.equipment.size(), 5)
	for item in world.hero.equipment.values():
		assert_eq(ItemData.get_item(int(item.id)).quality, 1)
	world.discard()


func test_multi_reward_quest_rolls_back_equipment_inventory_and_money_when_full() -> void:
	var world := ValleyRoute.create_world(92, false)
	world.ever_accepted_quest = true
	world.quests["valley_camp"] = {"handed_in": false, "counts": [4]}
	world.loot_quests.append("valley_camp")
	var marshal: GridActor
	for actor in world.actors:
		if actor.npc_id == 197:
			marshal = actor
	_beside(world, marshal)
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(118, 5)
	var equipment := world.hero.equipment.duplicate(true)
	var inventory := world.hero.inventory.duplicate(true)
	var health := world.hero.health
	assert_false(QuestRules.hand_in(world, "valley_camp", marshal))
	assert_eq(world.hero.equipment, equipment, "Auto-equipped first reward must roll back.")
	assert_eq(world.hero.inventory, inventory)
	assert_eq(world.hero.health, health)
	assert_eq(world.hero.copper, 0)
	assert_eq(world.hero.experience, 0)
	assert_false(world.quests.valley_camp.handed_in)
	world.hero.inventory[0] = {}
	assert_true(QuestRules.hand_in(world, "valley_camp", marshal))
	assert_eq(world.hero.equipment.ring_1.id, 70002)
	assert_eq(world.hero.inventory[0].id, 2224)
	world.discard()


func test_two_rings_can_be_selected_and_dual_pair_works_without_learning() -> void:
	var hero := HeroState.new(false)
	assert_true(InventoryRules.receive(hero, ItemData.instance(70002)))
	assert_true(InventoryRules.receive(hero, ItemData.instance(70003)))
	assert_eq(hero.equipment.ring_1.id, 70002)
	assert_eq(hero.equipment.ring_2.id, 70003)
	hero.inventory[0] = ItemData.instance(70012)
	assert_true(InventoryRules.equip(hero, 0, "ring_1"))
	assert_eq(hero.equipment.ring_2.id, 70003)
	hero.inventory[1] = ItemData.instance(2139)
	assert_true(InventoryRules.equip(hero, 1))
	assert_true(hero.has_off_hand_weapon())
	assert_eq(hero.off_hand_melee().damage_min, 2.0)
	assert_eq(hero.weapon_id(), hero.weapon_id(true))
	hero.inventory[1] = ItemData.instance(2129)
	assert_true(InventoryRules.equip(hero, 1))
	assert_false(hero.has_off_hand_weapon())
	assert_eq(hero.weapon_id(true), 0)


func test_vendor_gear_costs_roughly_twenty_seeded_kills_with_sold_loot() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 8, 8), Vector2i(4, 4), 123, false)
	for table in [299, 6, 257, 38]:
		var total := 0
		for index in range(1000):
			var source := GridActor.new(Vector2i.ZERO)
			source.spawn_id = "income/%d/%d" % [table, index]
			source.loot_table = table
			LootData.assign(world, source)
			total += source.loot_copper
			for item in source.loot:
				total += int(ItemData.get_item(int(item.id)).sell) * int(item.quantity)
		var kills := 200.0 / (total / 1000.0)
		assert_between(kills, 16.0, 25.0, str(table))
	for identifier in MerchantData.catalog(900003):
		var item := ItemData.get_item(int(identifier))
		if item.slot != "":
			assert_eq(item.quality, 1)
	world.discard()


func test_save_restores_untrained_dual_pair_and_level_one_uncommon_armor() -> void:
	var game := GameSession.new()
	game.new_game(93)
	game.world.hero.inventory[0] = ItemData.instance(2139)
	game.world.hero.inventory[1] = ItemData.instance(2572)
	assert_true(InventoryRules.equip(game.world.hero, 0))
	assert_true(InventoryRules.equip(game.world.hero, 1))
	game.world.hero.health = 10
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.hero.level, 1)
		assert_true(restored.hero.has_off_hand_weapon())
		assert_null(restored.hero.find_skill(&"ambidexterity_1"))
		assert_eq(restored.hero.equipment.armor.id, 2572)
		assert_eq(restored.hero.health, 10)
		restored.discard()
	snapshot.equipment.head = ItemData.instance(44)
	assert_null(SaveCodec.restore(snapshot, false))


func test_ambidexterity_boosts_offhand_damage_across_classes_without_changing_mainhand() -> void:
	var hero := HeroState.new(false)
	hero.inventory[0] = ItemData.instance(2139)
	assert_true(InventoryRules.equip(hero, 0))
	var main_multiplier := hero.melee.damage_multiplier
	var offhand := hero.off_hand_melee()
	assert_almost_eq(offhand.damage_multiplier, 0.5, 0.00001)
	var target := MeleeProfile.new()
	offhand.damage_min = 10
	offhand.damage_max = 10
	offhand.attack_power = 0
	var ordinary_damage := MeleeRules.damage(offhand, target, &"hit", 0.5)
	assert_true(hero.learn_skill(SkillDefinition.catalog(&"ambidexterity_1")))
	for category in ClassSkillData.PLAYABLE_CLASSES:
		hero.selected_class = category
		hero.refresh_stats()
		assert_eq(hero.melee.damage_multiplier, main_multiplier)
		offhand = hero.off_hand_melee()
		assert_almost_eq(offhand.damage_multiplier, 0.75, 0.00001)
		offhand.damage_min = 10
		offhand.damage_max = 10
		offhand.attack_power = 0
		assert_gt(MeleeRules.damage(offhand, target, &"hit", 0.5), ordinary_damage)
	assert_eq(hero.equipment.weapons.id, 2139)


func test_unrestricted_gear_auto_equips_into_vacant_slots_for_every_class() -> void:
	for category in ClassSkillData.PLAYABLE_CLASSES:
		var hero := HeroState.new(false)
		hero.selected_class = category
		hero.equipment.clear()
		assert_true(InventoryRules.receive(hero, ItemData.instance(2572)))
		assert_true(InventoryRules.receive(hero, ItemData.instance(2139)))
		assert_eq(hero.equipment.armor.id, 2572)
		assert_eq(hero.equipment.weapons.id, 2139)
		assert_true(hero.has_off_hand_weapon())
		assert_true(hero.inventory.all(func(item: Dictionary) -> bool: return item.is_empty()))


func _beside(world: GridWorld, actor: GridActor) -> void:
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(actor.tile + direction):
			world.player_tile = actor.tile + direction
			return
	fail_test("Contact has no adjacent open tile.")
