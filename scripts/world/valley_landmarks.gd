class_name ValleyLandmarks
extends RefCounted

## The same landmarks place chests, credit exploration and describe quest objectives.
static var CHESTS: Dictionary[String, Landmark] = {
	"mine_chest": Landmark.new(Vector2i(19, 3), "Explore the back of Echo Ridge Mine"),
	"ridge_chest": Landmark.new(Vector2i(69, 52), "Explore the eastern ridge above the vineyard"),
	"vineyard_chest": Landmark.new(Vector2i(50, 79), "Explore the southern vineyard edge"),
}


static func objective_label(identifier: StringName) -> String:
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
