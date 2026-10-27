extends HeroState
## Count actual accepted rage separately from production's cap losses.

var sources: Dictionary = {}
var lost_at_cap: float = 0.0
var decayed: int = 0
var source: String = ""


func gain_rage(amount: float) -> void:
	var label := source
	if label.is_empty():
		label = "incoming" if is_equal_approx(amount, INCOMING_RAGE_PER_TURN) else "Combat Potency"
	var before := rage
	var credit_before := rage_credit
	super.gain_rage(amount)
	var gained := rage - before
	sources[label] = int(sources.get(label, 0)) + gained
	lost_at_cap += amount + credit_before - gained - rage_credit


func decay_rage() -> void:
	var before := rage
	super.decay_rage()
	decayed += before - rage
