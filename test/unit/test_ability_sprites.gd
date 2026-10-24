extends GutTest

var _world: GridWorld
var _view: RecordingGridView
var _enemy: GridActor


func before_each() -> void:
	_world = GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(8, 8), 97, false)
	_world.hero.equipment["weapons"] = ItemData.instance(2092)
	for identifier: StringName in [&"battle_shout_1", &"lightning_shield_1",
		&"judgement_1", &"seal_of_command_1", &"windfury_weapon_1", &"consecration_1"]:
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


func test_higher_player_effect_survives_a_newer_lower_effect() -> void:
	assert_true(_world.cast_skill(&"battle_shout_1"))
	_view._process(0.75)
	assert_true(_world.cast_skill(&"lightning_shield_1"))
	_view._draw_player()
	assert_eq((_view.base as AtlasTexture).region, Rect2(0, 64, 16, 16))
	_view._process(0.5)
	assert_false(_view._player_blink.is_empty())
	assert_eq(float(_view._player_blink[&"lightning_shield"].elapsed), 0.5)
	_view._process(1.0)
	assert_true(_view._player_blink.is_empty())


func test_failed_cast_does_not_start_a_blink() -> void:
	_world.hero.rage = 0
	assert_false(_world.cast_skill(&"seal_of_command_1"))
	assert_true(_view._player_blink.is_empty())


func test_player_and_enemy_melee_bumps_take_turns_without_advancing_combat() -> void:
	_enemy.stunned_until = 0
	_world.hero.equipment["weapons"] = ItemData.instance(2361)
	_world.hero.refresh_stats()
	_world.hero.swing.remaining = 0.0
	assert_true(_world.request_melee(_enemy))
	var turn := _world.turn_count
	var health := _world.hero.health
	assert_eq(_view._melee_bumps.size(), 2)
	assert_null(_view._melee_bumps[0].attacker)
	assert_same(_view._melee_bumps[1].attacker, _enemy)
	_view._process(GridView.MELEE_BUMP_SECONDS / 2.0)
	assert_ne(_view._melee_bump_offset(null), Vector2.ZERO)
	assert_eq(_view._melee_bump_offset(_enemy), Vector2.ZERO)
	_view._process(GridView.MELEE_BUMP_SECONDS)
	assert_eq(_view._melee_bump_offset(null), Vector2.ZERO)
	assert_ne(_view._melee_bump_offset(_enemy), Vector2.ZERO)
	_view._process(GridView.MELEE_BUMP_SECONDS)
	assert_false(_view.is_melee_bumping())
	assert_eq(_view._melee_bump_offset(_enemy), Vector2.ZERO)
	assert_eq(_world.turn_count, turn)
	assert_eq(_world.hero.health, health)


func test_enemy_misses_bump_but_waiting_for_a_swing_does_not() -> void:
	_enemy.engaged = true
	_enemy.stunned_until = 0
	_world.hero.melee.dodge = 100.0
	var health := _world.hero.health
	NpcRules.act(_world, _enemy)
	assert_eq(_world.hero.health, health)
	assert_true(_view.is_melee_bumping(), "Dodged attacks still show the attempt.")
	_view._process(GridView.MELEE_BUMP_SECONDS)
	_enemy.swing.remaining = 10.0
	NpcRules.act(_world, _enemy)
	assert_false(_view.is_melee_bumping(), "No bump without a due attack.")


func test_world_replacement_disconnects_old_attacks_and_clears_bump_queue() -> void:
	_world.melee_attacked.emit(_enemy, _world.player_tile)
	assert_true(_view.is_melee_bumping())
	_view.world = GridWorld.new(_world.bounds, _world.player_tile)
	assert_false(_view.is_melee_bumping())
	_world.melee_attacked.emit(_enemy, _world.player_tile)
	assert_false(_view.is_melee_bumping())


func test_dead_attackers_are_skipped_and_multiple_enemies_bump_separately() -> void:
	var other := GridActor.new(_world.player_tile + Vector2i.DOWN)
	other.relationship = GridActor.Relationship.HOSTILE
	other.engaged = true
	_world.actors.append(other)
	_enemy.engaged = true
	_enemy.stunned_until = 0
	NpcRules.act(_world, _enemy)
	NpcRules.act(_world, other)
	assert_eq(_view._melee_bumps.size(), 2)
	_view._process(GridView.MELEE_BUMP_SECONDS / 2.0)
	assert_ne(_view._melee_bump_offset(_enemy), Vector2.ZERO)
	assert_eq(_view._melee_bump_offset(other), Vector2.ZERO)
	_enemy.alive = false
	_view._process(0.0)
	_view._process(GridView.MELEE_BUMP_SECONDS / 2.0)
	assert_ne(_view._melee_bump_offset(other), Vector2.ZERO)
	_view._process(GridView.MELEE_BUMP_SECONDS)
	assert_false(_view.is_melee_bumping())


