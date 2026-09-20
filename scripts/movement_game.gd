class_name MovementGame
extends Node2D

const MOVE_ACTIONS: Array[StringName] = [
	&"move_north", &"move_northeast", &"move_east", &"move_southeast",
	&"move_south", &"move_southwest", &"move_west", &"move_northwest",
]

var world: GridWorld
var _pending_action: bool = false
var _pending_direction := Vector2i.ZERO
var _pending_arrow: bool = false

@onready var grid_view: GridView = $GridView
@onready var camera: Camera2D = $Camera2D
@onready var combat_panel: CombatPanel = $HUD/CombatPanel
@onready var hero_panel: HeroPanel = $HUD/HeroPanel
@onready var _status: Label = $HUD/Top/Rows/Status
@onready var _hero_status: Label = $HUD/Top/Rows/HeroStatus
@onready var _chat: RichTextLabel = $HUD/Bottom/Rows/Chat
@onready var _feedback: Label = $HUD/Bottom/Rows/Feedback
@onready var _speed_buttons: Array[Button] = [
	$HUD/Top/Rows/Heading/Slow, $HUD/Top/Rows/Heading/Normal, $HUD/Top/Rows/Heading/Fast,
]


func _ready() -> void:
	combat_panel.action_taken.connect(refresh_view)
	combat_panel.visibility_changed.connect(_on_combat_panel_visibility_changed)
	combat_panel.reset_requested.connect(reset_fixture)
	combat_panel.selection_changed.connect(_select_actor)
	hero_panel.cast_requested.connect(_cast_skill)
	hero_panel.visibility_changed.connect(_on_hero_panel_visibility_changed)
	$HUD/Top/Rows/HeroStatus/Character.pressed.connect(_open_hero_panel.bind(false))
	$HUD/Top/Rows/HeroStatus/Spells.pressed.connect(_open_hero_panel.bind(true))
	reset_fixture()
	for index in range(_speed_buttons.size()):
		_speed_buttons[index].pressed.connect(_set_speed.bind([0.5, 1.0, 1.5][index]))
	$HUD/Top/Rows/Heading/Reset.pressed.connect(reset_fixture)


func _process(_delta: float) -> void:
	if not _pending_action:
		return
	_pending_action = false
	if (world.is_player_dead() or combat_panel.visible or hero_panel.visible
		or get_viewport().gui_get_focus_owner() != null):
		return
	var direction := _pending_direction
	if _pending_arrow:
		var arrows := Vector2i(
			int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT)),
			int(Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_UP))
		)
		if arrows != Vector2i.ZERO:
			direction = arrows
	if direction == Vector2i.ZERO:
		world.wait_turn()
		_feedback.text = "Waited one turn. The meadow stirs."
	elif world.move_player(direction):
		_feedback.text = "Action complete. F interacts; hostile bumps request melee."
	else:
		_feedback.text = "Blocked. No time or movement credit spent."
	refresh_view()


func _input(event: InputEvent) -> void:
	if combat_panel.visible:
		_handle_combat_input(event)
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if hero_panel.visible:
		_pending_action = false
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("spell_book"):
			hero_panel.close()
		elif event.is_action_pressed("character"):
			_open_hero_panel(false)
		elif event.is_action_pressed("ui_focus_next", false, true):
			hero_panel.navigate(true)
		elif event.is_action_pressed("ui_focus_prev", false, true):
			hero_panel.navigate(false)
		elif event.is_action_pressed("move_east"):
			hero_panel.change_tab(1)
		elif event.is_action_pressed("move_west"):
			hero_panel.change_tab(-1)
		elif event.is_action_pressed("wait"):
			pass
		else:
			var matched := false
			for index in range(MOVE_ACTIONS.size()):
				if event.is_action_pressed(MOVE_ACTIONS[index]):
					hero_panel.navigate(index in [3, 4, 5])
					matched = true
					break
			if not matched:
				return
		get_viewport().set_input_as_handled()
	elif not world.is_player_dead() and get_viewport().gui_get_focus_owner() == null:
		if event.is_action_pressed("character") or event.is_action_pressed("spell_book"):
			_open_hero_panel(event.is_action_pressed("spell_book"))
			get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		_pending_action = false
		get_viewport().set_input_as_handled()
		return
	if (world.is_player_dead() or combat_panel.visible or hero_panel.visible
		or get_viewport().gui_get_focus_owner() != null):
		return
	if event.is_action_pressed("interact"):
		_pending_action = false
		combat_panel.open_interaction(world)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wait"):
		_pending_direction = Vector2i.ZERO
		_pending_arrow = false
		_pending_action = true
	else:
		var matched := false
		for index in range(MOVE_ACTIONS.size()):
			if event.is_action_pressed(MOVE_ACTIONS[index]):
				_pending_direction = GridWorld.DIRECTIONS[index]
				_pending_arrow = event.physical_keycode in [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]
				_pending_action = true
				matched = true
				break
		if not matched:
			return
	# Collect same-frame arrow presses into a single diagonal action.
	get_viewport().set_input_as_handled()


