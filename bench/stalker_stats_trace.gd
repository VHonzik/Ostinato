extends "res://bench/restless_trace_world.gd"

const StatsWorld = preload("res://bench/stalker_stats_world.gd")
var profile: Dictionary = {}


func _spawn_stalker(entry: Vector2i) -> void:
	super._spawn_stalker(entry)
	StatsWorld.apply_profile(actors.back(), profile)
