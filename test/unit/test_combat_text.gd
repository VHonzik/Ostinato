extends GutTest

var _world: GridWorld
var _view: GridView
var _enemy: GridActor


func before_each() -> void:
	_world = GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 10), 17, false)
	_view = GridView.new()
	add_child_autofree(_view)
	_view.world = _world
	_view.combat_text.set_process(false)
	_view.combat_text._random.seed = 42
	_enemy = GridActor.new(Vector2i(11, 10))
	_enemy.title = "Enemy"
	_enemy.relationship = GridActor.Relationship.HOSTILE
	_enemy.awards_experience = false
	_enemy.health = 1000
	_enemy.max_health = 1000
	_enemy.melee.dodge = 0.0
	_enemy.melee.armor = 0.0
	_world.actors.append(_enemy)


func test_damage_procs_and_lethal_hit_show_resolved_damage_even_after_npc_death() -> void:
	var random_before := _world.random.state
	var combat_before := _world.combat_random.state
	SpellEffects.damage(_world, _enemy, 7, "Lightning Shield")
	SpellEffects.damage(_world, _enemy, 1000, "Finishing hit")
	assert_eq(_view.combat_text._entries.size(), 2)
	assert_eq(_view.combat_text._entries[0].text, "7")
	assert_eq(_view.combat_text._entries[1].text, "1000")
	assert_false(_enemy.alive)
	SpellEffects.damage(_world, _enemy, 7, "After death")
	assert_eq(_view.combat_text._entries.size(), 2)
	assert_eq(_world.random.state, random_before)
	assert_eq(_world.combat_random.state, combat_before)
	assert_eq(_world.turn_count, 0)


func test_weapon_miss_dodge_critical_and_off_hand_emit_separate_results() -> void:
	_world.hero.melee.hit = -100.0
	_world._player_swing(_enemy)
	assert_eq(_view.combat_text._entries[-1].text, "Miss")
	_world.hero.melee.hit = 100.0
	_enemy.melee.dodge = 100.0
	_enemy.facing = MeleeRules.facing_toward(_world.player_tile - _enemy.tile)
	_world._player_swing(_enemy)
	assert_eq(_view.combat_text._entries[-1].text, "Dodge")
	_enemy.melee.dodge = 0.0
	_world.hero.melee.critical = 100.0
	_world._player_swing(_enemy)
	assert_eq(_view.combat_text._entries[-1].color, Color("#ffd36a"))
	var off_hand := MeleeProfile.new()
	off_hand.hit = -100.0
	_world._player_off_hand_swing(_enemy, off_hand)
	assert_eq(_view.combat_text._entries[-1].text, "Miss")
	assert_eq(_view.combat_text._entries.size(), 4)


func test_magic_and_bonus_strike_misses_show_text_without_damage() -> void:
	_world.hero.melee.hit = -100.0
	ClassToolkitRules.magic_attack(_world, _enemy, SkillDefinition.catalog(&"earth_shock_1"))
	ClassToolkitRules.bonus_strike(_world, _enemy, false, 1.0, "Windfury")
	assert_eq(_view.combat_text._entries.size(), 2)
	for entry in _view.combat_text._entries:
		assert_eq(entry.text, "Miss")
	assert_eq(_enemy.health, 1000)


func test_absorbed_hit_shows_zero_instead_of_miss() -> void:
	_enemy.buffs[&"divine_shield_1"] = {"until": 10}
	SpellEffects.damage(_world, _enemy, 20, "Absorbed")
	assert_eq(_view.combat_text._entries[0].text, "0")
	assert_eq(_enemy.health, 1000)


func test_text_expires_without_turns_and_world_replacement_disconnects_old_events() -> void:
	SpellEffects.damage(_world, _enemy, 1, "First")
	SpellEffects.damage(_world, _enemy, 1, "Second")
	assert_lt(_view.combat_text._entries[0].velocity.x, 0.0)
	assert_gt(_view.combat_text._entries[1].velocity.x, 0.0)
	_view.combat_text._process(2.0)
	assert_true(_view.combat_text._entries.is_empty())
	assert_eq(_world.turn_count, 0)
	SpellEffects.damage(_world, _enemy, 1, "Before Loop")
	var replacement := GridWorld.new(_world.bounds, _world.player_tile)
	_view.world = replacement
	assert_true(_view.combat_text._entries.is_empty())
	SpellEffects.damage(_world, _enemy, 1, "Old Loop")
	assert_true(_view.combat_text._entries.is_empty())
	replacement.npc_combat_text.emit(Vector2i(12, 10), 3, &"hit")
	assert_eq(_view.combat_text._entries.size(), 1)
	assert_eq(_view.combat_text._entries[0].text, "3")
