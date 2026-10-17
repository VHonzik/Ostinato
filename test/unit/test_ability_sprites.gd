extends GutTest

var _world: GridWorld
var _view: RecordingGridView
var _enemy: GridActor


func before_each() -> void:
	_world = GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(8, 8), 97, false)
	_world.hero.equipment["weapons"] = ItemData.instance(2092)
	for identifier: StringName in [&"battle_shout_1", &"lightning_shield_1",
		&"execution_sentence_1", &"seal_of_command_1", &"windfury_weapon_1", &"consecration_1"]:
		_world.hero.learn_skill(SkillDefinition.catalog(identifier))
	_world.hero.rage = 100
	_world.hero.melee.hit = 100.0
	_world.hero.melee.critical = 0.0
	_world.hero.swing.remaining = 100.0
	_world.hero.swing._active = true
	_enemy = GridActor.new(Vector2i(9, 8))
	_enemy.npc_id = 299
	_enemy.relationship = GridActor.Relationship.HOSTILE
	_enemy.health = 1000
	_enemy.max_health = 1000
	_enemy.melee.dodge = 0.0
	_enemy.stunned_until = 999
	_enemy.awards_experience = false
	_world.actors.append(_enemy)
	_view = RecordingGridView.new()
	add_child_autofree(_view)
	_view.world = _world
	_view.set_process(false)


func test_player_effect_lasts_one_and_a_half_seconds_without_spending_turns() -> void:
	_view._draw_player()
	var original := _view.base
	assert_true(_world.cast_skill(&"battle_shout_1"))
	var turn := _world.turn_count
	_view._draw_player()
	assert_eq((_view.base as AtlasTexture).region, Rect2(0, 64, 16, 16))
	_view._process(0.125)
	_view._draw_player()
	assert_eq((_view.base as AtlasTexture).region, Rect2(0, 64, 16, 16))
	_view._process(1.25)
	_view._draw_player()
	assert_eq((_view.base as AtlasTexture).region, Rect2(0, 64, 16, 16))
	_view._process(0.125)
	_view._draw_player()
	assert_same(_view.base, original)
	assert_true(_view._player_blink.is_empty())
	assert_eq(_world.turn_count, turn)


func test_new_player_effect_replaces_previous_and_restarts_its_duration() -> void:
	assert_true(_world.cast_skill(&"battle_shout_1"))
	_view._process(0.75)
	assert_true(_world.cast_skill(&"lightning_shield_1"))
	_view._draw_player()
	assert_eq((_view.base as AtlasTexture).region, Rect2(48, 32, 16, 16))
	_view._process(0.5)
	assert_false(_view._player_blink.is_empty())
	assert_eq(float(_view._player_blink.elapsed), 0.5)
	_view._process(1.0)
	assert_true(_view._player_blink.is_empty())


func test_failed_cast_does_not_start_a_blink() -> void:
	_world.hero.rage = 0
	assert_false(_world.cast_skill(&"seal_of_command_1"))
	assert_true(_view._player_blink.is_empty())


func test_landed_enemy_effect_replaces_both_layers_and_keeps_current_health_tint() -> void:
	for identifier: StringName in [&"mortal_strike_1", &"eviscerate_1", &"earth_shock_1"]:
		var event := AttackEvent.new(_enemy, SkillDefinition.catalog(identifier), &"hit", 1)
		SpellEffects.attack(_world, event, "Hit")
		_enemy.health = 200
		_view._draw_actor(_enemy)
		assert_same((_view.base as AtlasTexture).atlas, GridView.ABILITY_CHARACTERS)
		assert_eq(_view.base_color, Color.RED)
		assert_null(_view.faction)
		_view._process(0.125)
		_view._draw_actor(_enemy)
		assert_null(_view.faction)
		_view._process(1.375)
		_view._draw_actor(_enemy)
		assert_same(_view.faction, _view.npc_sprite_layers(_enemy).faction_sprite)
		assert_true(_view._npc_blinks.is_empty())


func test_enemy_miss_dodge_and_ordinary_swing_do_not_start_effects() -> void:
	for result: StringName in [&"miss", &"dodge"]:
		SpellEffects.attack(_world, AttackEvent.new(_enemy,
			SkillDefinition.catalog(&"mortal_strike_1"), result, 0), "Miss")
	SpellEffects.attack(_world, AttackEvent.new(_enemy, null, &"hit", 1), "You")
	assert_true(_view._npc_blinks.is_empty())


func test_enemy_effect_replacement_resets_time_and_other_actors_keep_their_own_timer() -> void:
	var other := GridActor.new(Vector2i(10, 8))
	_world.actors.append(other)
	_world.npc_ability_hit.emit(other, &"mortal_strike")
	_world.npc_ability_hit.emit(_enemy, &"mortal_strike")
	_view._process(1.25)
	_world.npc_ability_hit.emit(_enemy, &"earth_shock")
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(48, 48, 16, 16))
	_view._process(0.25)
	assert_false(_view._npc_blinks.has(other))
	assert_eq(float(_view._npc_blinks[_enemy].elapsed), 0.25)
	_view._process(1.25)
	assert_true(_view._npc_blinks.is_empty())


