class_name GameplayHud
extends CanvasLayer

@onready var cancel_attack: Button = $Top/Rows/CancelAttack
@onready var feedback: Label = $Bottom/Rows/Feedback
@onready var _status: Label = $Top/Rows/Status
@onready var _hero_status: Label = $Top/Rows/HeroStatus
@onready var _chat: RichTextLabel = $Bottom/Rows/Chat
@onready var _quest_tracker: Label = $QuestTracker/Text


func show_game() -> void:
	$Top.show()
	$Bottom.show()


func hide_game() -> void:
	for path in ["Top", "Bottom", "PlayerMenu", "Auras", "RageBar", "HealthBar",
		"ComboPointBar", "MaelstromWeaponBar", "QuestTracker", "Enemy", "ExperienceBar", "SwingBar"]:
		(get_node(path) as Control).hide()


func refresh_overlay(active_game: bool, hero_open: bool, combat_open: bool) -> void:
	$Bottom.visible = active_game and not hero_open and not combat_open
	feedback.visible = not hero_open


func refresh_chat(world: GridWorld) -> void:
	_chat.text = "\n".join(world.messages)


func refresh(world: GridWorld, loop_count: int, options: GlobalOptions) -> void:
	$PlayerMenu/Buttons/PlayerMenu.text = "Menu (%s)" % options.key_label(&"player_menu")
	$PlayerMenu/Buttons/Character.text = "Character (%s)" % options.key_label(&"character")
	$PlayerMenu/Buttons/Spells.text = "Spells (%s)" % options.key_label(&"spell_book")
	$PlayerMenu/Buttons/Inventory.text = "Inventory (%s)" % options.key_label(&"inventory")
	var upgrade := InventoryRules.has_quality_upgrade(world.hero)
	for state in HotbarPanel.LABEL_COLOR_STATES:
		if upgrade:
			$PlayerMenu/Buttons/Inventory.add_theme_color_override(state, Color("70d779"))
		else:
			$PlayerMenu/Buttons/Inventory.remove_theme_color_override(state)
	$PlayerMenu/Buttons/Interact.text = "Interact (%s)" % options.key_label(&"interact")
	$PlayerMenu/Buttons/Quests.text = "Quests (%s)" % options.key_label(&"quest_log")
	var hero := world.hero
	_hero_status.text = "HP %d/%d   Rage %d/%d\nLv %d  XP %d/%d   %s" % [
		hero.health, hero.max_health, hero.rage, HeroState.MAX_RAGE,
		hero.level, hero.experience, hero.experience_to_next_level(),
		InventoryRules.money(hero.copper),
	]
	if hero.find_skill(&"relentless_assault_1") != null:
		_hero_status.text += "   CP %d/%d" % [hero.combo_points, HeroState.MAX_COMBO_POINTS]
	_status.text = "Turn %d  ·  Loop %d  ·  %s" % [world.turn_count, loop_count, hero.selected_class]
	_refresh_auras(world)


func refresh_resources(world: GridWorld, show_resources: bool) -> void:
	$PlayerMenu.visible = show_resources
	$Auras.visible = show_resources
	$RageBar.visible = $Auras.visible
	$SwingBar.visible = $RageBar.visible
	$SwingBar.position = $RageBar.position
	$SwingBar.size = Vector2($RageBar.size.x, 0.0)
	$SwingBar.refresh(world.hero)
	$HealthBar.visible = $Auras.visible
	$HealthBar.modulate.a = 0.8
	$HealthBar/Fill.max_value = world.hero.max_health
	$HealthBar/Fill.value = world.hero.health
	$ExperienceBar.visible = $Auras.visible
	$ExperienceBar.modulate.a = 0.8
	$ExperienceBar/Fill.max_value = world.hero.experience_to_next_level()
	$ExperienceBar/Fill.value = world.hero.experience
	$RageBar.modulate.a = 0.2 if world.hero.rage == 0 else 0.8
	$RageBar/Fill.max_value = HeroState.MAX_RAGE
	$RageBar/Fill.value = world.hero.rage
	$ComboPointBar.visible = ($Auras.visible
		and world.hero.find_skill(&"relentless_assault_1") != null)
	$ComboPointBar.refresh(world.hero)
	$MaelstromWeaponBar.visible = ($Auras.visible
		and world.hero.find_skill(&"maelstrom_weapon_1") != null)
	$MaelstromWeaponBar.refresh(world.hero)
	_refresh_enemy(world, show_resources)
	_refresh_quest_tracker(world)


func _refresh_enemy(world: GridWorld, show_resources: bool) -> void:
	var target := world.committed_enemy()
	$Enemy.visible = show_resources and target != null
	if target == null:
		return
	$Enemy/Rows/Heading/Name.text = target.title
	$Enemy/Rows/Heading/Objective.visible = QuestRules.is_objective(world, target)
	$Enemy/Rows/Health.max_value = target.max_health
	$Enemy/Rows/Health.value = target.health
	$Enemy/Rows/HealthText.text = "HP %d/%d" % [target.health, target.max_health]


