class_name NpcTarget
extends RefCounted

## A selected enemy target is either the hero or one of the hero's summoned actors.
var actor: GridActor
var tile: Vector2i:
	get:
		return _world.player_tile if is_player() else actor.tile
var melee: MeleeProfile:
	get:
		return _world.hero.melee if is_player() else actor.melee
var facing: Vector2i:
	get:
		return _world.hero.facing if is_player() else actor.facing
var title: String:
	get:
		return "You" if is_player() else actor.title
var alive: bool:
	get:
		return _world.hero.health > 0 if is_player() else actor.alive
var _world: GridWorld


func _init(world: GridWorld, selected_actor: GridActor) -> void:
	_world = world
	actor = selected_actor


func is_player() -> bool:
	return actor == null


func has_evasion() -> bool:
	return is_player() and _world.hero.buffs.has(&"evasion_1")


func take_damage(amount: int, result: StringName) -> void:
	if is_player():
		var hero := _world.hero
		hero.health = maxi(0, hero.health - amount)
		if amount > 0 and hero.last_hit_rage_turn != _world.turn_count:
			hero.gain_rage(HeroState.INCOMING_RAGE_PER_TURN)
			hero.last_hit_rage_turn = _world.turn_count
	else:
		actor.health = maxi(0, actor.health - amount)
		_world.npc_combat_text.emit(actor.tile, amount, result)
		_world._check_npc_death(actor, _world.turn_count)


func retaliate(attacker: GridActor, amount: int, critical: bool) -> void:
	ClassSpellEffects.retaliate(_world, attacker, actor, amount)
	if is_player():
		ClassToolkitRules.incoming(_world, attacker, amount, critical)
