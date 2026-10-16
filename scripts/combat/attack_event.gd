class_name AttackEvent
extends RefCounted

## Facts about one resolved attack. Bonus damage cannot enter the primary proc pipeline.
enum Origin { SWING, ACTIVE, QUEUED_STRIKE, BONUS }
enum Hand { MAIN, OFF }
enum School { PHYSICAL = 0, HOLY = 1, NATURE = 3 }

var target: GridActor
var skill: SkillDefinition
var result: StringName
var amount: int
var origin: Origin
var hand: Hand = Hand.MAIN
var school: School
var build_points: bool = true


func _init(actor: GridActor, ability: SkillDefinition, outcome: StringName,
	damage: int, damage_school: School = School.PHYSICAL) -> void:
	target = actor
	skill = ability
	result = outcome
	amount = damage
	school = damage_school
	origin = Origin.SWING if skill == null else Origin.ACTIVE
	if is_family(&"heroic_strike"):
		origin = Origin.QUEUED_STRIKE


func landed() -> bool:
	return result not in [&"miss", &"dodge"]


func critical() -> bool:
	return result == &"critical"


func is_direct() -> bool:
	return origin in [Origin.ACTIVE, Origin.QUEUED_STRIKE]


func is_swing() -> bool:
	return origin in [Origin.SWING, Origin.QUEUED_STRIKE]


func is_primary() -> bool:
	return origin != Origin.BONUS


func is_family(family: StringName) -> bool:
	return skill != null and skill.family == family


func is_finisher() -> bool:
	return is_direct() and is_family(&"eviscerate")


func can_build_combo() -> bool:
	return (is_primary() and landed() and build_points and not is_finisher()
		and (is_direct() or (school == School.PHYSICAL and hand == Hand.MAIN)))


func can_trigger_weapon_procs() -> bool:
	return is_primary() and landed() and school == School.PHYSICAL


func can_trigger_main_gauche() -> bool:
	return (can_trigger_weapon_procs() and hand == Hand.MAIN
		and (origin == Origin.SWING or is_family(&"heroic_strike")))


func can_trigger_battle_trance() -> bool:
	return is_direct() and critical() and not is_finisher() and not is_family(&"heroic_strike")
