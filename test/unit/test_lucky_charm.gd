extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(8, 8), 97, false)
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.LUCKY_CHARM_ID))
	return world


func _enemy(world: GridWorld) -> GridActor:
	var enemy := GridActor.new(world.player_tile + Vector2i.RIGHT)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.melee.ignores_dodge = true
	enemy.melee.hit = 1000
	enemy.melee.critical = 0
	enemy.melee.damage_min = 10000
	enemy.melee.damage_max = 10000
	world.actors.append(enemy)
	return enemy


func test_lethal_hit_leaves_one_hp_and_replaces_charm_in_full_bags() -> void:
	var world := _world()
	for slot in range(1, world.hero.inventory.size()):
		world.hero.inventory[slot] = ItemData.instance(35)
	var inventory := world.hero.inventory.duplicate(true)
	var enemy := _enemy(world)
	enemy.melee.critical = 100
	world.hero.health = 10
	world.wait_turn()
	assert_eq(world.hero.health, 1)
	assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)
	assert_eq(world.hero.inventory[0], ItemData.instance(ItemData.BROKEN_LUCKY_CHARM_ID))
	assert_eq(world.hero.inventory.slice(1), inventory.slice(1))
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.last_hit_rage_turn, 1, "The surviving hit still grants incoming rage.")
	assert_string_contains("\n".join(world.messages), "Lucky charm saves you")
	assert_true(world.hero.learned_skills.all(func(skill: SkillDefinition) -> bool:
		return skill.class_tab != &"Rogue"), "The item works without Rogue learning or class selection.")


func test_nonlethal_and_zero_damage_leave_charm_intact_but_lethal_hit_at_one_hp_breaks_it() -> void:
	var world := _world()
	var target := NpcTarget.new(world, null)
	world.hero.health = 10
	target.take_damage(9, &"hit")
	assert_eq(world.hero.health, 1)
	target.take_damage(0, &"miss")
	assert_eq(world.hero.inventory[0].id, ItemData.LUCKY_CHARM_ID)
	target.take_damage(1, &"hit")
	assert_eq(world.hero.health, 1)
	assert_eq(world.hero.inventory[0].id, ItemData.BROKEN_LUCKY_CHARM_ID)
	assert_false(world.check_terminal())
	target.take_damage(1, &"hit")
	assert_eq(world.hero.health, 0)
	assert_true(world.check_terminal())


func test_absorbed_hit_does_not_break_charm() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.learn_skill(SkillDefinition.catalog(&"divine_shield_1"))
	ClassToolkitRules.apply(world, &"divine_shield_1", {})
	var health := world.hero.health
	NpcRules._attack(world, enemy, NpcTarget.new(world, null))
	assert_eq(world.hero.health, health)
	assert_eq(world.hero.inventory[0].id, ItemData.LUCKY_CHARM_ID)


func test_two_lethal_swings_in_the_same_turn_break_charm_then_kill_player() -> void:
	var world := _world()
	var enemy := _enemy(world)
	enemy.melee.interval = 0.5
	enemy.swing.remaining = 0.25
	enemy.swing._active = true
	world.wait_turn()
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.inventory[0].id, ItemData.BROKEN_LUCKY_CHARM_ID)
	assert_eq(world.hero.health, 0)
	assert_eq(world.attempt_state, GridWorld.AttemptState.PLAYER_DIED)


func test_charm_does_not_protect_summons_or_revive_a_dead_player() -> void:
	var world := _world()
	var summon := GridActor.new(world.player_tile + Vector2i.UP)
	summon.summon_kind = "wolf"
	summon.awards_experience = false
	world.actors.append(summon)
	NpcTarget.new(world, summon).take_damage(10000, &"hit")
	assert_eq(summon.health, 0)
	assert_eq(world.hero.inventory[0].id, ItemData.LUCKY_CHARM_ID)
	world.hero.health = 0
	NpcTarget.new(world, null).take_damage(1, &"hit")
	assert_eq(world.hero.health, 0)
	assert_eq(world.hero.inventory[0].id, ItemData.LUCKY_CHARM_ID)


func test_development_death_is_not_a_hit_and_passive_items_cannot_be_used_or_assigned() -> void:
	var world := _world()
	assert_false(world.consume_item(0))
	assert_false(world.assign_hotbar(0, &"item_lucky_charm"))
	assert_eq(world.turn_count, 0)
	assert_true(ItemData.get_item(ItemData.LUCKY_CHARM_ID).slot.is_empty())
	world.hero.learn_skill(SkillDefinition.development_skills().filter(
		func(skill: SkillDefinition) -> bool:
			return skill.effect == SkillDefinition.Effect.DEATH_NOTICE)[0])
	var death: SkillDefinition
	for skill in world.hero.learned_skills:
		if skill.effect == SkillDefinition.Effect.DEATH_NOTICE:
			death = skill
	assert_not_null(death)
	if death != null:
		assert_true(world.cast_skill(death.id))
	assert_eq(world.hero.health, 0)
	assert_eq(world.hero.inventory[0].id, ItemData.LUCKY_CHARM_ID)


func test_saves_preserve_intact_and_broken_charms_and_the_gift_claim() -> void:
	var game := GameSession.new()
	game.world = _world()
	game.world.lucky_charm_received = true
	for identifier in [ItemData.LUCKY_CHARM_ID, ItemData.BROKEN_LUCKY_CHARM_ID]:
		var snapshot := SaveCodec.capture(game)
		var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
		assert_not_null(restored)
		if restored == null:
			return
		assert_eq(restored.hero.inventory[0].id, identifier)
		assert_true(restored.lucky_charm_received)
		if identifier == ItemData.LUCKY_CHARM_ID:
			NpcTarget.new(game.world, null).take_damage(10000, &"hit")
	# Existing revision-29 saves have no charm and need no claim conversion.
	var old_snapshot := SaveCodec.capture(game)
	old_snapshot.inventory[0] = {}
	old_snapshot.erase("lucky_charm_received")
	var old_restored := SaveCodec.restore(old_snapshot, false)
	assert_not_null(old_restored)
	if old_restored != null:
		assert_false(old_restored.lucky_charm_received)
	var malformed := SaveCodec.capture(game)
	malformed.lucky_charm_received = "yes"
	assert_null(SaveCodec.restore(malformed, false))
