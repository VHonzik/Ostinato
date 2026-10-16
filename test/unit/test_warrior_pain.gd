extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 16, 16), Vector2i(5, 5), 97, false)
	world.hero.level = 3
	world.hero.equipment.clear()
	world.hero.refresh_stats()
	world.hero.health = world.hero.max_health
	return world


func _learn(world: GridWorld, identifiers: Array[StringName]) -> void:
	for identifier in identifiers:
		assert_true(world.hero.learn_skill(SkillDefinition.catalog(identifier)))


func _enemy(world: GridWorld, damage: float = 1.0) -> GridActor:
	var enemy := GridActor.new(world.player_tile + Vector2i.RIGHT)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.awards_experience = false
	enemy.max_health = 10000
	enemy.health = enemy.max_health
	enemy.stunned_until = 999
	enemy.melee.level = world.hero.level
	enemy.melee.hit = 100.0
	enemy.melee.critical = 0.0
	enemy.melee.dodge = 0.0
	enemy.melee.armor = 0
	enemy.melee.attack_power = 0
	enemy.melee.damage_min = damage
	enemy.melee.damage_max = damage
	world.hero.melee.dodge = 0.0
	world.actors.append(enemy)
	return enemy


func _proc_seed(should_proc: bool) -> int:
	var generator := RandomNumberGenerator.new()
	for seed_value in range(1000):
		generator.seed = seed_value
		generator.randf() # Incoming outcome.
		generator.randf() # Incoming damage.
		var roll := generator.randf()
		var selected := (roll > 0.1 and roll < 0.2) if should_proc else (roll > 0.4 and roll < 0.5)
		if selected:
			return seed_value
	fail_test("No controlled Enrage seed found.")
	return -1


func _fixed_weapon(hero: HeroState) -> void:
	# Turn boundaries rebuild equipment stats; restore this controlled weapon per attack.
	hero.melee.damage_min = 100.0
	hero.melee.damage_max = 100.0
	hero.melee.attack_power = 0
	hero.melee.hit = 100.0
	hero.melee.critical = 0.0


func test_pain_passives_unlock_early_without_becoming_castable() -> void:
	var world := _world()
	for identifier: StringName in [&"enrage_1", &"recklessness_1"]:
		var skill := SkillDefinition.catalog(identifier)
		world.hero.warrior_progress = skill.progress_required - 1
		assert_false(world.train(&"Warrior", identifier))
		world.add_class_progress(&"Warrior", 1)
		assert_string_contains("\n".join(world.messages), "learn " + skill.title)
		assert_true(world.train(&"Warrior", identifier))
		assert_eq(world.hero.warrior_progress, skill.progress_required)
		assert_lt(skill.progress_required, SkillDefinition.catalog(&"cruelty_1").progress_required)
		assert_false(world.cast_skill(identifier))
		assert_false(world.assign_hotbar(0, identifier))
	assert_null(SkillDefinition.catalog(&"warrior_flurry_1"))
	assert_not_null(SkillDefinition.catalog(&"shaman_flurry_1"))
	assert_eq(world.turn_count, 0)


func test_enrage_rolls_from_surviving_enemy_damage_at_high_and_low_health() -> void:
	for should_proc in [true, false]:
		for wounded in [true, false]:
			var world := _world()
			_learn(world, [&"enrage_1"])
			var enemy := _enemy(world)
			if wounded:
				world.hero.health = world.hero.max_health / 2
			var critical := world.hero.melee.critical
			var health := world.hero.health
			world.combat_random.seed = _proc_seed(should_proc)
			NpcRules._attack(world, enemy, NpcTarget.new(world, null))
			assert_eq(world.hero.health, health - 1)
			assert_eq(world.hero.buffs.has(&"enrage_1"), should_proc)
			assert_almost_eq(world.hero.melee.critical, critical + (5.0 if should_proc else 0.0), 0.001)
			assert_almost_eq(world.hero.melee.damage_multiplier, 1.1 if should_proc else 1.0, 0.001)
			assert_almost_eq(world.hero.attack_haste(), 1.0, 0.001)


