extends Control

var progress: float = 1.0


func _ready() -> void:
	var rage_bar := get_node_or_null("../RageBar") as Control
	if rage_bar != null:
		rage_bar.item_rect_changed.connect(_layout.bind(rage_bar))
		_layout(rage_bar)


func refresh(hero: HeroState) -> void:
	var interval := maxf(0.01, hero.melee.interval / hero.attack_haste())
	progress = clampf(1.0 - hero.swing.remaining / interval, 0.0, 1.0)
	queue_redraw()


func _layout(rage_bar: Control) -> void:
	position = rage_bar.position
	size = Vector2(rage_bar.size.x, 0.0)


func _draw() -> void:
	draw_rect(Rect2(0.0, -1.5, size.x * progress, 3.0), Color.WHITE)
