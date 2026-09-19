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
	# NFR-002 requires rounding down to whole scales and whole logical pixels.
	var scale_x := float(content_size.x) / BASE_SIZE.x
	var scale_y := float(content_size.y) / BASE_SIZE.y
	var pixel_scale := maxi(1, floori(minf(scale_x, scale_y)))
	var logical_size := Vector2i((Vector2(content_size) / pixel_scale).floor())
	_game_viewport.size = logical_size
	_container.scale = Vector2.ONE * pixel_scale
	var remainder := Vector2(content_size - logical_size * pixel_scale)
	_container.position = (remainder / 2.0).floor()
