class_name SkillCost
extends RefCounted

## A fresh quote is paid immediately at cast completion.
var rage_cost: int = 0
var consumed_proc: StringName = &""


static func quote(hero: HeroState, skill: SkillDefinition) -> SkillCost:
	var payment := SkillCost.new()
	if skill.effect == SkillDefinition.Effect.PASSIVE:
		return payment
	if skill.family == &"execute" and hero.buffs.has(&"sudden_death_1"):
		payment.consumed_proc = &"sudden_death_1"
	elif skill.family == &"judgement" and hero.buffs.has(&"divine_purpose_1"):
		payment.consumed_proc = &"divine_purpose_1"
	elif skill.rage_cost > 0 and hero.buffs.has(&"battle_trance_1"):
		payment.consumed_proc = &"battle_trance_1"
	else:
		payment.rage_cost = skill.rage_cost
		if skill.effect == SkillDefinition.Effect.EXECUTE:
			payment.rage_cost = clampi(hero.rage, skill.rage_cost, skill.execute_rage_cap)
		if skill.class_tab == &"Paladin":
			payment.rage_cost = ceili(payment.rage_cost * (1.0
				- ClassToolkitRules.magnitude(hero, &"benediction_1") / 100.0))
	return payment


func pay(hero: HeroState) -> void:
	hero.rage -= rage_cost
	if consumed_proc != &"":
		hero.buffs.erase(consumed_proc)
