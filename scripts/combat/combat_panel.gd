class_name CombatPanel
extends Control

## Interaction and spell targeting with explicit confirmation.
signal action_taken
signal selection_changed(actor: GridActor)
signal service_requested(actor: GridActor)
signal conversation_requested(actor: GridActor)
signal loot_requested(source: GridActor)

enum Mode { SELECT, CONFIRM_ATTACK, SPELL, POISON }

var mode: Mode = Mode.SELECT
var selected: GridActor
var _skill: SkillDefinition
var _self_target: GridActor
var _world: GridWorld
var _candidates: Array[GridActor] = []
var _last_spell_target: GridActor
var _last_target_type: SkillDefinition.Target = SkillDefinition.Target.NONE
var _panel: PanelContainer
var _heading: Label
var _detail: Label
var _confirm: Button
var _cancel: Button
var _previous: Button
var _next: Button
var _poison_hands: int = PoisonRules.Hands.BOTH


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-340, -100)
	_panel.size = Vector2(680, 200)
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101d1b")
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	_heading = Label.new()
	_heading.name = "Heading"
	rows.add_child(_heading)
	_detail = Label.new()
	_detail.name = "Detail"
	# Give wrapping text its known content width before the first layout pass.
	_detail.custom_minimum_size.x = 660
	_detail.size.x = 660
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_detail)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	_previous = _button(buttons, "Previous", func() -> void: navigate(Vector2i.LEFT))
	_next = _button(buttons, "Next", func() -> void: navigate(Vector2i.RIGHT))
	_confirm = _button(buttons, "Choose (Enter)", confirm)
	_cancel = _button(buttons, "Cancel (Esc)", cancel)
	hide()


func open_interaction(world: GridWorld) -> void:
	close()
	_world = world
	_candidates = world.interaction_candidates()
	if _candidates.is_empty():
		world.add_message("No one is within interaction range.")
		return
	selected = _candidates[0]
	if _candidates.size() == 1:
		_choose_selected()
	else:
		mode = Mode.SELECT
		show()
		_update_selection()


func interact_with(world: GridWorld, actor: GridActor) -> void:
	if world.is_terminal() or not world.interaction_candidates().has(actor):
		return
	close()
	_world = world
	selected = actor
	_interact_selected()


func close() -> void:
	hide()
	selected = null
	selection_changed.emit(null)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func confirm() -> void:
	if visible and mode == Mode.POISON and _world != null:
		_world.cast_skill(_skill.id, null, _poison_hands)
		close()
		action_taken.emit()
		return
	if not visible or selected == null or _world == null or _world.is_terminal():
		return
	match mode:
		Mode.SELECT:
			_choose_selected()
		Mode.CONFIRM_ATTACK:
			_interact_selected()
		Mode.SPELL:
			if selected == _self_target or not selected.alive:
				clear_spell_target()
			else:
				_last_spell_target = selected
				_last_target_type = _skill.target
			_world.cast_skill(_skill.id, null if selected == _self_target else selected)
			close()
			action_taken.emit()


func cancel() -> void:
	close()


func clear_spell_target() -> void:
	_last_spell_target = null
	_last_target_type = SkillDefinition.Target.NONE


func navigate(direction: Vector2i) -> void:
	if mode == Mode.POISON:
		var step := 1 if direction.x > 0 or direction.y > 0 else -1
		_poison_hands = wrapi(_poison_hands - 1 + step, 0, 3) + 1
		_update_poison()
		return
	if mode not in [Mode.SELECT, Mode.SPELL] or _candidates.size() < 2:
		return
	# Prefer the nearest candidate ahead. If none is ahead, wrap from the far edge.
	var best: GridActor
	var best_score := INF
	for candidate in _candidates:
		if candidate == selected:
			continue
		var delta := candidate.tile - selected.tile
		var forward := direction.x * delta.x + direction.y * delta.y
		var side := absi(direction.x * delta.y - direction.y * delta.x)
		var score := float(forward + side * 2) if forward > 0 else 10000.0 + forward + side
		if score < best_score:
			best = candidate
			best_score = score
	selected = best
	_update_selection()


func select_tile(tile: Vector2i) -> void:
	if mode not in [Mode.SELECT, Mode.SPELL]:
		return
	for candidate in _candidates:
		if candidate.tile == tile:
			selected = candidate
			_update_selection()
			return


func _choose_selected() -> void:
	if selected.alive and selected.relationship == GridActor.Relationship.NEUTRAL:
		mode = Mode.CONFIRM_ATTACK
		show()
		_heading.text = "Attack %s?" % selected.title
		_detail.text = ("This NPC is neutral. Attacking will make it hostile. "
			+ "Enter attacks; Esc cancels without spending time.")
		_configure_buttons(false, "Attack (Enter)", true)
		selection_changed.emit(selected)
	else:
		_interact_selected()


func _interact_selected() -> void:
	if not selected.alive:
		if not _world.open_loot(selected):
			close()
			action_taken.emit()
			return
		var source := selected
		var available := source.loot_copper > 0
		for item in source.loot:
			available = available or LootData.collectable(_world, item)
		if available:
			close()
			loot_requested.emit(source)
			return
	if selected.alive and _world.northshire and selected.relationship == GridActor.Relationship.FRIENDLY:
		var contact := selected
		close()
		conversation_requested.emit(contact)
		return
	if selected.alive and selected.service != &"":
		var contact := selected
		close()
		service_requested.emit(contact)
		return
	var message := _world.interact(selected)
	if not message.is_empty():
		_world.add_message(message)
	close()
	action_taken.emit()


