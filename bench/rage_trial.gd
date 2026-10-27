extends RefCounted
## Observe production payments without changing resources, procs or damage.

var payment: SkillCost
var spending: Dictionary = {}


func before_completion(world: GridWorld) -> void:
	payment = null
	if world.pending_skill != null and not world.is_charging():
		payment = SkillCost.quote(world.hero, world.pending_skill)


func complete(_world: GridWorld, skill: SkillDefinition, paid: int) -> int:
	if payment == null:
		assert(skill.effect == SkillDefinition.Effect.CHARGE)
		return paid
	assert(payment.rage_cost == paid)
	if not spending.has(skill.title):
		spending[skill.title] = {"casts": 0, "paid": 0, "free": 0,
			"sudden_death": 0, "battle_trance": 0}
	var row: Dictionary = spending[skill.title]
	row.casts += 1
	row.paid += payment.rage_cost
	row.free += int(payment.rage_cost == 0 and skill.rage_cost > 0)
	if payment.consumed_proc == &"sudden_death_1":
		row.sudden_death += 1
	elif payment.consumed_proc == &"battle_trance_1":
		row.battle_trance += 1
	return payment.rage_cost
