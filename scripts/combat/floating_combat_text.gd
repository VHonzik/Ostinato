class_name FloatingCombatText
extends Node2D

const FONT: Font = preload("res://assets/KenneyPixel.ttf")
const FONT_SIZE: int = 24
const LIFETIME_SECONDS: float = 1.4
const FADE_SECONDS: float = 0.65
const GRAVITY: float = 160.0

var _entries: Array[Entry] = []
var _random := RandomNumberGenerator.new()
var _next_direction: float = -1.0


func _init() -> void:
	z_index = 10
	_random.randomize()


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	for index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[index]
		entry.elapsed += delta
		if entry.elapsed >= LIFETIME_SECONDS:
			_entries.remove_at(index)
			continue
		entry.position += entry.velocity * delta + Vector2(0.0, GRAVITY * delta * delta / 2.0)
		entry.velocity.y += GRAVITY * delta
	queue_redraw()


func _draw() -> void:
	for entry in _entries:
		var color := entry.color
		color.a = clampf((LIFETIME_SECONDS - entry.elapsed) / FADE_SECONDS, 0.0, 1.0)
		var width := FONT.get_string_size(entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var baseline := entry.position - Vector2(width / 2.0, 0.0)
		draw_string_outline(FONT, baseline, entry.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, FONT_SIZE, 2, Color(0.05, 0.05, 0.05, color.a))
		draw_string(FONT, baseline, entry.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func spawn(tile: Vector2i, amount: int, result: StringName) -> void:
	var entry := Entry.new()
	entry.text = String(result).capitalize() if result in [&"miss", &"dodge"] else str(amount)
	entry.color = Color("#e8e8e8") if result in [&"miss", &"dodge"] else (
		Color("#ffd36a") if result == &"critical" else Color.WHITE)
	entry.position = GridView.tile_center(tile) - Vector2(0.0, GridView.TILE_SIZE / 2.0 + 8.0)
	entry.velocity = Vector2(_next_direction * _random.randf_range(18.0, 26.0),
		_random.randf_range(-78.0, -66.0))
	_next_direction *= -1.0
	_entries.append(entry)
	queue_redraw()


func clear() -> void:
	_entries.clear()
	_next_direction = -1.0
	queue_redraw()


class Entry extends RefCounted:
	var text: String
	var color: Color
	var position: Vector2
	var velocity: Vector2
	var elapsed: float = 0.0
