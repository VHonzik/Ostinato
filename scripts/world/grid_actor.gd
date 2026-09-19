class_name GridActor
extends RefCounted

## Array order in GridWorld is the stable NPC turn order (FR-013).
var tile: Vector2i
var alive: bool = true
var wander_area: Rect2i


func _init(start_tile: Vector2i, area: Rect2i = Rect2i()) -> void:
	tile = start_tile
	wander_area = area
