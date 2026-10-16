class_name SkillBehaviors
extends RefCounted

## Family overrides and shared effect defaults are selected in this one registry.
static var _families: Dictionary[StringName, SkillBehavior] = {
	&"execute": Execute.new(),
	&"whirlwind": Whirlwind.new(),
	&"booming_shout": BoomingShout.new(),
	&"earth_shock": EarthShock.new(),
	&"feral_spirit": FeralSpirit.new(),
	&"seal_of_command": WeaponBuff.new(),
	&"windfury_weapon": Windfury.new(),
	&"instant_poison": Poison.new(),
	&"deadly_poison": Poison.new(),
	&"execution_sentence": ExecutionSentence.new(),
	&"consecration": Consecration.new(),
	&"blessing_of_might": BlessingOfMight.new(),
	&"divine_shield": DivineShield.new(),
	&"eviscerate": Eviscerate.new(),
	&"lightning_shield": LightningShield.new(),
}
static var _effects: Dictionary[int, SkillBehavior] = {
	SkillDefinition.Effect.MORTAL_STRIKE: PhysicalAttack.new(),
	SkillDefinition.Effect.EXECUTE: Execute.new(),
	SkillDefinition.Effect.BATTLE_SHOUT: BattleShout.new(),
	SkillDefinition.Effect.CHARGE: Charge.new(),
	SkillDefinition.Effect.ARMOR: Buff.new(),
	SkillDefinition.Effect.SUMMON: Summon.new(),
	SkillDefinition.Effect.EXECUTION_SENTENCE: ExecutionSentence.new(),
	SkillDefinition.Effect.PASSIVE: Passive.new(),
	SkillDefinition.Effect.CLASS_POINTS: Development.new(),
	SkillDefinition.Effect.PRACTICE: Development.new(),
	SkillDefinition.Effect.EXPERIENCE: Development.new(),
	SkillDefinition.Effect.GOLD: Development.new(),
	SkillDefinition.Effect.KILL_STALKER: Development.new(),
	SkillDefinition.Effect.DEATH_NOTICE: Development.new(),
}
static var _empty := SkillBehavior.new()


static func for_skill(skill: SkillDefinition) -> SkillBehavior:
	return _families.get(skill.family, _effects.get(skill.effect, _empty))


class Passive extends SkillBehavior:
	func can_apply(_world: GridWorld, _skill: SkillDefinition, _target: GridActor) -> bool:
		return false


class PhysicalAttack extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		ClassToolkitRules.physical_attack(world, cast.target, cast.skill, cast.skill.minimum)


class Execute extends PhysicalAttack:
	func can_apply(world: GridWorld, skill: SkillDefinition, target: GridActor) -> bool:
		return skill.execute_eligible(target) or world.hero.buffs.has(&"sudden_death_1")

	func resolve(world: GridWorld, cast: Cast) -> void:
		var skill := cast.skill
		var bonus := skill.minimum + maxi(0, cast.resource_spent - skill.rage_cost) \
			* skill.execute_damage_per_rage
		world.add_message("Execute: spent %d rage." % cast.resource_spent)
		ClassToolkitRules.physical_attack(world, cast.target, skill, bonus)


class BattleShout extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		var skill := cast.skill
		world.hero.gain_rage(skill.rage_generated)
		world.hero.buffs[skill.id] = {"armor": 0, "physical_percent": skill.physical_percent,
			"until": world.turn_count + 1 + skill.duration}
		world.hero.refresh_stats()
		world.add_message("Battle Shout: physical damage increased; gained %d rage."
			% skill.rage_generated)


class Charge extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		world.last_attacked_enemy = cast.target
		world.auto_attack_target = cast.target
		world.hero.gain_rage(cast.skill.rage_generated)
		world.add_message("Charge: reached %s; gained %d rage."
			% [cast.target.title, cast.skill.rage_generated])
		ClassToolkitRules.apply(world, &"juggernaut_1", {"charges": 1})


class Whirlwind extends SkillBehavior:
	func can_apply(world: GridWorld, skill: SkillDefinition, _target: GridActor) -> bool:
		return world.actors.any(func(actor: GridActor) -> bool:
			return ClassToolkitRules.eligible(world, actor, skill.range_tiles))

	func resolve(world: GridWorld, cast: Cast) -> void:
		for enemy in world.actors.duplicate():
			if world.is_terminal():
				break
			if ClassToolkitRules.eligible(world, enemy, cast.skill.range_tiles):
				enemy.relationship = GridActor.Relationship.HOSTILE
				enemy.engaged = true
				ClassToolkitRules.physical_attack(world, enemy, cast.skill,
					cast.skill.minimum, true, false)


class BoomingShout extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		for enemy in world.actors.duplicate():
			if world.is_terminal():
				break
			if not enemy.chest and ClassToolkitRules.eligible(world, enemy, cast.skill.range_tiles):
				enemy.relationship = GridActor.Relationship.HOSTILE
				enemy.engaged = true
				enemy.returning_home = false
				SpellEffects.damage(world, enemy, cast.skill.minimum, cast.skill.title,
					-1, null, true)


class EarthShock extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		var extra := 1.0 + ClassToolkitRules.magnitude(world.hero, &"elemental_assault_1") / 100.0
		if world.hero.buffs.has(&"elemental_assault_1"):
			extra += 0.5
			world.hero.buffs.erase(&"elemental_assault_1")
		var result := ClassToolkitRules.magic_attack(world, cast.target, cast.skill, extra)
		var target := cast.target
		if result.landed() and target.alive and not world.is_terminal():
			target.swing.remaining += 1.0
			target.debuffs["interrupt"] = {"until": world.turn_count + 3}
			if ClassToolkitRules.has(world.hero, &"improved_earth_shock_1"):
				target.stunned_until = world.turn_count + 1 \
					+ ClassToolkitRules.magnitude(world.hero, &"improved_earth_shock_1")
			world.add_message("Earth Shock interrupts %s and delays its next swing." % target.title)