func test_enrage_ignores_misses_dodges_immunity_and_lethal_hits_without_a_proc_roll() -> void:
	for condition in ["miss", "dodge", "immune", "lethal"]:
		var world := _world()
		_learn(world, [&"enrage_1", &"divine_shield_1"])
		world.hero.find_skill(&"enrage_1").coefficient = 1.0
		var enemy := _enemy(world, 1000.0 if condition == "lethal" else 1.0)
		match condition:
			"miss": enemy.melee.hit = -1000.0
			"dodge": world.hero.melee.dodge = 100.0
			"immune": ClassToolkitRules.apply(world, &"divine_shield_1", {})
		var expected := RandomNumberGenerator.new()
		expected.state = world.combat_random.state
		expected.randf()
		expected.randf()
		NpcRules._attack(world, enemy, NpcTarget.new(world, null))
		assert_false(world.hero.buffs.has(&"enrage_1"), condition)
		assert_eq(world.hero.last_enrage_roll_turn, -1, condition)
		assert_eq(world.combat_random.state, expected.state, condition)
		assert_eq(world.is_player_dead(), condition == "lethal")


func test_enrage_roll_is_limited_per_turn_even_when_the_first_roll_fails() -> void:
	var world := _world()
	_learn(world, [&"enrage_1"])
	var skill := world.hero.find_skill(&"enrage_1")
	var first := _enemy(world)
	var second := _enemy(world)
	skill.coefficient = 0.0
	NpcRules._attack(world, first, NpcTarget.new(world, null))
	skill.coefficient = 1.0
	var expected := RandomNumberGenerator.new()
	expected.state = world.combat_random.state
	expected.randf()
	expected.randf()
	NpcRules._attack(world, second, NpcTarget.new(world, null))
	assert_eq(world.combat_random.state, expected.state)
	assert_false(world.hero.buffs.has(&"enrage_1"))
	world.turn_count += 1
	NpcRules._attack(world, second, NpcTarget.new(world, null))
	assert_true(world.hero.buffs.has(&"enrage_1"))


func test_enrage_refreshes_without_stacking_survives_healing_and_expires() -> void:
	var world := _world()
	_learn(world, [&"enrage_1"])
	world.hero.find_skill(&"enrage_1").coefficient = 1.0
	var critical := world.hero.melee.critical
	var enemy := _enemy(world)
	NpcRules._attack(world, enemy, NpcTarget.new(world, null))
	var first_expiry := int(world.hero.buffs[&"enrage_1"].until)
	world.turn_count += 2
	world.hero.melee.dodge = 0.0
	NpcRules._attack(world, enemy, NpcTarget.new(world, null))
	var expiry := int(world.hero.buffs[&"enrage_1"].until)
	assert_eq(expiry, first_expiry + 2)
	assert_almost_eq(world.hero.melee.critical, critical + 5.0, 0.001)
	assert_almost_eq(world.hero.melee.damage_multiplier, 1.1, 0.001)
	SpellEffects.heal(world, null, world.hero.max_health, "Test heal")
	assert_true(world.hero.buffs.has(&"enrage_1"))
	world.turn_count = expiry - 2
	world.wait_turn()
	assert_true(world.hero.buffs.has(&"enrage_1"))
	world.wait_turn()
	assert_false(world.hero.buffs.has(&"enrage_1"))
	assert_almost_eq(world.hero.melee.critical, critical, 0.001)
	assert_almost_eq(world.hero.melee.damage_multiplier, 1.0, 0.001)


