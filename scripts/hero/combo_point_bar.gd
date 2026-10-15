extends Control

const BACKGROUND_COLOR := Color(0.055, 0.06, 0.05, 0.25)
const BORDER_COLOR := Color(0.5, 0.5, 0.45, 1.0)
const FILL_COLOR := Color(0.72, 0.58, 0.18, 1.0)

var _points: int = 0


func refresh(hero: HeroState) -> void:
	_points = clampi(hero.combo_points, 0, HeroState.MAX_COMBO_POINTS)
	modulate.a = 0.2 if _points == 0 else 0.8
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	var cell_width := size.x / HeroState.MAX_COMBO_POINTS
	for index in range(_points):
		var left := index * cell_width + 1.0
		var right := minf((index + 1) * cell_width, size.x - 1.0)
		draw_rect(Rect2(left, 1.0, right - left, size.y - 2.0), FILL_COLOR)
	draw_rect(Rect2(0.0, 0.0, size.x, 1.0), BORDER_COLOR)
	draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), BORDER_COLOR)
	for index in range(HeroState.MAX_COMBO_POINTS + 1):
		var left := minf(index * cell_width, size.x - 1.0)
		draw_rect(Rect2(left, 1.0, 1.0, size.y - 2.0), BORDER_COLOR)
