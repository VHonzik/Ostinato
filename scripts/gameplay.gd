class_name Gameplay
extends Node2D

signal view_refreshed

const MOVE_ACTIONS: Array[StringName] = [
	&"move_north", &"move_northeast", &"move_east", &"move_southeast",
	&"move_south", &"move_southwest", &"move_west", &"move_northwest",
]

## Brief presentation gap makes cancellation possible without another confirmation.
const MELEE_BOUNDARY_SECONDS: float = 0.18
const MOVE_REPEAT_DELAY_SECONDS: float = 0.5
const MOVE_REPEAT_INTERVAL_SECONDS: float = 0.15

var world: GridWorld
var session := GameSession.new()
var menu: MenuPanel
var hotbar_panel: HotbarPanel
var active_game: bool = false
var input_adapter: GameplayInput
var suspended: bool = false
var _pending_action: bool = false
var _pending_direction := Vector2i.ZERO
var _pending_arrow: bool = false
var _melee_delay_seconds: float = 0.0

@onready var hud: GameplayHud = $HUD
@onready var grid_view: GridView = $GridView
@onready var camera: Camera2D = $Camera2D
@onready var combat_panel: CombatPanel = $HUD/CombatPanel
@onready var hero_panel: HeroPanel = $HUD/HeroPanel


func _ready() -> void:
	input_adapter = create_input()
	input_adapter.game = self
	grid_view.melee_bumps_finished.connect(_refresh_hotbar)
	hotbar_panel = create_hotbar()
	hotbar_panel.theme = hero_panel.theme
	$HUD.add_child(hotbar_panel)
	hotbar_panel.slot_pressed.connect(_hotbar_slot_pressed)
	hotbar_panel.skill_dropped.connect(_assign_hotbar)
	hotbar_panel.lock_requested.connect(_toggle_hotbar_lock)
	hero_panel.slot_chosen.connect(_hotbar_slot_pressed)
	hero_panel.assignment_changed.connect(_refresh_hotbar)
	hero_panel.lock_requested.connect(_toggle_hotbar_lock)
	menu = create_menu()
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
	hud.cancel_attack.pressed.connect(_cancel_pending_melee)
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
	hud.hide_game()
	grid_view.hide()
	hotbar_panel.hide()


func _process(delta: float) -> void:
	if suspended or not active_game or menu.visible or world.is_terminal():
		_clear_movement_hold()
		return
	world.screen_size_tiles = get_viewport_rect().size / camera.zoom / GridView.TILE_SIZE
	if grid_view.is_melee_bumping():
		_pending_action = false
		_clear_movement_hold()
		return
	if world.pending_skill != null:
		_clear_movement_hold()
		_melee_delay_seconds -= delta
		if _melee_delay_seconds <= 0.0:
			world.continue_cast()
			refresh_view()
		return
	if world.pending_melee != null:
		_clear_movement_hold()
		_melee_delay_seconds -= delta
		if _melee_delay_seconds <= 0.0:
			world.continue_melee()
			if world.pending_melee == null:
				hud.feedback.text = "Attack ended. Choose your next action."
			refresh_view()
		return
	if (world.is_terminal() or world.pending_melee != null
		or world.pending_skill != null or combat_panel.visible or hero_panel.visible
		or hud.get_viewport().gui_get_focus_owner() != null):
		_pending_action = false
		_clear_movement_hold()
		return
	input_adapter.process_movement(delta)
	if not _pending_action:
		return
	_pending_action = false
	var direction := input_adapter.resolve_direction(_pending_direction)
	if direction == Vector2i.ZERO:
		world.wait_turn()
		hud.feedback.text = "Waited one turn. The meadow stirs."
	elif world.move_player(direction):
		hud.feedback.text = ""
	else:
		var contact := world.actor_at(world.player_tile + direction)
		hud.feedback.text = "Interacted with %s." % contact.title if (
			contact != null and contact.relationship == GridActor.Relationship.FRIENDLY
		) else "Blocked. No time or movement credit spent."
	refresh_view()


func _clear_movement_hold() -> void:
	if input_adapter != null:
		input_adapter.clear()


func reset_fixture() -> void:
	# Development restart is an explicit new game, not a death path.
	start_new_game()


