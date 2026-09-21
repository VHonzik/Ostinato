class_name MovementGame
extends Node2D

const MOVE_ACTIONS: Array[StringName] = [
	&"move_north", &"move_northeast", &"move_east", &"move_southeast",
	&"move_south", &"move_southwest", &"move_west", &"move_northwest",
]

## Brief presentation gap makes FR-010 cancellation possible without another confirmation.
const MELEE_BOUNDARY_SECONDS: float = 0.18

var world: GridWorld
var session := GameSession.new()
var menu: MenuPanel
var active_game: bool = false
var _pending_action: bool = false
var _pending_direction := Vector2i.ZERO
var _pending_arrow: bool = false
var _melee_delay_seconds: float = 0.0

@onready var grid_view: GridView = $GridView
@onready var camera: Camera2D = $Camera2D
@onready var combat_panel: CombatPanel = $HUD/CombatPanel
@onready var hero_panel: HeroPanel = $HUD/HeroPanel
@onready var _cancel_attack: Button = $HUD/Top/Rows/Heading/CancelAttack
@onready var _status: Label = $HUD/Top/Rows/Status
@onready var _hero_status: Label = $HUD/Top/Rows/HeroStatus
@onready var _chat: RichTextLabel = $HUD/Bottom/Rows/Chat
@onready var _feedback: Label = $HUD/Bottom/Rows/Feedback
@onready var _speed_buttons: Array[Button] = [
	$HUD/Top/Rows/Heading/Slow, $HUD/Top/Rows/Heading/Normal, $HUD/Top/Rows/Heading/Fast,
]


func _ready() -> void:
	menu = MenuPanel.new()
	menu.session = session
	$HUD.add_child(menu)
	menu.theme = hero_panel.theme
	menu.new_game_requested.connect(start_new_game)
	menu.return_to_menu_requested.connect(_return_to_menu)
	menu.refreshed.connect(refresh_view)
	menu.fullscreen_changed.connect(_apply_fullscreen)
	session.world_changed.connect(_adopt_world)
	combat_panel.service_requested.connect(_open_service)
	menu.options.load_options()
	_apply_fullscreen()
	get_tree().auto_accept_quit = false
	_cancel_attack.pressed.connect(_cancel_pending_melee)
	combat_panel.action_taken.connect(refresh_view)
	combat_panel.visibility_changed.connect(_on_combat_panel_visibility_changed)
	combat_panel.selection_changed.connect(_select_actor)
	hero_panel.cast_requested.connect(_cast_skill)
	hero_panel.visibility_changed.connect(_on_hero_panel_visibility_changed)
	$HUD/Top/Rows/HeroStatus/Character.pressed.connect(_open_hero_panel.bind(false))
	$HUD/Top/Rows/HeroStatus/Spells.pressed.connect(_open_hero_panel.bind(true))
	world = MovementFixture.create_world()
	grid_view.world = world
	menu.open_main()
	$HUD/Top.hide()
	$HUD/Bottom.hide()
	grid_view.hide()
	for index in range(_speed_buttons.size()):
		_speed_buttons[index].pressed.connect(_set_speed.bind([0.5, 1.0, 1.5][index]))
	$HUD/Top/Rows/Heading/Reset.pressed.connect(_open_options)


