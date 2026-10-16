extends GridWorld

var watched: Array[GridActor] = []
var previous_hp: Dictionary = {}
var damage: Dictionary = {}
var casts: Dictionary = {}
var activations: Dictionary = {}
var damage_total: int = 0
var valid_accounting: bool = true


func watch(targets: Array[GridActor]) -> void:
	watched = targets.duplicate()
	for target in watched:
		previous_hp[target.title] = target.health


func _award_ability_use(skill: SkillDefinition) -> void:
	casts[skill.title] = int(casts.get(skill.title, 0)) + 1


func add_message(message: String) -> void:
	if message.ends_with(" activated."):
		var title := message.trim_suffix(" activated.")
		activations[title] = int(activations.get(title, 0)) + 1
	if message.ends_with(" damage."):
		for target in watched:
			var marker := " -> %s: " % target.title
			var position := message.find(marker)
			if position < 0:
				continue
			var label := message.left(position).get_slice(" (", 0)
			if label == "You":
				label = "Main-hand auto"
			elif label == "Off-hand":
				label = "Off-hand auto"
			var tail := message.substr(position + marker.length()).trim_suffix(" damage.")
			var amount := int(tail.get_slice(", ", tail.get_slice_count(", ") - 1))
			var actual := int(previous_hp[target.title]) - target.health
			if actual != mini(int(previous_hp[target.title]), amount) or actual < 0:
				valid_accounting = false
				push_error("Damage accounting mismatch: " + message)
			previous_hp[target.title] = target.health
			if not damage.has(label):
				damage[label] = {"effective": 0, "raw": 0, "overkill": 0, "events": 0}
			damage[label].effective += actual
			damage[label].raw += amount
			damage[label].overkill += amount - actual
			damage[label].events += 1
			damage_total += actual
			break
	super.add_message(message)