func start_new_game(chosen_seed: int = -1) -> void:
	hero_panel.clear_selection()
	active_game = true
	menu.active_game = true
	menu.close()
	session.new_game(chosen_seed)
	hud.show_game()
	grid_view.show()
	refresh_view()


func _adopt_world() -> void:
	_clear_movement_hold()
	menu.close()
	hero_panel.close()
	combat_panel.close()
	combat_panel.clear_spell_target()
	world = session.world
	active_game = true
	menu.active_game = true
	world.message_added.connect(_refresh_chat)
	world.friendly_interaction_requested.connect(_interact_with_actor)
	world.loot_interaction_requested.connect(_interact_with_actor)
	grid_view.world = world
	grid_view.show()
	hud.show_game()
	_pending_action = false
	_melee_delay_seconds = 0.0
	_refresh_chat("")
	hud.feedback.text = ""
	refresh_view()


func _return_to_menu() -> void:
	_clear_movement_hold()
	world.discard()
	_pending_action = false
	active_game = false
	hero_panel.close()
	combat_panel.close()
	hud.hide_game()
	grid_view.hide()
	hotbar_panel.hide()
	session.world = null


func _open_options() -> void:
	if world.is_charging() or grid_view.is_melee_bumping():
		return
	_pending_action = false
	menu.open_options()


func _interact_with_actor(actor: GridActor) -> void:
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pending_action = false
		_clear_movement_hold()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and menu != null:
		menu.request_exit()


func refresh_view() -> void:
	world.check_terminal()
	if (world.is_terminal() or _actions_blocked()
		or menu.visible or combat_panel.visible or hero_panel.visible):
		_clear_movement_hold()
	if world.attempt_state == GridWorld.AttemptState.COMPLETED:
		_pending_action = false
		_melee_delay_seconds = 0.0
		hero_panel.close()
		combat_panel.close()
		combat_panel.clear_spell_target()
		hud.cancel_attack.hide()
		hotbar_panel.hide()
		hud.hide_game()
		grid_view.queue_redraw()
		if menu.active_game or not menu.visible:
			menu.open_completion()
		view_refreshed.emit()
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
		hud.feedback.text = "Charging. Actions resume on arrival." if world.is_charging() else (
			"Casting %s: %d/%d turns. Esc cancels." % [world.pending_skill.title,
				world.cast_elapsed, world.cast_turns])
	elif world.pending_melee != null:
		_pending_action = false
		_melee_delay_seconds = MELEE_BOUNDARY_SECONDS
		_select_actor(world.pending_melee)
		hud.feedback.text = "Attack on %s. Waiting for swing; Esc cancels." % world.pending_melee.title
	else:
		_melee_delay_seconds = 0.0
		if not combat_panel.visible:
			_select_actor(world.auto_attack_target)
	hud.cancel_attack.visible = (world.pending_melee != null or world.pending_skill != null)
	hud.cancel_attack.disabled = world.is_charging()
	grid_view.alternate_palette = menu.options.alternate_palette
	camera.position = GridView.tile_center(world.player_tile)
	camera.force_update_scroll()
	world.screen_size_tiles = get_viewport_rect().size / camera.zoom / GridView.TILE_SIZE
	grid_view.queue_redraw()
	hero_panel.refresh()
	_refresh_hotbar()
	hud.refresh(world, session.loop_count, menu.options)
	view_refreshed.emit()


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
	if (not active_game or world.is_terminal() or _actions_blocked()
		or combat_panel.visible or hero_panel.visible):
		return
	_pending_action = false
	menu.open_inventory()


func _open_hero_panel(spell_book: bool) -> void:
	if world.is_terminal() or _actions_blocked() or combat_panel.visible:
		return
	_pending_action = false
	hero_panel.layout_locked = world.hotbar_locked
	hero_panel.open(world.hero, spell_book)
	_refresh_hotbar()