func test_enrage_does_not_proc_when_an_enemy_hits_a_summon() -> void:
	var world := _world()
	_learn(world, [&"enrage_1"])
	world.hero.find_skill(&"enrage_1").coefficient = 1.0
	var enemy := _enemy(world)
	var summon := GridActor.new(world.player_tile + Vector2i.DOWN)
	summon.relationship = GridActor.Relationship.FRIENDLY
	summon.summon_kind = "wolf"
	summon.health = 50
	summon.max_health = 50
	summon.melee.level = world.hero.level
	summon.melee.dodge = 0.0
	world.actors.append(summon)
	NpcRules._attack(world, enemy, NpcTarget.new(world, summon))
	assert_lt(summon.health, 50)
	assert_false(world.hero.buffs.has(&"enrage_1"))
	assert_eq(world.hero.last_enrage_roll_turn, -1)


func test_recklessness_ramps_caps_and_healing_immediately_reduces_both_effects() -> void:
	var world := _world()
	_learn(world, [&"recklessness_1"])
	# Level 3 without gear has 72 health, so all these fractions are exact.
	for setup: Array in [[72, 1.0, 1.0], [54, 1.0 + 0.2 / 3.0, 1.0 + 0.1 / 3.0],
		[36, 1.0 + 0.4 / 3.0, 1.0 + 0.2 / 3.0], [18, 1.2, 1.1], [9, 1.2, 1.1]]:
		world.hero.health = setup[0]
		assert_almost_eq(ClassToolkitRules.recklessness_damage_multiplier(world.hero), setup[1], 0.00001)
		assert_almost_eq(ClassToolkitRules.recklessness_taken_multiplier(world.hero), setup[2], 0.00001)
	SpellEffects.heal(world, null, world.hero.max_health, "Test heal")
	assert_almost_eq(ClassToolkitRules.recklessness_damage_multiplier(world.hero), 1.0, 0.00001)
	assert_almost_eq(ClassToolkitRules.recklessness_taken_multiplier(world.hero), 1.0, 0.00001)


func test_recklessness_incoming_penalty_uses_health_before_each_hit_and_respects_immunity() -> void:
	var world := _world()
	_learn(world, [&"recklessness_1", &"divine_shield_1"])
	var enemy := _enemy(world, 30.0)
	world.hero.health = 54
	NpcRules._attack(world, enemy, NpcTarget.new(world, null))
	assert_eq(world.hero.health, 23, "First hit is 30 with the pre-hit 3.33% penalty.")
	assert_almost_eq(ClassToolkitRules.recklessness_taken_multiplier(world.hero), 1.0 + 4.9 / 54.0, 0.00001)
	assert_eq(ClassSpellEffects.absorb(world, null, 100, false), 109, "Penalty also applies to nonphysical damage.")
	assert_eq(ClassSpellEffects.absorb(world, enemy, 100, true), 100, "The hero's risk never applies to NPCs.")
	ClassToolkitRules.apply(world, &"divine_shield_1", {})
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 0)
	assert_eq(ClassSpellEffects.absorb(world, null, 100, false), 0)


func test_recklessness_boosts_physical_attacks_but_not_holy_or_nature_damage() -> void:
	var world := _world()
	_learn(world, [&"recklessness_1", &"earth_shock_1", &"judgement_1"])
	var enemy := _enemy(world)
	_fixed_weapon(world.hero)
	world.hero.health = 18
	world.hero.rage = 100
	world.hero.swing.remaining = 100.0
	world.hero.swing._active = true
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_eq(enemy.max_health - enemy.health, 240)
	var before := enemy.health
	_fixed_weapon(world.hero)
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(before - enemy.health, 84)
	before = enemy.health
	_fixed_weapon(world.hero)
	world._player_swing(enemy)
	assert_eq(before - enemy.health, 120)
	before = enemy.health
	ClassToolkitRules.magic_attack(world, enemy, world.hero.find_skill(&"earth_shock_1"))
	assert_eq(before - enemy.health, 24, "Physical bonus does not amplify Nature damage.")
	before = enemy.health
	ClassToolkitRules.magic_attack(world, enemy, world.hero.find_skill(&"judgement_1"))
	assert_eq(before - enemy.health, 150, "Physical bonus does not amplify Holy damage.")


