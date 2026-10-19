extends "res://bench/priority_world.gd"
## Observe each real world turn, including bump-to-swing continuation turns.

var timeline: Array[Dictionary] = []


func _finish_turn() -> void:
	var before := turn_count
	super._finish_turn()
	if turn_count == before or watched.is_empty():
		return
	var living := 0
	var adjacent := 0
	for enemy in watched:
		if enemy.alive:
			living += 1
			adjacent += int(GridWorld.tile_distance(player_tile, enemy.tile) <= 1)
	timeline.append({"turn": turn_count, "hp": hero.health, "living": living,
		"adjacent": adjacent, "damage": damage_total, "taken": raw_damage_taken,
		"healing": healing_total, "rage": hero.rage})
