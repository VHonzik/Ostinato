extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(8, 8), 97, false)
	for id: StringName in [&"relentless_assault_1", &"eviscerate_1", &"execute_1",
		&"lava_burst_1", &"judgement_1", &"seal_of_command_1", &"seal_fate_1", &"bandits_guile_1"]:
		world.hero.learn_skill(SkillDefinition.catalog(id))
	world.hero.rage = 100
	world.hero.swing.remaining = 100
	world.hero.swing._active = true
	return world


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(9, 8)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.health = 10000
	enemy.max_health = 10000
	enemy.awards_experience = false
	enemy.melee.hit = -1000
	world.actors.append(enemy)
	return enemy


func test_only_four_abilities_build_base_and_seal_fate_points() -> void:
	var world := _world()
	var enemy := _enemy(world)
	for id: StringName in [&"mortal_strike_1", &"execute_1", &"lava_burst_1", &"judgement_1"]:
		world.hero.combo_points = 0
		world.combo_event_counted = false
		AttackProcs.on_attack(world, AttackEvent.new(enemy, world.hero.find_skill(id), &"critical", 0))
		assert_eq(world.hero.combo_points, 2, String(id))
	world.hero.combo_points = 0
	world.combo_event_counted = false
	AttackProcs.on_attack(world, AttackEvent.new(enemy, world.hero.find_skill(&"whirlwind_1"), &"critical", 0))
	assert_eq(world.hero.combo_points, 0)
	assert_eq(int(ClassToolkitRules.effect(world.hero, &"bandits_guile_1").charges), 1,
		"Whirlwind still advances Guile independently of combo eligibility.")
	for result: StringName in [&"miss", &"dodge"]:
		AttackProcs.on_attack(world, AttackEvent.new(enemy, world.hero.find_skill(&"mortal_strike_1"), result, 0))
	assert_eq(world.hero.combo_points, 0)
	world.hero.combo_points = 5
	world.combo_event_counted = false
	AttackProcs.on_attack(world, AttackEvent.new(enemy, world.hero.find_skill(&"mortal_strike_1"), &"critical", 0))
	assert_eq(world.hero.combo_points, 5)


func test_auto_combo_chance_requires_potency_and_relentless_and_shares_base_cap() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.learned_skills.erase(world.hero.find_skill(&"seal_of_command_1"))
	var swing := AttackEvent.new(enemy, null, &"hit", 0)
	var state := world.combat_random.state
	AttackProcs.on_attack(world, swing)
	assert_eq(world.hero.combo_points, 0)
	assert_eq(world.combat_random.state, state)
	world.hero.learn_skill(SkillDefinition.catalog(&"combat_potency_1"))
	var potency := world.hero.find_skill(&"combat_potency_1")
	assert_almost_eq(potency.combo_chance, 0.3, 0.000001)
	potency.combo_chance = 0.0
	AttackProcs.on_attack(world, swing)
	assert_eq(world.hero.combo_points, 0)
	potency.combo_chance = 1.0
	AttackProcs.on_attack(world, swing)
	assert_eq(world.hero.combo_points, 1)
	state = world.combat_random.state
	AttackProcs.on_attack(world, swing)
	assert_eq(world.hero.combo_points, 1)
	assert_eq(world.combat_random.state, state, "No second combo roll after granting the base point.")
	AttackProcs.on_attack(world, AttackEvent.new(enemy, world.hero.find_skill(&"mortal_strike_1"), &"critical", 0))
	assert_eq(world.hero.combo_points, 2, "Seal Fate can add its point after the auto-attack point.")
	world.combo_event_counted = false
	world.hero.combo_points = 0
	swing.hand = AttackEvent.Hand.OFF
	AttackProcs.on_attack(world, swing)
	assert_eq(world.hero.combo_points, 0)
	world.hero.learned_skills.erase(world.hero.find_skill(&"relentless_assault_1"))
	swing.hand = AttackEvent.Hand.MAIN
	AttackProcs.on_attack(world, swing)
	assert_eq(world.hero.combo_points, 0)


