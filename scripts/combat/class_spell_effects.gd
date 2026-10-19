class_name ClassSpellEffects
extends RefCounted

## Buffs, Holy weapon effects and explicit class defenses.
static func absorb(world: GridWorld, target: GridActor, amount: int, _physical: bool) -> int:
	var buffs := world.hero.buffs if target == null else target.buffs
	if buffs.has(&"divine_shield_1"):
		return 0
	if target == null:
		amount = floori(amount * ClassToolkitRules.recklessness_taken_multiplier(world.hero))
	if WarBannerRules.protects(world, target):
		var percent := int(ItemData.get_item(ItemData.WAR_BANNER_ID).reduction_percent)
		# Whole damage rounds up so a small hit never becomes immunity.
		amount = ceili(amount * (100 - percent) / 100.0)
	return amount


static func retaliate(world: GridWorld, attacker: GridActor, defender: GridActor, amount: int) -> void:
	if world.is_terminal() or amount <= 0 or not attacker.alive:
		return
	if defender == null:
		ClassToolkitRules.discharge(world, attacker, true)


static func on_melee(world: GridWorld, event: AttackEvent) -> void:
	var target := event.target
	if world.is_terminal() or not target.alive:
		return
	var skill := world.hero.find_skill(&"seal_of_command_1")
	if event.landed() and skill != null and world.hero.equipment.has("weapons"):
		var weapon_roll := world.combat_random.randf()
		var raw := MeleeRules.weapon_damage(world.hero.melee, weapon_roll)
		var value := MeleeRules.round_weapon_damage(raw * skill.weapon_multiplier
			* ClassToolkitRules.damage_multiplier(world.hero)
			* MeleeRules.level_damage_multiplier(world.hero.level, target.melee.level),
			world.hero.melee, weapon_roll)
		SpellEffects.damage(world, target, value, "Seal of Command", world.turn_count)
		if not world.is_terminal():
			ClassToolkitRules.holy_event(world)


static func tick(world: GridWorld) -> void:
	# Delayed verdicts and poison own their expiry so their final delivery is preserved.
	for actor in world.actors:
		for key in actor.debuffs.keys():
			if (key not in [&"judgement_1", &"deadly_poison_1", &"heart_of_the_crusader_1"]
				and int(actor.debuffs[key].until) <= world.turn_count):
				actor.debuffs.erase(key)
	for key in world.hero.debuffs.keys():
		if int(world.hero.debuffs[key].until) <= world.turn_count:
			world.hero.debuffs.erase(key)
	PaladinRules.tick(world)
	if world.is_terminal():
		return
	for actor in world.actors:
		PoisonRules.tick(world, actor)
		if world.is_terminal():
			return
