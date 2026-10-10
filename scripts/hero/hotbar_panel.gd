class_name HotbarPanel
extends Control

signal slot_pressed(slot: int)
signal rank_dropped(slot: int, identifier: StringName, source_hero: HeroState)
signal lock_requested

var slots: Array[SkillButton] = []
var lock_button: Button
var editing_enabled: bool = false
var _world: GridWorld


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -340
	offset_right = 340
	offset_top = -120
	offset_bottom = -12
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows: Array[HBoxContainer] = []
	for row_index in range(2):
		var row := HBoxContainer.new()
		row.position = Vector2(0, 56 if row_index == 0 else 0)
		row.size = Vector2(680, 52)
		add_child(row)
		rows.append(row)
	for index in range(GridWorld.HOTBAR_SIZE):
		var button := SkillButton.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(64, 52)
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 14)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: slot_pressed.emit(index))
		button.set_drag_forwarding(Callable(), _can_drop.bind(index), _drop.bind(index))
		rows[index / 10].add_child(button)
		slots.append(button)
	lock_button = Button.new()
	lock_button.text = "Lock"
	lock_button.position = Vector2(608, -32)
	lock_button.size = Vector2(72, 28)
	lock_button.add_theme_font_size_override("font_size", 14)
	lock_button.pressed.connect(func() -> void: lock_requested.emit())
	add_child(lock_button)


func refresh(world: GridWorld, options: GlobalOptions, can_activate: bool,
	can_edit: bool, choosing_slot: bool) -> void:
	_world = world
	editing_enabled = can_edit and not world.hotbar_locked
	for index in range(slots.size()):
		var button := slots[index]
		var skill := world.hero.find_skill(world.hotbar[index])
		button.describe(skill, world.hero)
		var key := options.key_label(StringName("hotbar_%d" % (index + 1))).replace("Shift+", "S+")
		button.text = "%s\n%s" % [key, "—" if skill == null else skill.title.get_slice(" ", 0)]
		button.disabled = not (can_activate or (editing_enabled and choosing_slot))
		if skill == null:
			button.tooltip_text = "Slot %d (%s): empty. Assign a rank from the spell book." % [index + 1, key]
	lock_button.text = "Unlock" if world.hotbar_locked else "Lock"
	lock_button.tooltip_text = "Lock layout edits; assigned skills can still be activated."
	lock_button.disabled = not can_edit


func _can_drop(_position: Vector2, data: Variant, _slot: int) -> bool:
	if not editing_enabled or _world == null or not data is Dictionary:
		return false
	if data.get("hero") != _world.hero or not data.get("skill_id") is StringName:
		return false
	var skill := _world.hero.find_skill(data.skill_id)
	return skill != null and skill.effect != SkillRank.Effect.PASSIVE


func _drop(position: Vector2, data: Variant, slot: int) -> void:
	if _can_drop(position, data, slot):
		rank_dropped.emit(slot, data.skill_id, data.hero)
