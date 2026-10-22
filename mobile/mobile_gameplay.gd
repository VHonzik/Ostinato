extends Gameplay

var recovery := MobileRecoveryStore.new()
var _checkpoint_pending: bool = false


func create_input() -> GameplayInput:
	return MobileGameplayInput.new()


func create_menu() -> MenuPanel:
	var panel := preload("res://mobile/mobile_menu.gd").new()
	panel.recovery = recovery
	return panel


func create_hotbar() -> HotbarPanel:
	return preload("res://mobile/mobile_hotbar.gd").new()


func _ready() -> void:
	super._ready()
	(hud as MobileGameplayHud).attach_hotbar(hotbar_panel)
	view_refreshed.connect(func() -> void: _checkpoint_pending = true)
	# Menus can change state without advancing a world turn (training/equipment/assignments).
	hero_panel.assignment_changed.connect(func() -> void: _checkpoint_pending = true)
	menu.connect("item_assignment_requested", func(identifier: StringName) -> void:
		_open_hero_panel(false)
		hero_panel.assignment_id = identifier
		hero_panel.choosing_slot = true
		_refresh_hotbar())


func _process(delta: float) -> void:
	super._process(delta)
	if _checkpoint_pending and not suspended:
		_checkpoint_pending = false
		checkpoint()


func checkpoint() -> void:
	if not active_game or session.world == null:
		return
	var success := (recovery.invalidate() if world.attempt_state == GridWorld.AttemptState.COMPLETED
		else recovery.checkpoint(session))
	if not success:
		hud.feedback.text = recovery.last_error


func _apply_fullscreen() -> void:
	pass


func _input(_event: InputEvent) -> void:
	# Touch events arrive in the independently scaled UI viewport.
	pass


func _unhandled_key_input(_event: InputEvent) -> void:
	pass


func _hotbar_slot_pressed(slot: int) -> void:
	stop_movement()
	var focused := hud.get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	if not suspended:
		super._hotbar_slot_pressed(slot)
		_checkpoint_pending = true


func _toggle_hotbar_lock() -> void:
	super._toggle_hotbar_lock()
	_checkpoint_pending = true
