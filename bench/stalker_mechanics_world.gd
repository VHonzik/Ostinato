extends "res://bench/priority_world.gd"
## Experimental encounter only; production combat, timers and random draws stay live.

var tuning: Dictionary = {}
var boss: GridActor
var last_boss_health: int = 0
var boss_damage: int = 0
var boss_healing: int = 0
var channel_started: bool = false
var channel_active: bool = false
var channel_turn: int = -1
var channel_deadline: int = -1
var channel_start_damage: int = 0
var channel_damage: int = 0
var channel_success: bool = false
var start_resources: Dictionary = {}
var timeline: Array[Dictionary] = []


func _spawn_stalker(entry: Vector2i) -> void:
	super._spawn_stalker(entry)
	boss = actors[-1]
	last_boss_health = boss.health


func add_message(message: String) -> void:
	if boss != null:
		boss_damage += maxi(0, last_boss_health - boss.health)
		last_boss_health = boss.health
		boss.melee.damage_multiplier = (1.3 if tuning.get("enrage", false)
			and boss.health * 5 <= boss.max_health else 1.0)
	super.add_message(message)


func _advance_player_weapon() -> void:
	super._advance_player_weapon()
	if boss == null or not boss.alive or is_terminal():
		return
	# Isolate the experimental variants from the subsequently adopted live breath.
	# stalker_patterns_world supplies its own cone, cadence and measurements.
	boss.breath_normal_turns = 0
	if tuning.get("channel", false) and not channel_started and boss.health * 2 <= boss.max_health:
		_start_channel()
	if channel_active:
		boss.stunned_until = turn_count + 1


func _finish_turn() -> void:
	super._finish_turn()
	if boss == null:
		return
	# Summons act after the player's weapons; their threshold crossings also count.
	if (boss.alive and not is_terminal() and tuning.get("channel", false)
		and not channel_started and boss.health * 2 <= boss.max_health):
		_start_channel()
	if not channel_active:
		return
	if turn_count == channel_turn:
		# Exclude every source on the triggering boundary, including later summons.
		channel_start_damage = boss_damage
		start_resources = {"hp": hero.health, "rage": hero.rage,
			"stacks": ClassToolkitRules.maelstrom_stacks(hero), "points": hero.combo_points,
			"boss_hp": boss.health, "turn": turn_count,
			"ms_ready_in": maxi(0, int(hero.cooldowns.get("mortal_strike", 0)) - turn_count),
			"judge_ready_in": maxi(0, int(hero.cooldowns.get("judgement", 0)) - turn_count),
			"lava_ready_in": maxi(0, int(hero.cooldowns.get("lava_burst", 0)) - turn_count)}
		return
	channel_damage = boss_damage - channel_start_damage
	timeline.append({"turn": turn_count, "damage": channel_damage,
		"boss_hp": boss.health, "hp": hero.health})
	if not boss.alive or is_terminal() or turn_count >= channel_deadline:
		channel_success = channel_damage >= int(tuning.get("requirement", 0)) or not boss.alive
		channel_active = false
		if boss.alive and not is_terminal() and not channel_success:
			var amount := mini(int(tuning.get("heal", 0)), boss.max_health - boss.health)
			boss.health += amount
			boss_healing += amount
			last_boss_health = boss.health
			if previous_hp.has(boss.title):
				previous_hp[boss.title] = boss.health
			add_message("Experimental regeneration restores %d HP." % amount)


func _start_channel() -> void:
	channel_started = true
	channel_active = true
	channel_turn = turn_count
	channel_deadline = turn_count + 4


func encounter_metrics() -> Dictionary:
	return {"boss_damage": boss_damage, "boss_healing": boss_healing,
		"channel_started": channel_started, "channel_damage": channel_damage,
		"channel_success": channel_success, "channel_turn": channel_turn,
		"start_resources": start_resources, "channel_timeline": timeline}
