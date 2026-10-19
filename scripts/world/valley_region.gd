@tool
class_name ValleyRegion
extends Node2D

@export var location_id: StringName = &""
@export var size_tiles := Vector2i.ONE:
	set(value):
		size_tiles = value
		queue_redraw()


func tile_bounds() -> Rect2i:
	return Rect2i(Vector2i((position / 32.0).floor()), size_tiles)


func _draw() -> void:
	if Engine.is_editor_hint():
		var rectangle := Rect2(Vector2.ZERO, Vector2(size_tiles * 32))
		draw_rect(rectangle, Color(0.3, 0.65, 1.0, 0.08))
		draw_rect(rectangle, Color(0.3, 0.65, 1.0, 0.7), false, 1.0)