func test_sentence_shows_at_cast_and_again_at_impact_then_windfury_can_replace_it() -> void:
	_world.hero.buffs[&"seal_of_command_1"] = {"armor": 0, "until": 100}
	assert_true(_world.cast_skill(&"execution_sentence_1", _enemy))
	assert_eq((_view._npc_blinks[_enemy].sprite as AtlasTexture).region,
		Rect2(16, 16, 16, 16))
	_view._process(1.5)
	assert_true(_view._npc_blinks.is_empty())
	for turn in range(3):
		_world.wait_turn()
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(16, 16, 16, 16))
	_view._process(0.75)
	ClassToolkitRules.bonus_strike(_world, _enemy, false, 1.0, "Windfury",
		SkillDefinition.catalog(&"windfury_weapon_1"))
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(48, 16, 16, 16))
	assert_eq(float(_view._npc_blinks[_enemy].elapsed), 0.0)


func test_whirlwind_shows_on_each_landed_enemy_and_never_the_player() -> void:
	var other := GridActor.new(Vector2i(8, 9))
	other.npc_id = 299
	other.relationship = GridActor.Relationship.HOSTILE
	other.health = 1000
	other.max_health = 1000
	other.melee.dodge = 0.0
	other.stunned_until = 999
	_world.actors.append(other)
	assert_true(_world.cast_skill(&"whirlwind_1"))
	assert_true(_view._player_blink.is_empty())
	for enemy: GridActor in [_enemy, other]:
		assert_true(_view._npc_blinks.has(enemy))
		_view._draw_actor(enemy)
		assert_eq((_view.base as AtlasTexture).region, Rect2(0, 32, 16, 16))


func test_consecration_shows_open_tiles_for_one_and_a_half_seconds_then_restores_them() -> void:
	var flowers := Vector2i(7, 8)
	var wall := Vector2i(7, 7)
	_world.scenery_tiles[flowers] = &"flowers"
	_world.scenery_tiles[wall] = &"broadleaf_tree"
	_world.blocked_tiles[wall] = true
	assert_true(_world.cast_skill(&"consecration_1"))
	var turn := _world.turn_count
	var occupants := _view._sprite_occupants()
	assert_eq(_view._consecration_blink.tiles.size(), 8)
	assert_true(_view._consecration_visible(_world.player_tile))
	assert_true(_view._consecration_visible(_enemy.tile))
	assert_true(_view._consecration_visible(flowers))
	assert_false(_view._consecration_visible(wall))
	assert_eq(_view._terrain_sprite(flowers, occupants), &"")
	_view._draw_consecration()
	assert_eq(_view.effect_tiles.size(), 8)
	_view._process(0.125)
	assert_true(_view._consecration_visible(flowers))
	assert_eq(_view._terrain_sprite(flowers, occupants), &"")
	_view._process(0.125)
	assert_true(_view._consecration_visible(flowers))
	_world.player_tile = Vector2i(15, 15)
	assert_true(_view._consecration_visible(Vector2i(8, 8)), "The animation stays at the cast site.")
	assert_false(_view._consecration_visible(_world.player_tile))
	_view._process(1.125)
	assert_true(_view._consecration_visible(flowers))
	_view._process(0.125)
	assert_true(_view._consecration_blink.is_empty())
	assert_eq(_view._terrain_sprite(flowers, occupants), &"flowers")
	assert_false(_world.consecration.is_empty(), "Visual expiry does not end the damaging ground.")
	assert_eq(_world.turn_count, turn)


func test_world_replacement_clears_blinks_and_disconnects_old_world() -> void:
	assert_true(_world.cast_skill(&"consecration_1"))
	_world.ability_used.emit(SkillDefinition.catalog(&"battle_shout_1"))
	_world.npc_ability_hit.emit(_enemy, &"mortal_strike")
	_view.world = GridWorld.new(_world.bounds, _world.player_tile)
	assert_true(_view._player_blink.is_empty())
	assert_true(_view._npc_blinks.is_empty())
	assert_true(_view._consecration_blink.is_empty())
	_world.ability_used.emit(SkillDefinition.catalog(&"battle_shout_1"))
	_world.npc_ability_hit.emit(_enemy, &"mortal_strike")
	assert_true(_view._player_blink.is_empty())
	assert_true(_view._npc_blinks.is_empty())


func test_new_effect_replaces_consecration_on_its_tile_and_recasting_resets_the_area() -> void:
	assert_true(_world.cast_skill(&"consecration_1"))
	_view._process(1.0)
	_world.npc_ability_hit.emit(_enemy, &"mortal_strike")
	assert_false(_view._consecration_visible(_enemy.tile))
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(0, 16, 16, 16))
	_world.hero.cooldowns.clear()
	assert_true(_world.cast_skill(&"consecration_1"))
	assert_true(_view._consecration_visible(_enemy.tile))
	assert_true(_view._npc_blinks.is_empty())
	assert_eq(float(_view._consecration_blink.elapsed), 0.0)
	_view._process(1.0)
	assert_false(_view._consecration_blink.is_empty())
	_view._process(0.5)
	assert_true(_view._consecration_blink.is_empty())


class RecordingGridView:
	extends GridView

	var base: Texture2D
	var faction: Texture2D
	var base_color: Color
	var effect_tiles: Array[Vector2i] = []


	func _draw_sprite_layers(tile: Vector2i, base_texture: Texture2D,
		faction_texture: Texture2D, color: Color, _faction_color: Color) -> void:
		base = base_texture
		faction = faction_texture
		base_color = color
		if base_texture == _ability_sprite(CONSECRATION_CELL):
			effect_tiles.append(tile)