func _cast_skill(identifier: StringName) -> void:
	if not active_game or world.is_terminal() or grid_view.is_melee_bumping():
		return
	_pending_action = false
	if identifier == ItemData.WAR_BANNER_HOTBAR_ID:
		world.use_war_banner()
		refresh_view()
		return
	if identifier == ItemData.ANCESTRAL_TOTEM_HOTBAR_ID:
		world.use_ancestral_totem()
		refresh_view()
		return
	if identifier == ItemData.WAR_HORN_HOTBAR_ID:
		world.use_war_horn()
		refresh_view()
		return
	if ItemData.is_consumable_hotbar(identifier):
		world.consume_hotbar_item(identifier)
		refresh_view()
		return
	var skill := world.hero.find_skill(identifier)
	if skill == null:
		return
	if world.turn_count < int(world.hero.cooldowns.get(String(skill.family), 0)):
		combat_panel.close()
		world.add_message("%s is on cooldown." % skill.title)
		refresh_view()
		return
	var target := world.committed_enemy()
	if PoisonRules.is_poison(skill) and world.hero.has_off_hand_weapon():
		hero_panel.close()
		combat_panel.open_poison(world, skill)
	elif skill.family == &"lava_burst":
		hero_panel.close()
		combat_panel.open_spell(world, skill)
	elif (skill.effect in [SkillDefinition.Effect.MORTAL_STRIKE,
		SkillDefinition.Effect.EXECUTE, SkillDefinition.Effect.TOOLKIT,
		SkillDefinition.Effect.JUDGEMENT]
		and skill.target == SkillDefinition.Target.ENEMY
		and world.in_combat()
		and target != null):
		hero_panel.close()
		combat_panel.close()
		world.cast_skill(identifier)
	elif skill.target in [SkillDefinition.Target.ENEMY, SkillDefinition.Target.ALLY]:
		hero_panel.close()
		combat_panel.open_spell(world, skill)
	else:
		combat_panel.clear_spell_target()
		if not skill.development_only:
			hero_panel.close()
		world.cast_skill(identifier)
	refresh_view()


func _refresh_chat(_message: String) -> void:
	hud.refresh_chat(world)


func _on_hero_panel_visibility_changed() -> void:
	hud.refresh_overlay(active_game, hero_panel.visible, combat_panel.visible)
	_refresh_hotbar()


func _select_actor(actor: GridActor) -> void:
	grid_view.selected = actor
	grid_view.queue_redraw()


func _on_combat_panel_visibility_changed() -> void:
	hud.refresh_overlay(active_game, hero_panel.visible, combat_panel.visible)
	_refresh_hotbar()


func _cancel_pending_melee() -> void:
	if world.is_charging():
		return
	world.cancel_melee()
	world.cancel_cast()
	_pending_action = false
	_melee_delay_seconds = 0.0
	hud.feedback.text = "Attack canceled. Elapsed turns remain spent."
	refresh_view()



func _actions_blocked() -> bool:
	return (world.pending_skill != null or world.pending_melee != null
		or grid_view.is_melee_bumping())


func _hotbar_can_edit() -> bool:
	return (active_game and world != null and not world.is_terminal() and not menu.visible
		and not combat_panel.visible and not _actions_blocked())


func _refresh_hotbar() -> void:
	if hotbar_panel == null or world == null or menu == null:
		return
	hotbar_panel.visible = (active_game and not world.is_terminal()
		and not combat_panel.visible and not menu.visible)
	hud.refresh_resources(world, hotbar_panel.visible and not hero_panel.visible)
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
	var focused := hud.get_viewport().gui_get_focus_owner()
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


func create_input() -> GameplayInput:
	return DesktopGameplayInput.new()


func create_menu() -> MenuPanel:
	return MenuPanel.new()


func create_hotbar() -> HotbarPanel:
	return HotbarPanel.new()


func _input(event: InputEvent) -> void:
	if not suspended and input_adapter != null:
		input_adapter.handle_input(event)


func _unhandled_key_input(event: InputEvent) -> void:
	if not suspended and input_adapter != null:
		input_adapter.handle_key(event)


func can_move() -> bool:
	return (not suspended and _hotbar_can_edit() and not hero_panel.visible
		and hud.get_viewport().gui_get_focus_owner() == null)


func request_move(direction: Vector2i) -> bool:
	if not can_move() or _pending_action or absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	_pending_direction = direction
	_pending_arrow = false
	_pending_action = true
	return true


func stop_movement() -> void:
	_pending_action = false
	_clear_movement_hold()


func request_slot(slot: int) -> void:
	stop_movement()
	if not suspended:
		_hotbar_slot_pressed(slot)


func request_menu() -> void:
	stop_movement()
	if not suspended:
		_open_player_menu()


func request_interact() -> void:
	stop_movement()
	if not suspended:
		_open_interaction()
