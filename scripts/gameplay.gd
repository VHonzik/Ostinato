class_name Gameplay
extends Node2D

const MOVE_ACTIONS: Array[StringName] = [
	&"move_north", &"move_northeast", &"move_east", &"move_southeast",
	&"move_south", &"move_southwest", &"move_west", &"move_northwest",
]

## Brief presentation gap makes cancellation possible without another confirmation.
const MELEE_BOUNDARY_SECONDS: float = 0.18

var world: GridWorld
var session := GameSession.new()
var menu: MenuPanel
var hotbar_panel: HotbarPanel
var active_game: bool = false
var _pending_action: bool = false
var _pending_direction := Vector2i.ZERO
var _pending_arrow: bool = false
var _melee_delay_seconds: float = 0.0

@onready var grid_view: GridView = $GridView
@onready var camera: Camera2D = $Camera2D
@onready var combat_panel: CombatPanel = $HUD/CombatPanel
@onready var hero_panel: HeroPanel = $HUD/HeroPanel
@onready var _cancel_attack: Button = $HUD/Top/Rows/CancelAttack
@onready var _status: Label = $HUD/Top/Rows/Status
@onready var _hero_status: Label = $HUD/Top/Rows/HeroStatus
@onready var _chat: RichTextLabel = $HUD/Bottom/Rows/Chat
@onready var _feedback: Label = $HUD/Bottom/Rows/Feedback


func _ready() -> void:
	hotbar_panel = HotbarPanel.new()
	hotbar_panel.theme = hero_panel.theme
	$HUD.add_child(hotbar_panel)
	hotbar_panel.slot_pressed.connect(_hotbar_slot_pressed)
	hotbar_panel.rank_dropped.connect(_assign_hotbar)
	hotbar_panel.lock_requested.connect(_toggle_hotbar_lock)
	hero_panel.slot_chosen.connect(_hotbar_slot_pressed)
	hero_panel.assignment_changed.connect(_refresh_hotbar)
	hero_panel.lock_requested.connect(_toggle_hotbar_lock)
	menu = MenuPanel.new()
	menu.session = session
	$HUD.add_child(menu)
	menu.theme = hero_panel.theme
	menu.new_game_requested.connect(start_new_game)
	menu.return_to_menu_requested.connect(_return_to_menu)
	menu.refreshed.connect(refresh_view)
	menu.fullscreen_changed.connect(_apply_fullscreen)
	menu.hero_requested.connect(_open_hero_panel)
	session.world_changed.connect(_adopt_world)
	combat_panel.service_requested.connect(_open_service)
	combat_panel.conversation_requested.connect(menu.open_conversation)
	combat_panel.loot_requested.connect(menu.open_loot)
	menu.visibility_changed.connect(_refresh_hotbar)
	menu.options.load_options()
	_apply_fullscreen()
	get_tree().auto_accept_quit = false
	_cancel_attack.pressed.connect(_cancel_pending_melee)
	combat_panel.action_taken.connect(refresh_view)
	combat_panel.visibility_changed.connect(_on_combat_panel_visibility_changed)
	combat_panel.selection_changed.connect(_select_actor)
	hero_panel.cast_requested.connect(_cast_skill)
	hero_panel.visibility_changed.connect(_on_hero_panel_visibility_changed)
	$HUD/PlayerMenu/Buttons/PlayerMenu.pressed.connect(_open_player_menu)
	$HUD/PlayerMenu/Buttons/Character.pressed.connect(_open_hero_panel.bind(false))
	$HUD/PlayerMenu/Buttons/Spells.pressed.connect(_open_hero_panel.bind(true))
	$HUD/PlayerMenu/Buttons/Inventory.pressed.connect(_open_inventory)
	$HUD/PlayerMenu/Buttons/Interact.pressed.connect(_open_interaction)
	$HUD/PlayerMenu/Buttons/Quests.pressed.connect(func() -> void:
		if _hotbar_can_edit() and not hero_panel.visible:
			_pending_action = false
			menu.open_quest_log())
	world = MovementFixture.create_world()
	grid_view.world = world
	menu.open_main()
	$HUD/Top.hide()
	$HUD/Bottom.hide()
	$HUD/PlayerMenu.hide()
	$HUD/Auras.hide()
	grid_view.hide()
	hotbar_panel.hide()