func test_attacker_commits_on_miss_preserves_selection_and_allows_melee_retarget() -> void:
	var world := _world()
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(8, 9))
	var delay := world.hero.swing.remaining
	NpcRules.act(world, first)
	assert_same(world.committed_enemy(), first)
	assert_eq(world.hero.swing.remaining, delay)
	assert_eq(world.turn_count, 0)
	NpcRules.act(world, second)
	assert_same(world.committed_enemy(), first)
	assert_true(world.request_melee(second))
	assert_same(world.committed_enemy(), second)
	assert_eq(world.hero.swing.remaining, delay - 1.0)
	world.cancel_melee()
	second.alive = false
	first.swing.remaining = 0
	NpcRules.act(world, first)
	assert_same(world.committed_enemy(), first)


func test_free_highlights_require_usable_cast_but_full_combo_highlight_remains() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.auto_attack_target = enemy
	world.hero.buffs[&"battle_trance_1"] = {"until": 0}
	world.hero.combo_points = 5
	world.hero.rage = 0
	var panel := HotbarPanel.new()
	add_child_autofree(panel)
	world.assign_hotbar(0, &"mortal_strike_1")
	world.assign_hotbar(1, &"eviscerate_1")
	world.assign_hotbar(2, &"execute_1")
	var state := world.combat_random.state
	var buffs := world.hero.buffs.duplicate(true)
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_true(panel.slots[0].highlight_colors.has(HotbarPanel.FREE_COST_COLOR))
	assert_eq(panel.slots[1].highlight_colors.size(), 2, "Full points and an available free cast combine.")
	assert_false(panel.slots[2].highlight_colors.has(HotbarPanel.FREE_COST_COLOR), "Execute's health gate still applies.")
	world.hero.cooldowns.mortal_strike = 3
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_false(panel.slots[0].highlight_colors.has(HotbarPanel.FREE_COST_COLOR))
	world.hero.cooldowns.clear()
	enemy.tile = Vector2i(12, 8)
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_false(panel.slots[0].highlight_colors.has(HotbarPanel.FREE_COST_COLOR))
	enemy.tile = Vector2i(9, 8)
	world.sight_blockers[enemy.tile] = true
	assert_false(world.can_offer_cast(world.hero.find_skill(&"mortal_strike_1")))
	world.sight_blockers.clear()
	world.pending_skill = world.hero.find_skill(&"lava_burst_1")
	assert_false(world.can_offer_cast(world.hero.find_skill(&"mortal_strike_1")))
	world.pending_skill = null
	world.hero.combo_points = 0
	assert_false(world.can_offer_cast(world.hero.find_skill(&"eviscerate_1")))
	assert_eq(world.hero.buffs, buffs)
	assert_eq(world.combat_random.state, state)
	assert_eq(world.turn_count, 0)
	world.hero.buffs.clear()
	world.hero.combo_points = 5
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_eq(panel.slots[1].highlight_colors, [HotbarPanel.CRITICAL_COLOR])
	assert_false(world.cast_skill(&"eviscerate_1"), "Without Battle Trance, 15 rage is required.")
	assert_eq(world.hero.combo_points, 5)


func test_swing_progress_tracks_fractional_turn_delay_and_haste_without_advancing_time() -> void:
	var world := _world()
	var bar := (load("res://scripts/hero/swing_bar.gd") as GDScript).new() as Control
	add_child_autofree(bar)
	world.hero.melee.interval = 2.5
	world.hero.haste = 1.0
	world.hero.swing.remaining = 0
	world.hero.swing._active = false
	bar.refresh(world.hero)
	assert_almost_eq(bar.progress, 1.0, 0.000001)
	world.hero.swing.advance(true, 2.5)
	bar.refresh(world.hero)
	assert_almost_eq(bar.progress, 0.0, 0.000001)
	world.hero.swing.advance(true, 2.5)
	bar.refresh(world.hero)
	assert_almost_eq(bar.progress, 0.4, 0.000001)
	bar.refresh(world.hero)
	assert_almost_eq(world.hero.swing.remaining, 1.5, 0.000001)
	world.hero.haste = 2.0
	world.hero.swing.remaining = 0.5
	bar.refresh(world.hero)
	assert_almost_eq(bar.progress, 0.6, 0.000001)
	assert_eq(world.turn_count, 0)
