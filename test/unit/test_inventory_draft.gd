extends GutTest


func test_preparing_multiple_grants_does_not_equip_or_change_stats_until_commit() -> void:
	var hero := HeroState.new(false)
	var equipment := hero.equipment.duplicate(true)
	var inventory := hero.inventory.duplicate(true)
	var armor := hero.melee.armor
	var draft := InventoryDraft.new(hero)
	assert_true(draft.receive(ItemData.instance(70002)))
	assert_true(draft.receive(ItemData.instance(70003)))
	assert_true(draft.receive(ItemData.instance(118, 2)))
	assert_eq(hero.equipment, equipment)
	assert_eq(hero.inventory, inventory)
	assert_eq(hero.melee.armor, armor)
	draft.commit()
	assert_eq(hero.equipment.ring_1.id, 70002)
	assert_eq(hero.equipment.ring_2.id, 70003)
	assert_eq(hero.inventory[0], ItemData.instance(118, 2))
	var expected := HeroState.new(false)
	expected.equipment = hero.equipment.duplicate(true)
	expected.refresh_stats()
	assert_eq([hero.strength, hero.agility, hero.stamina, hero.max_health],
		[expected.strength, expected.agility, expected.stamina, expected.max_health])


func test_multi_quantity_grant_needs_space_for_remainder_before_auto_equipping() -> void:
	var hero := HeroState.new(false)
	for index in range(hero.inventory.size()):
		hero.inventory[index] = ItemData.instance(118, 5)
	var before := hero.equipment.duplicate(true)
	var inventory := hero.inventory.duplicate(true)
	assert_false(InventoryRules.receive(hero, ItemData.instance(70001, 2)))
	assert_eq(hero.equipment, before)
	assert_eq(hero.inventory, inventory)
	hero.inventory[0] = {}
	assert_true(InventoryRules.receive(hero, ItemData.instance(70001, 2)))
	assert_eq(hero.equipment.neck.id, 70001)
	assert_eq(hero.inventory[0], ItemData.instance(70001))