func test_enemy_bump_temporarily_reveals_actor_through_consecration_flash() -> void:
	assert_true(_world.cast_skill(&"consecration_1"))
	assert_true(_view._consecration_visible(_enemy.tile))
	_enemy.stunned_until = 0
	NpcRules.act(_world, _enemy)
	assert_true(_view.is_melee_bumping())
	assert_false(_view._consecration_visible(_enemy.tile))
	_view._process(GridView.MELEE_BUMP_SECONDS)
	assert_true(_view._consecration_visible(_enemy.tile))


func test_landed_enemy_effect_replaces_both_layers_and_keeps_current_health_tint() -> void:
	for identifier: StringName in [&"mortal_strike_1", &"eviscerate_1", &"lava_burst_1"]:
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


func test_stalker_health_and_faction_layers_tint_independently_and_elemental_uses_health_art() -> void:
	_enemy.stalker = true
	_enemy.health = 200
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(64, 0, 16, 16))
	assert_eq((_view.faction as AtlasTexture).region, Rect2(64, 16, 16, 16))
	assert_eq(_view.base_color, Color.RED)
	assert_eq(_view.faction_color, _view._actor_color(_enemy))
	var faction := _view.faction
	_enemy.health = _enemy.max_health
	_enemy.relationship = GridActor.Relationship.NEUTRAL
	_view._draw_actor(_enemy)
	assert_eq(_view.base_color, Color.WHITE)
	assert_same(_view.faction, faction)
	assert_eq(_view.faction_color, _view._actor_color(_enemy))
	var elemental := GridActor.new(Vector2i(10, 8))
	elemental.summon_kind = "earth_elemental"
	elemental.relationship = GridActor.Relationship.FRIENDLY
	elemental.health = 1
	elemental.max_health = 40
	_view._draw_actor(elemental)
	assert_eq((_view.base as AtlasTexture).region, Rect2(48, 64, 16, 16))
	assert_eq(_view.base_color, Color.RED)
	assert_null(_view.faction)


func test_enemy_priority_preserves_older_hit_until_expiry_then_reveals_newer_hit() -> void:
	var other := GridActor.new(Vector2i(10, 8))
	_world.actors.append(other)
	_world.npc_ability_hit.emit(other, &"mortal_strike")
	_world.npc_ability_hit.emit(_enemy, &"mortal_strike")
	_view._process(1.25)
	_world.npc_ability_hit.emit(_enemy, &"lava_burst")
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(0, 16, 16, 16))
	_view._process(0.25)
	assert_false(_view._npc_blinks.has(other))
	assert_eq(float(_view._npc_blinks[_enemy][&"lava_burst"].elapsed), 0.25)
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(48, 48, 16, 16))
	_view._process(1.25)
	assert_true(_view._npc_blinks.is_empty())


func test_sentence_shows_at_cast_and_impact_and_takes_priority_over_windfury() -> void:
	_world.hero.learn_skill(SkillDefinition.catalog(&"seal_of_command_1"))
	assert_true(_world.cast_skill(&"judgement_1", _enemy))
	assert_eq((_view._npc_blinks[_enemy][&"judgement"].sprite as AtlasTexture).region,
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
	assert_eq((_view.base as AtlasTexture).region, Rect2(16, 16, 16, 16))
	assert_eq(float(_view._npc_blinks[_enemy][&"windfury_weapon"].elapsed), 0.0)


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
	assert_false(_view._consecration_visible(_world.player_tile))
	assert_true(_view._consecration_visible(_enemy.tile))
	assert_true(_view._consecration_visible(flowers))
	assert_false(_view._consecration_visible(wall))
	assert_eq(_view._terrain_sprite(flowers, occupants), &"")
	_view._draw_consecration()
	assert_eq(_view.effect_tiles.size(), 6)
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


func test_consecration_replays_each_tick_and_always_leaves_the_player_visible() -> void:
	assert_true(_world.cast_skill(&"consecration_1"))
	var center := _world.player_tile
	for tick in range(6):
		assert_false(_view._consecration_blink.is_empty())
		assert_false(_view._consecration_visible(_world.player_tile))
		assert_true(_view._consecration_visible(_enemy.tile))
		_view._draw_player()
		assert_same(_view.base, _view.player_sprite_layers(_world.hero.selected_class).base_sprite)
		_view._process(GridView.ABILITY_BLINK_SECONDS)
		assert_true(_view._consecration_blink.is_empty())
		if tick == 0:
			_world.player_tile = center + Vector2i.LEFT
		if tick < 5:
			_world.wait_turn()
			assert_true(_view._consecration_visible(center))
	_world.wait_turn()
	assert_true(_world.consecration.is_empty())
	assert_true(_view._consecration_blink.is_empty(), "Expired ground stops replaying.")
	assert_eq(_world.turn_count, 7)


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
	_world.wait_turn()
	assert_true(_view._player_blink.is_empty())
	assert_true(_view._npc_blinks.is_empty())


func test_direct_hit_takes_priority_over_new_consecration_until_hit_expires() -> void:
	assert_true(_world.cast_skill(&"consecration_1"))
	_view._process(1.0)
	_world.npc_ability_hit.emit(_enemy, &"mortal_strike")
	assert_false(_view._consecration_visible(_enemy.tile))
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(0, 16, 16, 16))
	_world.hero.cooldowns.clear()
	assert_true(_world.cast_skill(&"consecration_1"))
	assert_false(_view._consecration_visible(_enemy.tile))
	assert_false(_view._npc_blinks.is_empty())
	assert_eq(float(_view._consecration_blink.elapsed), 0.0)
	_view._process(1.0)
	assert_false(_view._consecration_blink.is_empty())
	_view._process(0.5)
	assert_true(_view._consecration_blink.is_empty())


