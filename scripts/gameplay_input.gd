class_name GameplayInput
extends RefCounted

## Platform input owns holds; Gameplay owns action gates and the turn queue.
var game: Gameplay


func clear() -> void:
	pass


func process_movement(_delta: float) -> void:
	pass


func resolve_direction(direction: Vector2i) -> Vector2i:
	return direction


func handle_input(_event: InputEvent) -> void:
	pass


func handle_key(_event: InputEvent) -> void:
	pass