func reset_fixture() -> void:
	hero_panel.close()
	combat_panel.close()
	world = MovementFixture.create_world()
	world.message_added.connect(_refresh_chat)
	world.add_message("Welcome, mage. F interacts. Neutral wolf south; hostile wolves east.")
	grid_view.world = world
	_pending_action = false
	_feedback.text = "You are the blue outline. Walk over the remains just west of you."
	_update_speed_buttons()
	refresh_view()


func refresh_view() -> void:
	if world.is_player_dead():
		_pending_action = false
		hero_panel.close()
		combat_panel.show_death()
	elif world.pending_melee != null:
		_pending_action = false
		combat_panel.show_pending(world)
	camera.position = GridView.tile_center(world.player_tile)
	camera.force_update_scroll()
	grid_view.queue_redraw()
	var hero := world.hero
	_hero_status.text = "Lv %d  XP %d/%d   HP %d/%d   Mana %d/%d" % [
		hero.level, hero.experience, hero.experience_to_next_level(),
		hero.health, hero.max_health, hero.mana, hero.max_mana,
	]
	hero_panel.refresh()
	_status.text = "Turn %d  |  Tile %d, %d  |  Speed %.1f  |  Credit %.1f" % [
		world.turn_count, world.player_tile.x, world.player_tile.y,
		world.movement_speed, world.movement_credit,
	]


func _set_speed(speed: float) -> void:
	if world.is_player_dead():
		return
	world.movement_speed = speed
	_update_speed_buttons()
	_feedback.text = "Speed changed; credit retained. Press Esc to return to movement."
	refresh_view()


func _update_speed_buttons() -> void:
	for index in range(_speed_buttons.size()):
		_speed_buttons[index].set_pressed_no_signal(
			is_equal_approx(world.movement_speed, [0.5, 1.0, 1.5][index])
		)


func _open_hero_panel(spell_book: bool) -> void:
	if world.is_player_dead() or combat_panel.visible:
		return
	_pending_action = false
	hero_panel.open(world.hero, spell_book)


func _cast_skill(identifier: StringName) -> void:
	_pending_action = false
	world.cast_skill(identifier)
	refresh_view()


func _refresh_chat(_message: String) -> void:
	_chat.text = "\n".join(world.messages)


func _on_hero_panel_visibility_changed() -> void:
	_feedback.visible = not hero_panel.visible
	$HUD/Bottom/Rows/Legend.visible = not hero_panel.visible
	var controls := $HUD/Bottom/Rows/Controls as Label
	controls.text = (
		"A/D: tabs   ·   W/S or Tab: select   ·   Enter: activate   ·   Esc: close"
		if hero_panel.visible else
		"Move: WASD + QEZC / arrows / numpad   ·   Wait: . / numpad 5"
	)


func _select_actor(actor: GridActor) -> void:
	grid_view.selected = actor
	grid_view.queue_redraw()


func _handle_combat_input(event: InputEvent) -> void:
	_pending_action = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tile := Vector2i((get_global_mouse_position() / GridView.TILE_SIZE).floor())
		combat_panel.select_tile(tile)
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		combat_panel.cancel()
	elif event.is_action_pressed("ui_accept"):
		combat_panel.confirm()
	elif event.is_action_pressed("ui_focus_next", false, true):
		combat_panel.focus_next(false)
	elif event.is_action_pressed("ui_focus_prev", false, true):
		combat_panel.focus_next(true)
	else:
		for index in range(MOVE_ACTIONS.size()):
			if event.is_action_pressed(MOVE_ACTIONS[index]):
				combat_panel.navigate(GridWorld.DIRECTIONS[index])
				break
	get_viewport().set_input_as_handled()


func _on_combat_panel_visibility_changed() -> void:
	$HUD/Bottom.visible = not combat_panel.visible
