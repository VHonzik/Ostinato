class_name VanishRules
extends RefCounted


static func active(world: GridWorld) -> bool:
	return world.hero.buffs.has(&"vanish_1")


static func origin(world: GridWorld) -> Vector2i:
	var buff: Dictionary = world.hero.buffs[&"vanish_1"]
	return world.bounds.position + Vector2i(buff.tile_offset_x, buff.tile_offset_y)


static func break_effect(world: GridWorld) -> int:
	if not active(world):
		return 0
	world.hero.buffs.erase(&"vanish_1")
	world.add_message("Vanish ends as you act.")
	return SkillDefinition.catalog(&"vanish_1").critical_percent
