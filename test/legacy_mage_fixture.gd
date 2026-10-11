class_name LegacyMageFixture
extends RefCounted

## Explicit setup for retained spell/equipment mechanics, independent of the warrior start.
static func apply(world: GridWorld) -> void:
	world.hero.selected_class = &"Mage"
	world.hero.equipment.clear()
	StarterGear.equip_outfit(world.hero)
	world.hero.learned_skills = world.hero.learned_skills.filter(
		func(skill: SkillRank) -> bool: return skill.class_tab != &"Warrior")
	world.hero.learn_skill(SkillRank.catalog(&"fireball_1"))
	world.hero.learn_skill(SkillRank.catalog(&"frost_armor_1"))
	var first := world.hero.find_skill(&"fireball_1")
	var second := world.hero.find_skill(&"frost_armor_1")
	world.hero.learned_skills.erase(first)
	world.hero.learned_skills.erase(second)
	world.hero.learned_skills.push_front(second)
	world.hero.learned_skills.push_front(first)
	world.hero.health = world.hero.max_health
	world.hero.mana = world.hero.max_mana
	if world.hotbar[0] == &"slam_1":
		world.hotbar[0] = &"fireball_1"
	if world.hotbar[1] == &"battle_shout_1":
		world.hotbar[1] = &"frost_armor_1"


static func session(game: GameSession) -> void:
	var reference: WeakRef = weakref(game)
	game.world_changed.connect(func() -> void:
		var active_session := reference.get_ref() as GameSession
		if active_session != null and active_session.world.hero.selected_class == &"Warrior":
			apply(active_session.world))
