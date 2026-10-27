extends "res://bench/restless_trace_world.gd"

const RageTrial = preload("res://bench/rage_trial.gd")
const RageHero = preload("res://bench/rage_hero.gd")
var trial := RageTrial.new()
var rage_samples: Array[int] = []
var decision_samples: Array[Dictionary] = []
var entry_rage: int = 0


func watch(targets: Array[GridActor]) -> void:
	super.watch(targets)
	entry_rage = hero.rage
	var observer := hero as RageHero
	observer.sources.clear()
	observer.lost_at_cap = 0.0
	observer.decayed = 0
	trial.spending.clear()


func continue_cast() -> bool:
	trial.before_completion(self)
	return super.continue_cast()


func _resolve_skill(skill: SkillDefinition, target: GridActor, resource_spent: int = 0,
	poison_hands: int = PoisonRules.Hands.BOTH, maelstrom_stacks: int = 0,
	critical_bonus: int = 0) -> void:
	var paid := trial.complete(self, skill, resource_spent)
	var observer := hero as RageHero
	observer.source = skill.title
	super._resolve_skill(skill, target, paid, poison_hands, maelstrom_stacks, critical_bonus)
	observer.source = ""


func _player_swing(target: GridActor) -> void:
	var observer := hero as RageHero
	observer.source = "main-hand swings"
	super._player_swing(target)
	observer.source = ""


func _finish_turn() -> void:
	super._finish_turn()
	if not watched.is_empty():
		rage_samples.append(hero.rage)


func metrics() -> Dictionary:
	var result := super.metrics()
	var observer := hero as RageHero
	var gained := 0
	for value: int in observer.sources.values():
		gained += value
	var paid := 0
	for row: Dictionary in trial.spending.values():
		paid += int(row.paid)
	assert(entry_rage + gained - paid - observer.decayed == hero.rage)
	result.merge({"rage_samples": rage_samples, "rage_decisions": decision_samples,
		"rage_sources": observer.sources, "cap_loss": observer.lost_at_cap,
		"rage_paid": paid, "rage_decayed": observer.decayed,
		"entry_rage": entry_rage, "spending": trial.spending,
		"decisions": [], "events": []}, true)
	return result