func _process(delta: float) -> void:
	if not active_game or menu.visible or world.is_terminal():
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
	if (world.is_terminal() or world.pending_melee != null
		or world.pending_skill != null or combat_panel.visible or hero_panel.visible
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
		_feedback.text = "Action complete."
	else:
		var contact := world.actor_at(world.player_tile + direction)
		_feedback.text = "Interacted with %s." % contact.title if (
			contact != null and contact.relationship == GridActor.Relationship.FRIENDLY
		) else "Blocked. No time or movement credit spent."
	refresh_view()


func _input(event: InputEvent) -> void:
	if active_game and world.is_charging():
		_pending_action = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("fullscreen", false, true) and menu._capture_action == &"":
			menu.toggle_fullscreen()
			get_viewport().set_input_as_handled()
			return
		if menu.visible:
			_pending_action = false
			menu.handle_key(event)
			get_viewport().set_input_as_handled()
			return
	if menu.visible or not active_game or world.is_terminal():
		return
	if world.pending_skill != null:
		_pending_action = false
		if event is InputEventKey and event.is_pressed():
			if not event.is_echo() and event.is_action_pressed("ui_cancel", false, true):
				world.cancel_cast()
				refresh_view()
			get_viewport().set_input_as_handled()
		return
	if world.pending_melee != null:
		_pending_action = false
		if event is InputEventKey and event.is_pressed():
			if not event.is_echo() and event.is_action_pressed("ui_cancel", false, true):
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
		if hero_panel.handle_assignment_key(event):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel", false, true) or event.is_action_pressed("spell_book", false, true):
			hero_panel.close()
		elif event.is_action_pressed("character", false, true):
			_open_hero_panel(false)
		elif event.is_action_pressed("ui_focus_next", false, true):
			hero_panel.navigate(true, true)
		elif event.is_action_pressed("ui_focus_prev", false, true):
			hero_panel.navigate(false, true)
		elif event.is_action_pressed("move_east", false, true):
			hero_panel.change_tab(1)
		elif event.is_action_pressed("move_west", false, true):
			hero_panel.change_tab(-1)
		elif event.is_action_pressed("wait", false, true):
			pass
		else:
			var matched := false
			for index in range(MOVE_ACTIONS.size()):
				if event.is_action_pressed(MOVE_ACTIONS[index], false, true):
					hero_panel.navigate(index in [3, 4, 5])
					matched = true
					break
			if not matched:
				return
		get_viewport().set_input_as_handled()
	elif not world.is_terminal() and get_viewport().gui_get_focus_owner() == null:
		if event.is_action_pressed("character", false, true) or event.is_action_pressed("spell_book", false, true):
			_open_hero_panel(event.is_action_pressed("spell_book", false, true))
			get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if menu.visible or not active_game or world.is_terminal():
		return
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel", false, true):
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		else:
			_open_options()
		_pending_action = false
		get_viewport().set_input_as_handled()
		return
	if (world.is_terminal() or world.pending_melee != null
		or world.pending_skill != null or combat_panel.visible or hero_panel.visible
		or get_viewport().gui_get_focus_owner() != null):
		return
	for index in range(world.hotbar.size()):
		if event.is_action_pressed("hotbar_%d" % (index + 1), false, true):
			_hotbar_slot_pressed(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("player_menu", false, true):
		_open_player_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("options", false, true):
		_open_options()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quest_log", false, true):
		_pending_action = false
		menu.open_quest_log()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory", false, true):
		_open_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact", false, true):
		_open_interaction()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wait", false, true):
		_pending_direction = Vector2i.ZERO
		_pending_arrow = false
		_pending_action = true
	else:
		var matched := false
		for index in range(MOVE_ACTIONS.size()):
			if event.is_action_pressed(MOVE_ACTIONS[index], false, true):
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
	hero_panel.clear_selection()
	active_game = true
	menu.active_game = true
	menu.close()
	session.new_game()
	$HUD/Top.show()
	$HUD/Bottom.show()
	grid_view.show()
	refresh_view()


func _adopt_world() -> void:
	menu.close()
	hero_panel.close()
	combat_panel.close()
	combat_panel.clear_spell_target()
	world = session.world
	active_game = true
	menu.active_game = true
	world.message_added.connect(_refresh_chat)
	world.friendly_interaction_requested.connect(_interact_with_friendly)
	grid_view.world = world
	grid_view.show()
	$HUD/Top.show()
	$HUD/Bottom.show()
	_pending_action = false
	_melee_delay_seconds = 0.0
	_refresh_chat("")
	_feedback.text = ""
	refresh_view()


func _return_to_menu() -> void:
	world.discard()
	_pending_action = false
	active_game = false
	hero_panel.close()
	combat_panel.close()
	$HUD/Top.hide()
	$HUD/Bottom.hide()
	$HUD/PlayerMenu.hide()
	$HUD/Auras.hide()
	grid_view.hide()
	hotbar_panel.hide()
	session.world = null


func _open_options() -> void:
	if world.is_charging():
		return
	_pending_action = false
	menu.open_options()


func _interact_with_friendly(actor: GridActor) -> void:
	_pending_action = false
	combat_panel.interact_with(world, actor)


func _open_service(actor: GridActor) -> void:
	var service := actor.service
	if service == &"Marshal":
		menu.open_marshal()
	elif service == &"Trader":
		menu.open_trade(actor)
	else:
		menu.open_trainer(service)


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_FULLSCREEN if menu.options.fullscreen else Window.MODE_WINDOWED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and menu != null:
		menu.request_exit()


func refresh_view() -> void:
	world.check_terminal()
	if world.attempt_state == GridWorld.AttemptState.COMPLETED:
		_pending_action = false
		_melee_delay_seconds = 0.0
		hero_panel.close()
		combat_panel.close()
		combat_panel.clear_spell_target()
		_cancel_attack.hide()
		hotbar_panel.hide()
		$HUD/Top.hide()
		$HUD/Bottom.hide()
		$HUD/PlayerMenu.hide()
		$HUD/Auras.hide()
		grid_view.queue_redraw()
		if menu.active_game or not menu.visible:
			menu.open_completion()
		return
	if world.attempt_state == GridWorld.AttemptState.PLAYER_DIED:
		_pending_action = false
		hero_panel.close()
		if session.world != world:
			session.world = world
		session.restart_after_death()
		return
	elif world.pending_skill != null:
		_pending_action = false
		_melee_delay_seconds = MELEE_BOUNDARY_SECONDS
		_feedback.text = "Charging. Actions resume on arrival." if world.is_charging() else (
			"Casting %s. Esc cancels." % world.pending_skill.title)
	elif world.pending_melee != null:
		_pending_action = false
		_melee_delay_seconds = MELEE_BOUNDARY_SECONDS
		_select_actor(world.pending_melee)
		_feedback.text = "%s on %s. Waiting for swing; Esc cancels." % [
			"Attack" if world.queued_strike == null else "Heroic Strike queued",
			world.pending_melee.title]
	else:
		_melee_delay_seconds = 0.0
		if not combat_panel.visible:
			_select_actor(world.auto_attack_target)
	_cancel_attack.visible = (world.pending_melee != null or world.pending_skill != null)
	_cancel_attack.disabled = world.is_charging()
	grid_view.alternate_palette = menu.options.alternate_palette
	$HUD/PlayerMenu/Buttons/PlayerMenu.text = "Menu (%s)" % menu.options.key_label(&"player_menu")
	$HUD/PlayerMenu/Buttons/Character.text = "Character (%s)" % menu.options.key_label(&"character")
	$HUD/PlayerMenu/Buttons/Spells.text = "Spells (%s)" % menu.options.key_label(&"spell_book")
	$HUD/PlayerMenu/Buttons/Inventory.text = "Inventory (%s)" % menu.options.key_label(&"inventory")
	$HUD/PlayerMenu/Buttons/Interact.text = "Interact (%s)" % menu.options.key_label(&"interact")
	$HUD/PlayerMenu/Buttons/Quests.text = "Quests (%s)" % menu.options.key_label(&"quest_log")
	camera.position = GridView.tile_center(world.player_tile)
	camera.force_update_scroll()
	grid_view.queue_redraw()
	var hero := world.hero
	_hero_status.text = "HP %d/%d   Rage %d/%d\nLv %d  XP %d/%d" % [
		hero.health, hero.max_health, hero.rage, HeroState.MAX_RAGE,
		hero.level, hero.experience, hero.experience_to_next_level(),
	]
	hero_panel.refresh()
	_refresh_hotbar()
	var effects: PackedStringArray = []
	for identifier in hero.buffs:
		var skill := hero.find_skill(StringName(identifier))
		var title := skill.title if skill != null else String(identifier).capitalize()
		effects.append("%s (%dt)" % [title, int(hero.buffs[identifier].until) - world.turn_count])
	for identifier in hero.debuffs:
		effects.append("%s (%dt)" % [String(identifier).capitalize(),
			int(hero.debuffs[identifier].until) - world.turn_count])
	$HUD/Auras.text = " · ".join(effects)
	_status.text = "Turn %d  ·  Loop %d" % [world.turn_count, session.loop_count]


func _open_player_menu() -> void:
	if not _hotbar_can_edit() or hero_panel.visible:
		return
	_pending_action = false
	menu.open_player()


func _open_interaction() -> void:
	if not _hotbar_can_edit() or hero_panel.visible:
		return
	_pending_action = false
	combat_panel.open_interaction(world)


func _open_inventory() -> void:
	if (not active_game or world.is_terminal() or world.pending_melee != null
		or world.pending_skill != null or combat_panel.visible or hero_panel.visible):
		return
	_pending_action = false
	menu.open_inventory()


func _open_hero_panel(spell_book: bool) -> void:
	if (world.is_terminal() or world.pending_melee != null
		or world.pending_skill != null or combat_panel.visible):
		return
	_pending_action = false
	hero_panel.layout_locked = world.hotbar_locked
	hero_panel.open(world.hero, spell_book)
	_refresh_hotbar()


func _cast_skill(identifier: StringName) -> void:
	if not active_game or world.is_terminal():
		return
	_pending_action = false
	var skill := world.hero.find_skill(identifier)
	if skill == null:
		return
	if (skill.effect in [SkillRank.Effect.MORTAL_STRIKE, SkillRank.Effect.HEROIC_STRIKE]
		and world.in_combat()
		and world.last_attacked_enemy != null):
		hero_panel.close()
		combat_panel.close()
		world.cast_skill(identifier)
	elif skill.target in [SkillRank.Target.ENEMY, SkillRank.Target.ALLY]:
		hero_panel.close()
		combat_panel.open_spell(world, skill)
	else:
		combat_panel.clear_spell_target()
		if not skill.development_only:
			hero_panel.close()
		world.cast_skill(identifier)
	refresh_view()


func _refresh_chat(_message: String) -> void:
	_chat.text = "\n".join(world.messages)


func _on_hero_panel_visibility_changed() -> void:
	$HUD/Bottom.visible = active_game and not hero_panel.visible and not combat_panel.visible
	_refresh_hotbar()
	_feedback.visible = not hero_panel.visible


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
	if event.is_action_pressed("ui_cancel", false, true):
		combat_panel.cancel()
	elif event.is_action_pressed("ui_accept", false, true):
		combat_panel.confirm()
	else:
		for index in range(MOVE_ACTIONS.size()):
			if event.is_action_pressed(MOVE_ACTIONS[index], false, true):
				combat_panel.navigate(GridWorld.DIRECTIONS[index])
				break
	get_viewport().set_input_as_handled()


func _on_combat_panel_visibility_changed() -> void:
	$HUD/Bottom.visible = active_game and not combat_panel.visible and not hero_panel.visible
	_refresh_hotbar()


func _cancel_pending_melee() -> void:
	if world.is_charging():
		return
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


func _hotbar_can_edit() -> bool:
	return (active_game and world != null and not world.is_terminal() and not menu.visible
		and not combat_panel.visible and world.pending_skill == null and world.pending_melee == null)


func _refresh_hotbar() -> void:
	if hotbar_panel == null or world == null or menu == null:
		return
	hotbar_panel.visible = (active_game and not world.is_terminal()
		and not combat_panel.visible and not menu.visible)
	$HUD/PlayerMenu.visible = hotbar_panel.visible and not hero_panel.visible
	$HUD/Auras.visible = hotbar_panel.visible and not hero_panel.visible
	var can_edit := _hotbar_can_edit()
	hotbar_panel.refresh(world, menu.options, can_edit and not hero_panel.visible,
		can_edit, hero_panel.choosing_slot)
	hero_panel.layout_locked = world.hotbar_locked
	hero_panel.refresh()


func _hotbar_slot_pressed(slot: int) -> void:
	if not _hotbar_can_edit() or slot < 0 or slot >= world.hotbar.size():
		return
	if hero_panel.visible:
		if hero_panel.choosing_slot:
			_assign_hotbar(slot, hero_panel.assignment_id, world.hero)
		return
	# Slot buttons do not take focus or bypass an existing UI owner.
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		return
	_cast_skill(world.hotbar[slot])


func _assign_hotbar(slot: int, identifier: StringName, source_hero: HeroState) -> void:
	if not _hotbar_can_edit() or source_hero != world.hero:
		return
	if world.assign_hotbar(slot, identifier):
		hero_panel.finish_assignment()
		_refresh_hotbar()


func _toggle_hotbar_lock() -> void:
	if not _hotbar_can_edit():
		return
	world.hotbar_locked = not world.hotbar_locked
	if hero_panel.visible:
		hero_panel.finish_assignment()
	else:
		hotbar_panel.lock_button.release_focus()
	_refresh_hotbar()
