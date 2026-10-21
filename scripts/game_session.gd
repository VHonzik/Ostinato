class_name GameSession
extends RefCounted

## Replace the complete attempt; old references cannot affect the new world.
signal world_changed

var world: GridWorld
var seed_value: int = 0
var loop_count: int = 1
var development_build: bool = OS.is_debug_build()
var _saved_snapshot: String = ""


func new_game(chosen_seed: int = -1) -> void:
	_saved_snapshot = ""
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	seed_value = generator.randi() if chosen_seed == -1 else chosen_seed
	loop_count = 1
	var fresh := ValleyRoute.create_world(seed_value, development_build)
	fresh.class_selected = true
	fresh.hotbar[0] = &"mortal_strike_1"
	fresh.hotbar[1] = &"whirlwind_1"
	_replace_world(fresh)
	world.add_message(opening_text(1))


func restart_after_death() -> bool:
	if world == null:
		return false
	world.check_terminal()
	if world.attempt_state != GridWorld.AttemptState.PLAYER_DIED:
		return false
	var learned := world.hero.learned_skills.duplicate()
	var hotbar := world.hotbar.duplicate()
	var locked := world.hotbar_locked
	loop_count += 1
	var fresh := ValleyRoute.create_world(seed_value, development_build)
	if world.hero.selected_class in ClassSkillData.PLAYABLE_CLASSES:
		fresh.hero.selected_class = world.hero.selected_class
	fresh.chosen_classes.assign(world.chosen_classes)
	fresh.hero.learned_skills.assign(learned)
	fresh.hero.refresh_stats()
	fresh.hotbar = hotbar
	for slot in range(fresh.hotbar.size()):
		if fresh.hotbar[slot] in [ItemData.WAR_HORN_HOTBAR_ID, ItemData.ANCESTRAL_TOTEM_HOTBAR_ID,
			ItemData.WAR_BANNER_HOTBAR_ID]:
			fresh.hotbar[slot] = &""
	if fresh.hotbar[GridWorld.HOTBAR_SIZE - 1] == &"":
		fresh.hotbar[GridWorld.HOTBAR_SIZE - 1] = GridWorld.FOOD_HOTBAR_ID
	fresh.hotbar_locked = locked
	_replace_world(fresh)
	world.add_message(opening_text(loop_count))
	return true


static func opening_text(loop_number: int) -> String:
	var hint := "Speak to Marshal McBride north of you, outside the abbey."
	if loop_number == 1:
		return "You arrive in Northshire, weary from the road. " + hint
	if loop_number == 2:
		return "You remember dying. What happened? Was it a nightmare? " + hint
	if loop_number == 3:
		return "You definitely died this time. Why are you back here? " + hint
	if loop_number == 4:
		return "What is that monster at the gate? Where are the guards? " + hint
	if loop_number == 5:
		return "No one else seems to remember anything, but maybe they can help me? " + hint
	return "I must become stronger. " + hint


func selectable_classes() -> Array[StringName]:
	if loop_count < 3:
		return [&"Warrior"]
	return ClassSkillData.PLAYABLE_CLASSES


func can_select_class() -> bool:
	return (world != null and world.can_save() and loop_count >= 2
		and not world.class_selected and not world.ever_accepted_quest)


func select_class(category: StringName, marshal: GridActor = null) -> bool:
	if (not can_select_class() or category not in selectable_classes()
		or not QuestRules.in_range(world, marshal, NpcDefinition.MARSHAL_ID) or marshal.service != &"Marshal"):
		return false
	var first_choice := not world.chosen_classes.has(category)
	world.resolving_turn = true
	world.hero.selected_class = category
	if first_choice:
		world.chosen_classes.append(category)
	world.class_selected = true
	world.hero.refresh_stats()
	world.add_message("%s selected for Loop %d. Visit its trainer; learned skills remain usable." % [category, loop_count])
	var reply := (NpcDefinition.first_class_referral(category) if first_choice
		else NpcDefinition.trainer_referral(category))
	world.add_message("Marshal: " + reply)
	world.resolving_turn = false
	return true


func restore(restored_world: GridWorld, saved_seed: int, saved_loop: int) -> void:
	seed_value = saved_seed
	loop_count = saved_loop
	_replace_world(restored_world)


func _replace_world(next_world: GridWorld) -> void:
	if world != null:
		world.discard()
	world = next_world
	world_changed.emit()


func mark_saved() -> void:
	_saved_snapshot = JSON.stringify(SaveCodec.capture(self))


func has_unsaved_changes() -> bool:
	return world != null and (not world.can_save() or _saved_snapshot != JSON.stringify(SaveCodec.capture(self)))