func test_priority_is_independent_of_trigger_order_and_hidden_effects_keep_aging() -> void:
	for families in [[&"mortal_strike", &"judgement"], [&"judgement", &"mortal_strike"]]:
		_view._npc_blinks.clear()
		for family: StringName in families:
			_world.npc_ability_hit.emit(_enemy, family)
		assert_eq(_view.character_effect(_enemy).family, &"mortal_strike")
	_view._process(1.0)
	_world.npc_ability_hit.emit(_enemy, &"judgement")
	_view._process(0.5)
	assert_eq(_view.character_effect(_enemy).family, &"judgement")
	_view._process(1.0)
	assert_true(_view.character_effect(_enemy).is_empty())


func test_melee_bump_beats_windup_and_aggro_beats_whirlwind() -> void:
	_enemy.breath_remaining = 2
	_view._show_breath_windup(_enemy)
	_world.npc_ability_hit.emit(_enemy, &"mortal_strike")
	assert_eq(_view.character_effect(_enemy).family, &"breath_windup")
	_world.melee_attacked.emit(_enemy, _world.player_tile)
	assert_eq(_view.character_effect(_enemy).family, &"melee_bump")
	_view._process(GridView.MELEE_BUMP_SECONDS)
	assert_eq(_view.character_effect(_enemy).family, &"breath_windup")
	_view._npc_blinks.clear()
	_enemy.breath_remaining = 0
	_view._show_aggro(_enemy)
	_world.npc_ability_hit.emit(_enemy, &"whirlwind")
	assert_eq(_view.character_effect(_enemy).family, &"aggro")
	_view._draw_actor(_enemy)
	assert_eq((_view.faction as AtlasTexture).region, Rect2(80, 0, 16, 16))


func test_vanish_and_self_effects_follow_priority() -> void:
	_world.hero.learn_skill(SkillDefinition.catalog(&"vanish_1"))
	assert_true(_world.cast_skill(&"vanish_1"))
	_view._show_player_ability(SkillDefinition.catalog(&"lightning_shield_1"))
	assert_eq(_view.character_effect().family, &"vanish")
	_view._show_player_ability(SkillDefinition.catalog(&"divine_shield_1"))
	assert_eq(_view.character_effect().family, &"divine_shield")
	_view._show_player_ability(SkillDefinition.catalog(&"evasion_1"))
	assert_eq(_view.character_effect().family, &"evasion")
	_view._process(1.5)
	assert_eq(_view.character_effect().family, &"vanish")
	_view._draw_player()
	assert_almost_eq(_view.base_color.a, 0.4, 0.000001)


func test_poison_trigger_uses_new_art_without_tick_refresh_and_loses_to_ground() -> void:
	_world.hero.learn_skill(SkillDefinition.catalog(&"deadly_poison_1"))
	PoisonRules.apply_deadly(_world, _enemy)
	_view._draw_actor(_enemy)
	assert_eq((_view.base as AtlasTexture).region, Rect2(32, 64, 16, 16))
	_view._process(1.0)
	_world.wait_turn()
	assert_almost_eq(float(_view._npc_blinks[_enemy][&"poison_trigger"].elapsed), 1.0, 0.000001)
	assert_true(_world.cast_skill(&"consecration_1"))
	assert_eq(_view.character_effect(_enemy).family, &"consecration")
	PoisonRules.apply_deadly(_world, _enemy)
	assert_eq(_view.character_effect(_enemy).family, &"consecration")
	_view._process(1.5)
	assert_true(_view._npc_blinks.is_empty())


class RecordingGridView:
	extends GridView

	var base: Texture2D
	var faction: Texture2D
	var base_color: Color
	var faction_color: Color
	var effect_tiles: Array[Vector2i] = []


	func _draw_sprite_layers(tile: Vector2i, base_texture: Texture2D,
		faction_texture: Texture2D, color: Color, relationship_color: Color,
		_offset: Vector2 = Vector2.ZERO) -> void:
		base = base_texture
		faction = faction_texture
		base_color = color
		faction_color = relationship_color
		if base_texture == _ability_sprite(CONSECRATION_CELL):
			effect_tiles.append(tile)
