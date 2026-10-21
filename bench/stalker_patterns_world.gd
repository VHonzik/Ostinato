extends "res://bench/stalker_mechanics_world.gd"

var cone_active: bool = false
var cone_origin: Vector2i
var cone_direction: Vector2i
var cone_deadline: int = -1
var normal_turns: int = 0
var cone_casts: int = 0
var cone_impacts: int = 0
var cone_hits: int = 0
var cone_immune: int = 0
var cone_damage: int = 0
var cone_pet_kills: int = 0
var dodge_steps: int = 0
var cancelled_casts: int = 0
var cone_trace: Array[Dictionary] = []
var enrage_turn: int = -1
var enrage_player_hp: int = 0
var enrage_start_damage: int = 0
var enrage_incoming: int = 0


func add_message(message: String) -> void:
	if boss != null and boss.alive and boss.health * 5 <= boss.max_health and enrage_turn < 0:
		enrage_turn = turn_count
		enrage_player_hp = hero.health
		enrage_start_damage = raw_damage_taken
	super.add_message(message)
	if enrage_turn >= 0:
		enrage_incoming = raw_damage_taken - enrage_start_damage


func _start_channel() -> void:
	if not cone_active:
		super._start_channel()


func _advance_player_weapon() -> void:
	super._advance_player_weapon()
	if boss == null or not boss.alive or is_terminal():
		return
	if cone_active:
		boss.stunned_until = turn_count + 1
		# NpcRules' held turn subtracts one: retain a fresh interval throughout the breath.
		boss.swing.remaining = boss.melee.interval + 1.0
		if turn_count >= cone_deadline:
			_resolve_cone()
		return
	if channel_active or not tuning.get("cone", false) or not boss.engaged:
		return
	if boss.stunned_until > turn_count or VanishRules.active(self):
		return
	var delay := int(tuning.get("cone_gap", 10)) if cone_casts > 0 else 4
	if normal_turns < delay:
		normal_turns += 1
		return
	cone_active = true
	cone_origin = boss.tile
	cone_direction = MeleeRules.direction_toward(player_tile - boss.tile)
	cone_deadline = turn_count + 2
	cone_casts += 1
	normal_turns = 0
	boss.stunned_until = turn_count + 1
	boss.swing.remaining = boss.melee.interval + 1.0
	cone_trace.append({"start": turn_count, "deadline": cone_deadline,
		"origin": [cone_origin.x, cone_origin.y],
		"direction": [cone_direction.x, cone_direction.y]})


func threatens(tile: Vector2i) -> bool:
	var offset := tile - cone_origin
	var forward := offset.x * cone_direction.x + offset.y * cone_direction.y
	var side := absi(offset.x * cone_direction.y - offset.y * cone_direction.x)
	return (GridWorld.tile_distance(tile, cone_origin) <= 3
		and forward > 0 and side <= forward and has_sight(cone_origin, tile))


func _resolve_cone() -> void:
	cone_active = false
	cone_impacts += 1
	var targets: Array[GridActor] = [null]
	for actor in actors:
		if actor.alive and actor.summon_kind != "":
			targets.append(actor)
	for actor in targets:
		var target := NpcTarget.new(self, actor)
		if not target.alive or not threatens(target.tile):
			continue
		# Fixed 60 base Fire damage, with live level scaling and defenses. No crit/dodge.
		var raw := floori(60.0 * boss.melee.damage_multiplier
			* MeleeRules.level_damage_multiplier(boss.melee.level, target.melee.level))
		var amount := ClassSpellEffects.absorb(self, actor, raw, false)
		if actor == null:
			cone_hits += int(amount > 0)
			cone_immune += int(amount == 0)
			cone_damage += amount
		target.take_damage(amount, &"hit")
		add_message("Fel Breath -> %s: hit, %d damage." % [target.title, amount])
		if actor != null and not actor.alive:
			cone_pet_kills += 1
		if check_terminal():
			return
		if target.alive:
			if actor == null:
				ClassToolkitRules.on_damage_taken(self, amount)
			target.retaliate(boss, amount)
		if is_terminal():
			return


func encounter_metrics() -> Dictionary:
	var result := super.encounter_metrics()
	result.merge({"cone_casts": cone_casts, "cone_impacts": cone_impacts,
		"cone_hits": cone_hits, "cone_immune": cone_immune, "cone_damage": cone_damage,
		"cone_pet_kills": cone_pet_kills, "dodge_steps": dodge_steps,
		"cancelled_casts": cancelled_casts, "cone_trace": cone_trace,
		"enrage_turn": enrage_turn, "enrage_player_hp": enrage_player_hp,
		"enrage_incoming": enrage_incoming})
	return result
