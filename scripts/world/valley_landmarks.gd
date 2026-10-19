class_name ValleyLandmarks
extends RefCounted

## Treasure positions are independent of the broad exploration destinations.
static var EXPLORATION: Dictionary:
	get:
		return ValleyRoute.layout_info().exploration
static var CHESTS: Dictionary[String, Landmark]:
	get:
		var result: Dictionary[String, Landmark] = {}
		var chests: Dictionary = ValleyRoute.layout_info().chests
		for id: String in chests:
			result[id] = Landmark.new(chests[id].tile, chests[id].hint)
		return result


static func objective_label(identifier: StringName) -> String:
	match identifier:
		&"mine": return "Enter Echo Ridge Mine"
		&"vineyard": return "Approach the vineyard"
		&"wolf_woods": return "Explore the western wolf woods"
	if CHESTS.has(String(identifier)):
		return CHESTS[String(identifier)].description
	# Historical fixture objective; the playable valley has no overlook trigger.
	return "Visit the gate overlook (43–45, 11–17)" if identifier == &"gate_overlook" else ""


class Landmark:
	extends RefCounted

	var tile: Vector2i
	var description: String

	func _init(position: Vector2i, text: String) -> void:
		tile = position
		description = text
