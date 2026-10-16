class_name ValleyLandmarks
extends RefCounted

## Treasure positions are independent of the broad exploration destinations.
const EXPLORATION: Dictionary = {
	"mine": Rect2i(17, 2, 11, 12),
	"vineyard": Rect2i(44, 54, 19, 24),
	"wolf_woods": Rect2i(4, 28, 18, 32),
}
static var CHESTS: Dictionary[String, Landmark] = {
	"mine_chest": Landmark.new(Vector2i(19, 3), "Explore the back of Echo Ridge Mine"),
	"ridge_chest": Landmark.new(Vector2i(69, 52), "Explore the eastern ridge above the vineyard"),
	"vineyard_chest": Landmark.new(Vector2i(50, 79), "Explore the southern vineyard edge"),
}


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