func _refresh_auras(world: GridWorld) -> void:
	var hero := world.hero
	for child in $Auras.get_children():
		$Auras.remove_child(child)
		child.queue_free()
	for identifier in hero.buffs:
		if identifier == &"maelstrom_weapon_1":
			continue
		var skill := hero.find_skill(StringName(identifier))
		var title := skill.title if skill != null else String(identifier).capitalize()
		if skill != null and PoisonRules.is_poison(skill):
			for off_hand in [false, true]:
				if PoisonRules.coating(hero, world.turn_count, off_hand) != identifier:
					continue
				var effect: Dictionary = hero.buffs[identifier].duplicate()
				effect.until = int(effect.get("off_until" if off_hand else "main_until", effect.until))
				_add_aura(world, title + (" (OH)" if off_hand else " (MH)"), effect, false,
					title.left(1) + ("O" if off_hand else "M"))
			continue
		_add_aura(world, title, hero.buffs[identifier], false)
	for identifier in hero.debuffs:
		_add_aura(world, String(identifier).capitalize(), hero.debuffs[identifier], true)
	if WarBannerRules.active(world):
		var banner := ItemData.get_item(ItemData.WAR_BANNER_ID)
		var detail := ("%d%% less damage taken" % banner.reduction_percent
			if WarBannerRules.protects(world) else "Outside protection range")
		_add_aura(world, "Wartorn Banner", {"until": world.war_banner.until,
			"detail": detail + " / stay within %d tiles of the banner" % banner.radius}, false, "WB")
	if hero.restoration.has("food"):
		var food: Dictionary = hero.restoration.food
		var elapsed := mini(world.turn_count - int(food.started), int(food.duration))
		var next_heal := floori(float(food.total) * mini(elapsed + 1, int(food.duration))
			/ int(food.duration)) - int(food.delivered)
		_add_aura(world, "Eating", {"until": int(food.started) + int(food.duration),
			"healing": next_heal,
			"detail": "%d HP next turn / %d of %d HP delivered" % [
				next_heal, food.delivered, food.total]}, false, "Eat")
	var reckless_damage := (ClassToolkitRules.recklessness_damage_multiplier(hero) - 1.0) * 100.0
	if reckless_damage > 0.0:
		var reckless_taken := (ClassToolkitRules.recklessness_taken_multiplier(hero) - 1.0) * 100.0
		_add_aura(world, "Death Wish", {"until": 0,
			"detail": "+%.1f%% physical damage / +%.1f%% damage taken" % [
				reckless_damage, reckless_taken]}, false)


func _refresh_quest_tracker(world: GridWorld) -> void:
	var quests: PackedStringArray = []
	for identifier in world.quests:
		if world.quests[identifier].handed_in:
			continue
		var quest: Dictionary = QuestData.QUESTS[identifier]
		var lines: PackedStringArray = [String(quest.title)]
		if QuestRules.ready(world, identifier):
			lines[0] += " — Completed"
		for index in range(quest.objectives.size()):
			var objective: QuestObjective = quest.objectives[index]
			var amount := QuestRules.progress(world, identifier, index)
			var required := int(objective.count)
			var status := "Completed" if amount >= required else "%d/%d" % [amount, required]
			lines.append("  %s: %s" % [objective.label(), status])
		quests.append("\n".join(lines))
	_quest_tracker.text = "\n\n".join(quests)
	$QuestTracker.reset_size()
	$QuestTracker.visible = $Auras.visible and not quests.is_empty()


func _add_aura(world: GridWorld, title: String, effect: Dictionary, harmful: bool, abbreviation: String = "") -> void:
	var square := Panel.new()
	square.custom_minimum_size = Vector2(32, 32)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243b35")
	style.set_border_width_all(1)
	style.border_color = Color("ff7777") if harmful else Color("a6c8a0")
	if int(effect.get("critical_ready", 0)) > 0:
		style.border_color = Color("ffe187")
	square.add_theme_stylebox_override("panel", style)
	var words := title.split(" ", false)
	var shortcut := title.left(2).to_upper()
	if words.size() > 1:
		shortcut = (words[0].left(1) + words[-1].left(1)).to_upper()
	if not abbreviation.is_empty():
		shortcut = abbreviation
	var label := Label.new()
	label.text = shortcut
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_child(label)
	var until := int(effect.get("until", 0))
	square.tooltip_text = title
	if title == "Vanish":
		square.tooltip_text += "\nMove or wait unseen. A melee attack or any ability ends Vanish."
		square.tooltip_text += "\nOpening action: +%d percentage points crit." % SkillDefinition.catalog(&"vanish_1").critical_percent
	if effect.has("physical_percent"):
		square.tooltip_text += "\n+%d%% physical damage" % effect.physical_percent
	if effect.has("critical_percent"):
		square.tooltip_text += "\n+%d percentage points attack crit" % effect.critical_percent
	if effect.has("detail"):
		square.tooltip_text += "\n" + String(effect.detail)
	if effect.has("healing"):
		var healing := Label.new()
		healing.name = "Healing"
		healing.text = "+%d" % effect.healing
		healing.add_theme_font_size_override("font_size", 10)
		healing.add_theme_color_override("font_color", Color("66ee88"))
		healing.add_theme_color_override("font_outline_color", Color.BLACK)
		healing.add_theme_constant_override("outline_size", 2)
		healing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(healing)
	if int(effect.get("charges", 0)) > 0:
		square.tooltip_text += " / %d charges" % effect.charges
		var charges := Label.new()
		charges.name = "Charges"
		charges.text = str(int(effect.charges))
		charges.add_theme_font_size_override("font_size", 10)
		charges.add_theme_color_override("font_color", Color.WHITE)
		charges.add_theme_color_override("font_outline_color", Color.BLACK)
		charges.add_theme_constant_override("outline_size", 2)
		charges.position = Vector2(2, 1)
		charges.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(charges)
	if until > 0:
		var remaining := maxi(0, until - world.turn_count)
		var duration := Label.new()
		duration.text = str(remaining)
		duration.add_theme_font_size_override("font_size", 10)
		duration.add_theme_color_override("font_color",
			Color("ff6464") if remaining <= 3 else Color.WHITE)
		duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		duration.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		duration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		duration.offset_right = -1
		duration.offset_bottom = -1
		duration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		square.add_child(duration)
		square.tooltip_text += " / %d turns" % maxi(0, until - world.turn_count)
	$Auras.add_child(square)
