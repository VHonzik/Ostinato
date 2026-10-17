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
	world.add_message("Valley. Marshal north, wolves west, mine farther north, vineyards east. Watch the gate.")


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
	fresh.hero.learned_skills.assign(learned)
	fresh.hero.refresh_stats()
	fresh.hotbar = hotbar
	if fresh.hotbar[GridWorld.HOTBAR_SIZE - 1] == &"":
		fresh.hotbar[GridWorld.HOTBAR_SIZE - 1] = GridWorld.FOOD_HOTBAR_ID
	fresh.hotbar_locked = locked
	_replace_world(fresh)
	world.add_message("You died. Loop %d begins as %s. Learning remains; choose your class at the marshal before taking quests." % [loop_count, world.hero.selected_class])
	return true


func can_select_class() -> bool:
	return (world != null and world.can_save() and loop_count >= 2
		and not world.class_selected and not world.ever_accepted_quest)


func select_class(category: StringName, marshal: GridActor = null) -> bool:
	if (not can_select_class() or category not in ClassSkillData.PLAYABLE_CLASSES
		or not QuestRules.in_range(world, marshal, NpcDefinition.MARSHAL_ID) or marshal.service != &"Marshal"):
		return false
	world.resolving_turn = true
	world.hero.selected_class = category
	world.class_selected = true
	world.hero.refresh_stats()
	world.add_message("%s selected for Loop %d. Visit its trainer; learned skills remain usable." % [category, loop_count])
	world.add_message("Marshal: " + NpcDefinition.trainer_referral(category))
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