func _process(delta: float) -> void:
	if not active_game or menu.visible:
		return
	if world.pending_skill != null:
		_melee_delay_seconds -= delta
		if _melee_delay_seconds <= 0.0:
			world.continue_cast()
			refresh_view()
		return
	if world.pending_melee != null:
		_melee_delay_seconds -= delta
		if _melee_delay_seconds <= 0.0:
			world.continue_melee()
			if world.pending_melee == null:
				_feedback.text = "Attack ended. Choose your next action."
			refresh_view()
		return
	if not _pending_action:
		return
	_pending_action = false
	if (world.is_player_dead() or world.pending_melee != null
		or combat_panel.visible or hero_panel.visible
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
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("fullscreen") and menu._capture_action == &"":
			menu.toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
		if menu.visible:
			_pending_action = false
			menu.handle_key(event)
			get_viewport().set_input_as_handled()
			return
	if menu.visible or not active_game:
		return
	if world.pending_skill != null:
		_pending_action = false
		if event is InputEventKey and event.is_pressed():
			if not event.is_echo() and event.is_action_pressed("ui_cancel"):
				world.cancel_cast()
				refresh_view()
			get_viewport().set_input_as_handled()
		return
	if world.pending_melee != null:
		_pending_action = false
		if event is InputEventKey and event.is_pressed():
			if not event.is_echo() and event.is_action_pressed("ui_cancel"):
				_cancel_pending_melee()
			get_viewport().set_input_as_handled()
		return
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
	if menu.visible or not active_game:
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		else:
			_open_options()
		_pending_action = false
		get_viewport().set_input_as_handled()
		return
	if (world.is_player_dead() or world.pending_melee != null
		or combat_panel.visible or hero_panel.visible
		or get_viewport().gui_get_focus_owner() != null):
		return
	if event.is_action_pressed("options"):
		_open_options()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		_pending_action = false
		menu.open_inventory()
		get_viewport().set_input_as_handled()
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
				_pending_arrow = (event.physical_keycode in [KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]
						and _default_arrow_bindings())
				_pending_action = true
				matched = true
				break
		if not matched:
			return
	# Collect same-frame arrow presses into a single diagonal action.
	get_viewport().set_input_as_handled()


func reset_fixture() -> void:
	# Development restart is an explicit new game, not a death path.
	start_new_game()


func start_new_game() -> void:
	active_game = true
	menu.active_game = true
	menu.close()
	session.new_game()
	$HUD/Top.show()
	$HUD/Bottom.show()
	grid_view.show()
	refresh_view()


func _adopt_world() -> void:
	hero_panel.close()
	combat_panel.close()
	world = session.world
	active_game = true
	menu.active_game = true
	world.message_added.connect(_refresh_chat)
	grid_view.world = world
	grid_view.show()
	$HUD/Top.show()
	$HUD/Bottom.show()
	_pending_action = false
	_melee_delay_seconds = 0.0
	_update_speed_buttons()
	_refresh_chat("")
	_feedback.text = "F: interact / I: outfit / K: spells / Esc: options"
	refresh_view()


func _return_to_menu() -> void:
	world.cancel_melee()
	world.cancel_cast()
	_pending_action = false
	active_game = false
	hero_panel.close()
	combat_panel.close()
	$HUD/Top.hide()
	$HUD/Bottom.hide()
	grid_view.hide()
	session.world = null


func _open_options() -> void:
	_pending_action = false
	menu.open_options()


func _open_service(service: StringName) -> void:
	if service == &"Marshal":
		menu.open_marshal()
	else:
		menu.open_trainer(service)


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_FULLSCREEN if menu.options.fullscreen else Window.MODE_WINDOWED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and menu != null:
		menu.request_exit()


func refresh_view() -> void:
	if world.is_player_dead():
		_pending_action = false
		hero_panel.close()
		if session.world != world:
			session.world = world
		session.restart_after_death()
		return
	elif world.pending_skill != null:
		_pending_action = false
		_melee_delay_seconds = MELEE_BOUNDARY_SECONDS
		_feedback.text = "Casting %s. Esc cancels." % world.pending_skill.title
	elif world.pending_melee != null:
		_pending_action = false
		_melee_delay_seconds = MELEE_BOUNDARY_SECONDS
		_select_actor(world.pending_melee)
		_feedback.text = "Attacking %s. Waiting for swing; Esc cancels." % world.pending_melee.title
	else:
		_melee_delay_seconds = 0.0
		if not combat_panel.visible:
			_select_actor(null)
	_cancel_attack.visible = world.pending_melee != null or world.pending_skill != null
	grid_view.alternate_palette = menu.options.alternate_palette
	$HUD/Top/Rows/HeroStatus/Character.text = "Character (%s)" % menu.options.key_label(&"character")
	$HUD/Top/Rows/HeroStatus/Spells.text = "Spells (%s)" % menu.options.key_label(&"spell_book")
	camera.position = GridView.tile_center(world.player_tile)
	camera.force_update_scroll()
	grid_view.queue_redraw()
	var hero := world.hero
	_hero_status.text = "Lv %d  XP %d/%d   HP %d/%d   Mana %d/%d" % [
		hero.level, hero.experience, hero.experience_to_next_level(),
		hero.health, hero.max_health, hero.mana, hero.max_mana,
	]
	hero_panel.refresh()
	_status.text = "Loop %d  |  Turn %d  |  Tile %d, %d  |  Speed %.1f  |  Credit %.1f" % [
		session.loop_count, world.turn_count, world.player_tile.x, world.player_tile.y,
		world.movement_speed, world.movement_credit,
	]


func _set_speed(speed: float) -> void:
	if world.is_player_dead() or world.pending_melee != null or world.pending_skill != null:
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
	if (world.is_player_dead() or world.pending_melee != null
		or world.pending_skill != null or combat_panel.visible):
		return
	_pending_action = false
	hero_panel.open(world.hero, spell_book)


func _cast_skill(identifier: StringName) -> void:
	_pending_action = false
	var skill := world.hero.find_skill(identifier)
	if skill == null:
		return
	if skill.target in [SkillRank.Target.ENEMY, SkillRank.Target.ALLY]:
		hero_panel.close()
		combat_panel.open_spell(world, skill)
	else:
		if not skill.development_only:
			hero_panel.close()
		world.cast_skill(identifier)
	refresh_view()


func _refresh_chat(_message: String) -> void:
	_chat.text = "\n".join(world.messages)


func _on_hero_panel_visibility_changed() -> void:
	_feedback.visible = not hero_panel.visible
	$HUD/Bottom/Rows/Legend.visible = not hero_panel.visible
	var controls := $HUD/Bottom/Rows/Controls as Label
	controls.text = (
		"A/D: tabs   Â·   W/S or Tab: select   Â·   Enter: activate   Â·   Esc: close"
		if hero_panel.visible else
		"Move: WASD + QEZC / arrows / numpad   Â·   Wait: . / numpad 5"
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
	else:
		for index in range(MOVE_ACTIONS.size()):
			if event.is_action_pressed(MOVE_ACTIONS[index]):
				combat_panel.navigate(GridWorld.DIRECTIONS[index])
				break
	get_viewport().set_input_as_handled()


func _on_combat_panel_visibility_changed() -> void:
	$HUD/Bottom.visible = not combat_panel.visible


func _cancel_pending_melee() -> void:
	world.cancel_melee()
	world.cancel_cast()
	_pending_action = false
	_melee_delay_seconds = 0.0
	_feedback.text = "Attack canceled. Elapsed turns remain spent."
	refresh_view()



func _default_arrow_bindings() -> bool:
	for pair in [[&"move_north", KEY_UP], [&"move_east", KEY_RIGHT],
		[&"move_south", KEY_DOWN], [&"move_west", KEY_LEFT]]:
		var bound := false
		for event in InputMap.action_get_events(pair[0]):
			if event is InputEventKey and event.physical_keycode == pair[1]:
				bound = true
		if not bound:
			return false
	return true
