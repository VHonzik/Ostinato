extends Control

const BACKGROUND_COLOR := Color(0.055, 0.06, 0.05, 0.25)
const BORDER_COLOR := Color(0.5, 0.5, 0.45, 1.0)
const FILL_COLOR := Color(0.58, 0.25, 0.82, 1.0)
const MAX_STACKS: int = 5

var _stacks: int = 0


func refresh(hero: HeroState) -> void:
	_stacks = clampi(ClassToolkitRules.maelstrom_stacks(hero), 0, MAX_STACKS)
	modulate.a = 0.2 if _stacks == 0 else 0.8
	tooltip_text = "Maelstrom Weapon: %d/%d" % [_stacks, MAX_STACKS]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	if _stacks > 0:
		var right := minf(size.x * _stacks / MAX_STACKS, size.x - 1.0)
		draw_rect(Rect2(1.0, 1.0, right - 1.0, size.y - 2.0), FILL_COLOR)
	draw_rect(Rect2(0.0, 0.0, size.x, 1.0), BORDER_COLOR)
	draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), BORDER_COLOR)
	for boundary: int in [0, 1, 4, 5]:
		var left := minf(size.x * boundary / MAX_STACKS, size.x - 1.0)
		draw_rect(Rect2(left, 1.0, 1.0, size.y - 2.0), BORDER_COLOR)