class FeralSpirit extends SkillBehavior:
	func can_apply(world: GridWorld, _skill: SkillDefinition, _target: GridActor) -> bool:
		return ClassToolkitRules.wolf_tiles(world).size() >= 2

	func resolve(world: GridWorld, cast: Cast) -> void:
		ClassToolkitRules.summon_wolves(world, cast.skill)


class Summon extends SkillBehavior:
	func can_apply(world: GridWorld, skill: SkillDefinition, _target: GridActor) -> bool:
		return (SummonRules.active(world, SummonRules.slot(skill)) == null
			and SummonRules.placement(world, skill) != Vector2i(-1, -1))

	func resolve(world: GridWorld, cast: Cast) -> void:
		SummonRules.summon(world, cast.skill)


class ExecutionSentence extends SkillBehavior:
	func can_apply(world: GridWorld, skill: SkillDefinition, target: GridActor) -> bool:
		return (world.hero.buffs.has(&"seal_of_command_1")
			and world.hero.equipment.has("weapons") and not target.debuffs.has(skill.id))

	func resolve(world: GridWorld, cast: Cast) -> void:
		PaladinRules.sentence(world, cast.target, cast.skill)


class Consecration extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		PaladinRules.consecrate(world, cast.skill)


class Poison extends SkillBehavior:
	func can_apply(world: GridWorld, _skill: SkillDefinition, _target: GridActor) -> bool:
		return world.hero.equipment.has("weapons")

	func resolve(world: GridWorld, cast: Cast) -> void:
		PoisonRules.coat(world, cast.skill, cast.poison_hands)


class Buff extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		var skill := cast.skill
		var buffs := world.hero.buffs
		for key in buffs.keys():
			var previous := SkillDefinition.catalog(StringName(key))
			if previous != null and previous.family == skill.family:
				buffs.erase(key)
		var effect := {"armor": 0, "until": world.turn_count + 1 + skill.duration}
		configure(world, skill, effect)
		buffs[skill.id] = effect
		world.hero.refresh_stats()
		world.add_message("%s applied." % skill.title)

	func configure(_world: GridWorld, _skill: SkillDefinition, _effect: Dictionary) -> void:
		pass


class WeaponBuff extends Buff:
	func can_apply(world: GridWorld, _skill: SkillDefinition, _target: GridActor) -> bool:
		return world.hero.equipment.has("weapons")


class Windfury extends WeaponBuff:
	func configure(world: GridWorld, _skill: SkillDefinition, effect: Dictionary) -> void:
		effect["weapon_id"] = world.hero.weapon_id()
		effect["ready"] = 0


class BlessingOfMight extends Buff:
	func configure(_world: GridWorld, skill: SkillDefinition, effect: Dictionary) -> void:
		effect["strength"] = skill.minimum


class DivineShield extends Buff:
	func configure(world: GridWorld, _skill: SkillDefinition, effect: Dictionary) -> void:
		effect["immunity"] = 1
		if ClassToolkitRules.has(world.hero, &"guardians_favor_1"):
			effect.until += world.hero.find_skill(&"guardians_favor_1").duration


class Eviscerate extends PhysicalAttack:
	func can_apply(world: GridWorld, _skill: SkillDefinition, _target: GridActor) -> bool:
		return world.hero.combo_points > 0

	func resolve(world: GridWorld, cast: Cast) -> void:
		var points := world.hero.combo_points
		world.hero.combo_points = 0
		ClassToolkitRules.physical_attack(world, cast.target, cast.skill,
			cast.skill.minimum * points, false)
		ClassToolkitRules.slice_and_dice(world, points)
		ClassToolkitRules.finish(world, points)


class LightningShield extends Buff:
	func configure(world: GridWorld, _skill: SkillDefinition, effect: Dictionary) -> void:
		effect["charges"] = 6 if ClassToolkitRules.has(world.hero, &"improved_shields_1") else 3
		effect["ready"] = 0


class Development extends SkillBehavior:
	func resolve(world: GridWorld, cast: Cast) -> void:
		match cast.skill.effect:
			SkillDefinition.Effect.CLASS_POINTS:
				world.add_class_progress(world.hero.selected_class, 30)
				world.add_message("Gained 30 %s progression points."
					% String(world.hero.selected_class).to_lower())
			SkillDefinition.Effect.PRACTICE:
				world.add_message("%s: cast complete (1 turn, 0 rage)." % cast.skill.title)
			SkillDefinition.Effect.EXPERIENCE:
				world.add_message("%s: gained 450 XP." % cast.skill.title)
				for gained_level in world.hero.add_experience(450):
					world.add_message("Level up! You are now level %d. Health restored." % gained_level)
			SkillDefinition.Effect.GOLD:
				world.hero.copper += 10000
				world.add_message("Gain 1 gold: gained %s." % InventoryRules.money(10000))
			SkillDefinition.Effect.KILL_STALKER:
				var stalker := world._first_living_stalker()
				if stalker != null:
					SpellEffects.damage(world, stalker, stalker.health, "Kill stalker")
			SkillDefinition.Effect.DEATH_NOTICE:
				world.hero.health = 0
				world.add_message("Death trigger invoked. You died.")
