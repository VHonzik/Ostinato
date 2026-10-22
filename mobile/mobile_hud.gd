class_name MobileGameplayHud
extends GameplayHud

var _hotbar: HotbarPanel


func _ready() -> void:
	# Wrap auras within the player info column instead of extending into enemy info.
	var desktop_auras := $Auras as HBoxContainer
	var auras := HFlowContainer.new()
	auras.theme = desktop_auras.theme
	auras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remove_child(desktop_auras)
	desktop_auras.queue_free()
	auras.name = "Auras"
	add_child(auras)
	$Top.item_rect_changed.connect(_layout_auras)
	_layout_auras()
	for path in ["HealthBar", "RageBar", "ExperienceBar", "ComboPointBar",
		"MaelstromWeaponBar"]:
		(get_node(path) as Control).set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)


func attach_hotbar(hotbar: HotbarPanel) -> void:
	_hotbar = hotbar
	_hotbar.item_rect_changed.connect(_layout_resources)
	_layout_resources()


func refresh_overlay(_active_game: bool, _hero_open: bool, _combat_open: bool) -> void:
	$Bottom.hide()


func refresh_resources(world: GridWorld, show_resources: bool) -> void:
	super.refresh_resources(world, show_resources)
	$Bottom.hide()
	$PlayerMenu.hide()


func show_game() -> void:
	super.show_game()
	$Bottom.hide()


func _layout_auras() -> void:
	var player_info := $Top as Control
	var auras := $Auras as Control
	auras.position = player_info.position + Vector2(0, player_info.size.y + 8)
	auras.size = Vector2(player_info.size.x, 0)


func _layout_resources() -> void:
	# Leave the hotbar's lock button clear on the right.
	var width := _hotbar.size.x - _hotbar.lock_button.size.x - 12
	var half_width := (width - 8) / 2.0
	var origin := _hotbar.position
	$HealthBar.position = origin + Vector2(0, -60)
	$HealthBar.size = Vector2(half_width, 32)
	$RageBar.position = origin + Vector2(half_width + 8, -60)
	$RageBar.size = Vector2(half_width, 32)
	$ExperienceBar.position = origin + Vector2(0, -24)
	$ExperienceBar.size = Vector2(width, 20)
	$ComboPointBar.position = origin + Vector2(0, -92)
	$ComboPointBar.size = Vector2(half_width, 28)
	$MaelstromWeaponBar.position = origin + Vector2(half_width + 8, -92)
	$MaelstromWeaponBar.size = Vector2(half_width, 28)