func test_pain_passives_work_in_retained_classes_while_shaman_keeps_flurry() -> void:
	var world := _world()
	_learn(world, [&"enrage_1", &"recklessness_1", &"shaman_flurry_1"])
	world.hero.selected_class = &"Rogue"
	world.hero.find_skill(&"enrage_1").coefficient = 1.0
	var enemy := _enemy(world)
	world.hero.health = 18
	NpcRules._attack(world, enemy, NpcTarget.new(world, null))
	assert_true(world.hero.buffs.has(&"enrage_1"))
	assert_almost_eq(ClassToolkitRules.recklessness_damage_multiplier(world.hero), 1.2, 0.001)
	AttackProcs.on_attack(world, AttackEvent.new(enemy, world.hero.find_skill(&"whirlwind_1"), &"critical", 20))
	assert_true(world.hero.buffs.has(&"shaman_flurry_1"))
	assert_true(world.hero.buffs.has(&"enrage_1"), "Shaman haste and Warrior Enrage coexist.")
	assert_almost_eq(world.hero.attack_haste(), 1.3, 0.001)
	assert_eq(world.hero.warrior_progress, 0)
	assert_eq(world.hero.progression_points(&"Rogue"), 0)


func test_enrage_save_preserves_expiry_stats_and_roll_boundary_and_death_clears_state() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.world = _world()
	var world := game.world
	world.hero.warrior_progress = 30
	_learn(world, [&"enrage_1", &"recklessness_1"])
	var enemy := _enemy(world)
	world.hero.find_skill(&"enrage_1").coefficient = 1.0
	NpcRules._attack(world, enemy, NpcTarget.new(world, null))
	enemy.alive = false
	assert_true(world.can_save())
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.hero.last_enrage_roll_turn, world.turn_count)
	assert_eq(restored.hero.buffs, world.hero.buffs)
	assert_almost_eq(restored.hero.melee.critical, world.hero.melee.critical, 0.001)
	assert_almost_eq(restored.hero.melee.damage_multiplier, 1.1, 0.001)
	var expiry := int(restored.hero.buffs[&"enrage_1"].until)
	var random_state := restored.combat_random.state
	ClassToolkitRules.on_damage_taken(restored, 1)
	assert_eq(restored.combat_random.state, random_state, "Reload cannot grant a second roll in the same turn.")
	assert_eq(int(restored.hero.buffs[&"enrage_1"].until), expiry)
	var invalid := snapshot.duplicate(true)
	invalid.hero.last_enrage_roll_turn = world.turn_count + 1
	assert_null(SaveCodec.restore(invalid, false))
	invalid = snapshot.duplicate(true)
	invalid.learned.erase("enrage_1")
	assert_null(SaveCodec.restore(invalid, false))
	world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_not_null(game.world.hero.find_skill(&"enrage_1"))
	assert_not_null(game.world.hero.find_skill(&"recklessness_1"))
	assert_eq(game.world.hero.last_enrage_roll_turn, -1)
	assert_true(game.world.hero.buffs.is_empty())
	assert_almost_eq(ClassToolkitRules.recklessness_damage_multiplier(game.world.hero), 1.0, 0.001)


func test_recklessness_aura_tracks_current_health_and_disappears_at_full_health() -> void:
	var world := _world()
	_learn(world, [&"recklessness_1"])
	var scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	var main := scene.instantiate() as Control
	add_child_autofree(main)
	var gameplay := main.get_node("GameContainer/GameViewport/Gameplay") as Gameplay
	gameplay.session.restore(world, 97, 1)
	world.hero.health = 18
	gameplay.refresh_view()
	var auras := gameplay.hud.get_node("Auras")
	assert_eq(auras.get_child_count(), 1)
	assert_string_contains((auras.get_child(0) as Control).tooltip_text, "+20.0% physical damage / +10.0% damage taken")
	SpellEffects.heal(world, null, world.hero.max_health, "Test heal")
	gameplay.refresh_view()
	assert_eq(auras.get_child_count(), 0)