func _update_selection() -> void:
	_heading.text = "%s / %s" % [selected.title, selected.relationship_name()]
	_detail.text = "Level %d   Health %d/%d. Directions select; Enter chooses; Esc cancels." % [
		selected.melee.level, selected.health if selected.alive else 0, selected.max_health,
	]
	if mode == Mode.SPELL and _skill.effect == SkillDefinition.Effect.EXECUTE:
		_detail.text += "\nExecute spends %d rage; %s." % [
			_skill.cost(_world.hero), "Sudden Death allows any health" if _world.hero.buffs.has(&"sudden_death_1")
			else "requires at or below %d%% health" % _skill.execute_health_percent]
	if selected.debuffs.has(&"deadly_poison_1"):
		var poison: Dictionary = selected.debuffs[&"deadly_poison_1"]
		_detail.text += "\nDeadly Poison: %d stacks / %d turns." % [
			poison.stacks, maxi(0, int(poison.until) - _world.turn_count)]
	if selected.debuffs.has(&"judgement_1"):
		_detail.text += "\nJudgement: verdict in %d turns." % maxi(0,
			int(selected.debuffs[&"judgement_1"].until) - _world.turn_count)
	if selected.alive and selected.breath_remaining > 0:
		_detail.text += "\nFel Breath: %d turns. Leave the marked cone." % selected.breath_remaining
	_configure_buttons(_candidates.size() > 1,
		"Cast (Enter)" if mode == Mode.SPELL else "Choose (Enter)", true)
	selection_changed.emit(selected)


func _configure_buttons(multiple: bool, confirm_text: String, cancel_visible: bool) -> void:
	# Keep adjacent world targets visible during selection and attack confirmation.
	_panel.position = size * 0.5 + Vector2(-340, 88)
	_panel.size = Vector2(680, 164)
	_previous.visible = multiple
	_next.visible = multiple
	_confirm.text = confirm_text
	_cancel.visible = cancel_visible


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func open_spell(world: GridWorld, skill: SkillDefinition) -> void:
	if (_world != world or _last_target_type != skill.target
		or (_last_spell_target != null and not _last_spell_target.alive)):
		clear_spell_target()
	close()
	_world = world
	_skill = skill
	if skill.available_resource(world.hero) < skill.cost(world.hero):
		world.add_message("Not enough %s for %s: requires %d, have %d." % [
			skill.resource_name(), skill.title, skill.cost(world.hero), skill.available_resource(world.hero)])
		return
	_candidates = world.spell_candidates(skill)
	_self_target = null
	if skill.target == SkillDefinition.Target.ALLY and world.valid_spell_target(skill, null):
		_self_target = GridActor.new(world.player_tile)
		_self_target.title = "You"
		_self_target.health = world.hero.health
		_self_target.max_health = world.hero.max_health
		_self_target.melee.level = world.hero.level
		_candidates.push_front(_self_target)
	if _candidates.is_empty():
		world.add_message("No valid target for " + skill.title + ".")
		return
	selected = _last_spell_target if _candidates.has(_last_spell_target) else _candidates[0]
	if skill.family == &"lava_burst":
		if _candidates.size() == 1 and selected.engaged:
			_last_spell_target = selected
			_last_target_type = skill.target
			world.cast_skill(skill.id, selected)
			close()
			action_taken.emit()
			return
		mode = Mode.SPELL
		show()
		_update_selection()
		return
	if (skill.target == SkillDefinition.Target.ENEMY and _candidates.size() == 1
		and selected.relationship == GridActor.Relationship.NEUTRAL
		and world.tile_distance(world.player_tile, selected.tile) <= 1):
		var nearby := world.actors.filter(func(actor: GridActor) -> bool:
			return (actor.alive and actor != selected
				and world.tile_distance(world.player_tile, actor.tile) <= 1))
		if nearby.is_empty():
			_last_spell_target = selected
			_last_target_type = skill.target
			world.cast_skill(skill.id, selected)
			close()
			action_taken.emit()
			return
	mode = Mode.SPELL
	show()
	_update_selection()


func open_poison(world: GridWorld, skill: SkillDefinition) -> void:
	close()
	clear_spell_target()
	_world = world
	_skill = skill
	mode = Mode.POISON
	_poison_hands = PoisonRules.Hands.BOTH
	show()
	_update_poison()


func _update_poison() -> void:
	var choice: String = ["Main hand", "Off hand", "Both hands"][_poison_hands - 1]
	_heading.text = "%s / %s" % [_skill.title, choice]
	var descriptions: Array[String] = []
	for off_hand in [false, true]:
		var identifier := PoisonRules.coating(_world.hero, _world.turn_count, off_hand)
		var title := "Uncoated" if identifier == &"" else SkillDefinition.catalog(identifier).title
		descriptions.append("%s: %s" % ["Off hand" if off_hand else "Main hand", title])
	_detail.text = "%s.\nDirections choose hand(s); Enter coats for %d rage and one turn. Esc cancels." % [
		"; ".join(descriptions), _skill.cost(_world.hero)]
	_configure_buttons(true, "Coat (Enter)", true)
