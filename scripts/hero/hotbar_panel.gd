class_name HotbarPanel
extends Control

signal slot_pressed(slot: int)
signal skill_dropped(slot: int, identifier: StringName, source_hero: HeroState)
signal lock_requested

const INSUFFICIENT_RAGE_COLOR := Color("ff6464")
const LABEL_COLOR_STATES: Array[StringName] = [
	&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
	&"font_focus_color", &"font_disabled_color",
]

var slots: Array[SkillButton] = []
var lock_button: Button
var editing_enabled: bool = false
var _world: GridWorld
var _cooldown_labels: Array[Label] = []


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
		rows[index / GridWorld.HOTBAR_ROW_SIZE].add_child(button)
		slots.append(button)
		var cooldown := Label.new()
		cooldown.name = "Cooldown"
		button.add_child(cooldown)
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		cooldown.offset_left = -30
		cooldown.offset_right = -3
		cooldown.offset_top = 2
		cooldown.offset_bottom = 18
		cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown.add_theme_font_size_override("font_size", 12)
		cooldown.add_theme_color_override("font_color", Color("ff6464"))
		cooldown.hide()
		_cooldown_labels.append(cooldown)
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
		if world.hotbar[index] == ItemData.WAR_HORN_HOTBAR_ID:
			skill = ItemData.war_horn_action()
		elif world.hotbar[index] == ItemData.ANCESTRAL_TOTEM_HOTBAR_ID:
			skill = ItemData.ancestral_totem_action()
		button.describe(skill, world.hero)
		var key := options.key_label(StringName("hotbar_%d" % (index + 1))).replace("Shift+", "S+")
		button.text = "%s\n%s" % [key, "—" if skill == null else skill.title.get_slice(" ", 0)]
		button.disabled = not (can_activate or (editing_enabled and choosing_slot))
		var remaining := 0
		if skill != null:
			remaining = maxi(0, int(world.hero.cooldowns.get(
				String(world.cooldown_family(skill)), 0)) - world.turn_count)
		var cooldown := _cooldown_labels[index]
		var insufficient_rage := (skill != null
			and skill.available_resource(world.hero) < skill.cost(world.hero))
		var execute_unavailable := (skill != null and skill.effect == SkillDefinition.Effect.EXECUTE
			and not world.hero.buffs.has(&"sudden_death_1")
			and (not world.valid_spell_target(skill, world.last_attacked_enemy) if world.in_combat()
				else world.spell_candidates(skill).is_empty()))
		var sentence_unavailable := (skill != null
			and skill.effect == SkillDefinition.Effect.JUDGEMENT
			and world.hero.find_skill(&"seal_of_command_1") == null)
		for color_state in LABEL_COLOR_STATES:
			if insufficient_rage or execute_unavailable or sentence_unavailable:
				button.add_theme_color_override(color_state, INSUFFICIENT_RAGE_COLOR)
			else:
				button.remove_theme_color_override(color_state)
		cooldown.text = str(remaining) if remaining > 0 else ""
		cooldown.visible = remaining > 0
		if skill == null:
			button.tooltip_text = "Slot %d (%s): empty. Assign a skill from the spell book." % [index + 1, key]
		if world.hotbar[index] == GridWorld.FOOD_HOTBAR_ID:
			var quantity := 0
			for item in world.hero.inventory:
				if not item.is_empty() and item.id == GridWorld.SPAWN_FOOD_ID:
					quantity += int(item.quantity)
			var food := ItemData.get_item(GridWorld.SPAWN_FOOD_ID)
			button.text = "%s\nFood x%d" % [key, quantity]
			button.tooltip_text = "%s x%d\nHeals %d HP over %d turns. Movement or combat ends eating." % [
				food.title, quantity, food.restore, food.duration]
		elif world.hotbar[index] == ItemData.WAR_HORN_HOTBAR_ID:
			button.text = "%s\nHorn" % key
			button.tooltip_text = ItemData.describe(ItemData.WAR_HORN_ID)
			button.disabled = button.disabled or not world.has_war_horn()
		elif world.hotbar[index] == ItemData.ANCESTRAL_TOTEM_HOTBAR_ID:
			button.text = "%s\nTotem x%d" % [key, 1 if world.has_ancestral_totem() else 0]
			button.tooltip_text = ItemData.describe(ItemData.ANCESTRAL_TOTEM_ID)
			button.disabled = button.disabled or not world.has_ancestral_totem()
		elif world.hotbar[index] == ItemData.WAR_BANNER_HOTBAR_ID:
			button.text = "%s\nBanner x%d" % [key, 1 if world.has_war_banner() else 0]
			button.tooltip_text = ItemData.describe(ItemData.WAR_BANNER_ID)
			button.disabled = button.disabled or not world.has_war_banner()
	lock_button.text = "Unlock" if world.hotbar_locked else "Lock"
	lock_button.tooltip_text = "Lock layout edits; assigned skills can still be activated."
	lock_button.disabled = not can_edit


func _can_drop(_position: Vector2, data: Variant, _slot: int) -> bool:
	if not editing_enabled or _world == null or not data is Dictionary:
		return false
	if data.get("hero") != _world.hero or not data.get("skill_id") is StringName:
		return false
	var skill := _world.hero.find_skill(data.skill_id)
	return skill != null and skill.effect != SkillDefinition.Effect.PASSIVE


func _drop(position: Vector2, data: Variant, slot: int) -> void:
	if _can_drop(position, data, slot):
		skill_dropped.emit(slot, data.skill_id, data.hero)
