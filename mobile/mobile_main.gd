extends Control

@onready var game: Gameplay = $GameContainer/GameViewport/Gameplay
@onready var _world_container: SubViewportContainer = $GameContainer
@onready var _world_viewport: SubViewport = $GameContainer/GameViewport
@onready var _ui_container: SubViewportContainer = $UiContainer
@onready var _ui_viewport: SubViewport = $UiContainer/UiViewport
var controls: Control
var _resume: Control


func _ready() -> void:
	# The simulation/camera and HUD have independent viewport transforms.
	game.hud.reparent(_ui_viewport)
	controls = preload("res://mobile/mobile_controls.gd").new()
	controls.game = game
	game.hud.add_child(controls)
	resized.connect(_layout)
	_layout()
	_style_panels()
	game.combat_panel.visibility_changed.connect(_style_panels)


func _layout() -> void:
	if size.x < 1 or size.y < 1:
		return
	var safe := Rect2(Vector2.ZERO, size)
	if DisplayServer.get_name() == "Android":
		safe = safe.intersection(Rect2(DisplayServer.get_display_safe_area()))
	if not safe.has_area():
		return
	game.stop_movement()
	var ui_scale := minf(safe.size.x / 1280.0, safe.size.y / 720.0)
	var ui_size := Vector2i((safe.size / ui_scale).floor())
	_ui_viewport.size = ui_size
	_ui_container.scale = Vector2.ONE * ui_scale
	_ui_container.position = safe.position
	# All target coordinates refer to the same unobscured rectangle.
	_world_container.position = safe.position
	var world_scale := safe.size.y / 720.0
	_world_container.scale = Vector2.ONE * world_scale
	_world_viewport.size = Vector2i((safe.size / world_scale).floor())
	_style_panels()


func _style_panels() -> void:
	var panel := game.combat_panel
	panel._panel.position = Vector2(32, 180)
	panel._panel.size = Vector2(panel.size.x - 64, 260)
	panel._detail.custom_minimum_size.x = panel.size.x - 96
	panel._detail.text = panel._detail.text.replace("Enter", "Confirm").replace("Esc", "Cancel")
	for button in [panel._confirm, panel._cancel, panel._previous, panel._next]:
		button.custom_minimum_size = Vector2(160, 56)
		button.text = button.text.replace(" (Enter)", "").replace(" (Esc)", "")
	game.hud.cancel_attack.text = "Cancel"
	game.hud.cancel_attack.custom_minimum_size.y = 48


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		suspend()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		controls.back()


func suspend() -> void:
	if game.suspended:
		return
	game.stop_movement()
	game.checkpoint()
	game.suspended = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_resume = Control.new()
	_resume.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resume.mouse_filter = Control.MOUSE_FILTER_STOP
	game.hud.add_child(_resume)
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resume.add_child(background)
	var button := Button.new()
	button.text = "Resume"
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.offset_left = -160
	button.offset_right = 160
	button.offset_top = -40
	button.offset_bottom = 40
	button.add_theme_font_size_override("font_size", 32)
	button.pressed.connect(resume_game)
	_resume.add_child(button)


func resume_game() -> void:
	game.stop_movement()
	game.suspended = false
	game.process_mode = Node.PROCESS_MODE_INHERIT
	if _resume != null:
		_resume.queue_free()
		_resume = null
	controls.refresh()
