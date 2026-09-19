extends Control

## NFR-002: use every whole logical pixel, including space left by integer scaling.
## A SubViewportContainer also leaves remainder pixels in the project's clear color.
const BASE_SIZE := Vector2i(640, 360)

@onready var _container: SubViewportContainer = $GameContainer
@onready var _game_viewport: SubViewport = $GameContainer/GameViewport


func _ready() -> void:
	get_window().min_size = BASE_SIZE
	resized.connect(_resize_viewport)
	_resize_viewport()


func _resize_viewport() -> void:
	var content_size := Vector2i(size)
	var pixel_scale := maxi(1, mini(content_size.x / BASE_SIZE.x, content_size.y / BASE_SIZE.y))
	var logical_size := Vector2i(content_size.x / pixel_scale, content_size.y / pixel_scale)
	_game_viewport.size = logical_size
	_container.scale = Vector2.ONE * pixel_scale
	_container.position = Vector2((content_size - logical_size * pixel_scale) / 2)
