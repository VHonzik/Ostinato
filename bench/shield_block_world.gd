extends "res://bench/priority_world.gd"
## Experiment only. The copied turn/NPC attack paths insert block before HP loss.
## Disabled runs must replay exactly against production GridWorld.

var block_enabled: bool = false
var block_random := RandomNumberGenerator.new()
var block_rolls: int = 0
var blocks: int = 0
var prevented: int = 0
var eligible_damage: int = 0


func _finish_turn() -> void:
	if is_terminal() and not resolving_turn:
		return
	turn_count += 1
	resolving_turn = true
	if check_terminal():
		pending_melee = null
		cancel_cast(true)
		resolving_turn = false
		return
	_tick_effects()
	if check_terminal():
		pending_melee = null
		cancel_cast(true)
		resolving_turn = false
		return
	_advance_player_weapon()
	if check_terminal():
		resolving_turn = false
		return
	hero.refresh_stats()
	NpcRules.acquire_hostiles(self)
	for actor in actors:
		if not actor.alive:
			continue
		if actor.summon_kind != "":
			SummonRules.act(self, actor)
		else:
			_enemy_act(actor)
		if check_terminal():
			pending_melee = null
			cancel_cast(true)
			resolving_turn = false
			return
	_regenerate()
	_tick_restoration()
	_arrive_stalker()
	NpcRules.acquire_hostiles(self)
	resolving_turn = false
	combo_event_counted = false
	maelstrom_event_counted = false
	for actor in actors:
		_hide_empty_corpse(actor)
		if not actor.alive and not actor.chest and not actor.story_guard and actor.died_on_turn >= 0:
			if turn_count - actor.died_on_turn >= 300:
				actor.corpse_visible = false


func _enemy_act(actor: GridActor) -> void:
	if actor.stunned_until > turn_count:
		actor.swing.advance(false, actor.melee.interval)
		return
	var target := NpcTarget.new(self, SummonRules.enemy_target(self, actor))
	NpcRules._move(self, actor, target.tile)
	var in_melee := (actor.engaged and GridWorld.tile_distance(actor.tile, target.tile) == 1
		and has_sight(actor.tile, target.tile))
	var swings := actor.swing.advance(in_melee, actor.melee.interval)
	for index in range(swings):
		if is_terminal():
			return
		_enemy_attack(actor, target)
		if is_terminal() or not target.alive or not actor.alive:
			return


func _enemy_attack(actor: GridActor, target: NpcTarget) -> void:
	if target.is_player():
		melee_attacked.emit(actor, target.tile)
	var result := MeleeRules.outcome(actor.melee, target.melee,
		combat_random.randf() * 100.0)
	var amount := MeleeRules.damage(actor.melee, target.melee, result, combat_random.randf())
	amount = ClassSpellEffects.absorb(self, target.actor, amount, true)
	if target.is_player():
		amount = _block_damage(amount)
	target.take_damage(amount, result)
	add_message("%s -> %s: %s, %d damage." % [actor.title, target.title, result, amount])
	if check_terminal():
		add_message("You died.")
		return
	if not target.alive:
		return
	if target.is_player():
		ClassToolkitRules.on_damage_taken(self, amount)
	target.retaliate(actor, amount)


func _block_damage(amount: int) -> int:
	if (not block_enabled or amount <= 0 or not hero.equipment.has("weapons")
		or not ItemData.get_item(hero.weapon_id()).shield):
		return amount
	block_rolls += 1
	eligible_damage += amount
	if block_random.randf() >= 0.3:
		return amount
	blocks += 1
	var remaining := ceili(amount * 0.3)
	assert(remaining >= 1 and remaining <= amount)
	prevented += amount - remaining
	return remaining


func metrics() -> Dictionary:
	var result := super.metrics()
	result.merge({"block_rolls": block_rolls, "blocks": blocks,
		"prevented": prevented, "eligible_damage": eligible_damage})
	return result
