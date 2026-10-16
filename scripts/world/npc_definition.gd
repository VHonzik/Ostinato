class_name NpcDefinition
extends RefCounted

const MARSHAL_ID: int = 197
const JANOS_ID: int = 900003

## Contact order is also saved actor order. These definitions contain no live actor state.
static var CONTACTS: Array[NpcDefinition] = [
	NpcDefinition.new(197, {"title": "Marshal McBride", "tile": Vector2i(30, 52),
		"service": &"Marshal", "sprite": &"marshal",
		"greeting": "Greeting adventurer, welcome to Northshire Abbey. You look worn out from your travels."}),
	NpcDefinition.new(823, {"title": "Deputy Willem", "tile": Vector2i(24, 45),
		"sprite": &"willem", "greeting": "A new face is always a pleasant sight, how can I help?"}),
	NpcDefinition.new(900003, {"title": "Janos Hammerknuckle", "tile": Vector2i(28, 41),
		"service": &"Trader", "sprite": &"trader", "offers_starter_gear": true,
		"refresh_saved_name": true, "greeting": "Greetings, what can I get you?"}),
	NpcDefinition.new(198, {"title": "Khelden Bremen", "tile": Vector2i(32, 35)}),
	NpcDefinition.new(9296, {"title": "Milly Osworth", "tile": Vector2i(35, 32),
		"sprite": &"milly",
		"greeting": "A gang of brigands, the Defias, moved into the Northshire Vineyards while I was harvesting!"}),
	NpcDefinition.new(1642, {"title": "Northshire Guard", "tile": Vector2i(12, 63),
		"sprite": &"gate_guard", "story_guard": true,
		"greeting": "This is the road out of the valley. Stay alert; I heard something beyond the gate."}),
	NpcDefinition.new(911, {"title": "Llane Beshere", "tile": Vector2i(31, 34),
		"service": &"Warrior", "sprite": &"llane", "trainer_location": "inside the abbey",
		"greeting": "Practice your warrior skills. Return when you are ready to learn new tricks."}),
	NpcDefinition.new(915, {"title": "Jorik Kerridan", "tile": Vector2i(39, 43),
		"service": &"Rogue", "sprite": &"jorrick", "trainer_location": "southeast of the abbey",
		"greeting": "Hello adventurer. Jorik Kerridan, famous rogue at your service."}),
	NpcDefinition.new(925, {"title": "Brother Sammuel", "tile": Vector2i(30, 37),
		"service": &"Paladin", "sprite": &"sammuel", "trainer_location": "inside the abbey",
		"greeting": "Hello adventurer. I am Brother Sammuel, follower of the light."}),
	NpcDefinition.new(900002, {"title": "Farseer Lopaa", "tile": Vector2i(38, 37),
		"service": &"Shaman", "sprite": &"shaman_mentor", "trainer_location": "east of the abbey",
		"refresh_saved_name": true,
		"greeting": "Hello adventurer, I am Farseer Lopaa, a storm-chaser."}),
]

var npc_id: int
var title: String
var tile: Vector2i
var greeting: String
var service: StringName
var sprite: StringName
var trainer_location: String
var story_guard: bool
var offers_starter_gear: bool
var refresh_saved_name: bool


func _init(identity: int, fields: Dictionary) -> void:
	npc_id = identity
	title = fields.title
	tile = fields.tile
	greeting = fields.get("greeting", "Hello adventurer.")
	service = fields.get("service", &"")
	sprite = fields.get("sprite", &"")
	trainer_location = fields.get("trainer_location", "")
	story_guard = fields.get("story_guard", false)
	offers_starter_gear = fields.get("offers_starter_gear", false)
	refresh_saved_name = fields.get("refresh_saved_name", false)


static func find(identity: int) -> NpcDefinition:
	for contact in CONTACTS:
		if contact.npc_id == identity:
			return contact
	return null


static func display_name(identity: int) -> String:
	var contact := find(identity)
	return "the quest contact" if contact == null else contact.title


static func greeting_for(identity: int) -> String:
	var contact := find(identity)
	return "Hello adventurer." if contact == null else contact.greeting


static func trainer_referral(category: StringName) -> String:
	for contact in CONTACTS:
		if contact.service == category and contact.trainer_location != "":
			return "Speak with %s %s." % [contact.title, contact.trainer_location]
	return ""


func create_actor() -> GridActor:
	var actor := GridActor.new(tile)
	actor.npc_id = npc_id
	actor.title = title
	actor.service = service
	actor.spawn_id = "fixed/%d" % npc_id
	actor.awards_experience = false
	actor.story_guard = story_guard
	return actor
