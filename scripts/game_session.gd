class_name GameSession
extends RefCounted

## FR-001/002/003: replace the complete attempt; old references cannot affect the new world.
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
	_replace_world(MovementFixture.create_world(seed_value, development_build, true))
	world.add_message("Loop 1. You awaken as a mage. The marshal waits northwest.")


func restart_after_death() -> bool:
	if world == null or not world.is_player_dead():
		return false
	var learned := world.hero.learned_skills.duplicate()
	var hotbar := world.hotbar.duplicate()
	var locked := world.hotbar_locked
	loop_count += 1
	var fresh := MovementFixture.create_world(seed_value, development_build, true)
	fresh.hero.learned_skills.assign(learned)
	fresh.hotbar = hotbar
	fresh.hotbar_locked = locked
	_replace_world(fresh)
	world.add_message("You died. Loop %d begins. Your learned ranks remain." % loop_count)
	return true


func can_select_class() -> bool:
	return (world != null and loop_count >= 2 and world.hero.level == 1
		and not world.class_selected and not world.ever_accepted_quest)


func select_class(category: StringName) -> bool:
	if (not can_select_class() or category not in [&"Mage", &"Druid"]
		or category == world.hero.selected_class):
		return false
	if not StarterGear.exchange(world.hero, category):
		world.add_message("Not enough inventory space. Class selection remains available.")
		return false
	world.class_selected = true
	world.add_message("Marshal: Welcome back, %s. These clothes should fit. Visit your trainer." % category)
	return true


func restore(restored_world: GridWorld, saved_seed: int, saved_loop: int) -> void:
	seed_value = saved_seed
	loop_count = saved_loop
	_replace_world(restored_world)


func _replace_world(next_world: GridWorld) -> void:
	if world != null:
		world.cancel_melee()
		world.cancel_cast()
	world = next_world
	world_changed.emit()


func mark_saved() -> void:
	_saved_snapshot = JSON.stringify(SaveCodec.capture(self))


func has_unsaved_changes() -> bool:
	return world != null and (not world.can_save() or _saved_snapshot != JSON.stringify(SaveCodec.capture(self)))
