class_name NpcDefinition
extends RefCounted

const MARSHAL_ID: int = 197
const JANOS_ID: int = 900003

## Contact identities and dialogue. Starting positions live in scenes/valley.tscn.
static var CONTACTS: Array[NpcDefinition] = [
	NpcDefinition.new(197, {"title": "Marshal McBride",
		"service": &"Marshal", "sprite": &"marshal",
		"greeting": "Greeting adventurer, welcome to Northshire Abbey. You look worn out from your travels."}),
	NpcDefinition.new(823, {"title": "Deputy Willem",
		"sprite": &"willem", "greeting": "A new face is always a pleasant sight, how can I help?"}),
	NpcDefinition.new(900003, {"title": "Janos Hammerknuckle",
		"service": &"Trader", "sprite": &"trader", "offers_starter_gear": true,
		"refresh_saved_name": true, "greeting": "Greetings, what can I get you?"}),
	NpcDefinition.new(9296, {"title": "Milly Osworth",
		"sprite": &"milly",
		"greeting": "A gang of brigands, the Defias, moved into the Northshire Vineyards while I was harvesting!"}),
	NpcDefinition.new(1642, {"title": "Northshire Guard",
		"sprite": &"gate_guard", "story_guard": true,
		"greeting": "This is the road out of the valley. Stay alert; I heard something beyond the gate."}),
	NpcDefinition.new(911, {"title": "Llane Beshere",
		"service": &"Warrior", "sprite": &"llane", "trainer_location": "inside the abbey",
		"greeting": "Practice your warrior skills. Return when you are ready to learn new tricks."}),
	NpcDefinition.new(915, {"title": "Jorik Kerridan",
		"service": &"Rogue", "sprite": &"jorrick", "trainer_location": "southeast of the abbey",
		"greeting": "Hello adventurer. Jorik Kerridan, famous rogue at your service."}),
	NpcDefinition.new(925, {"title": "Brother Sammuel",
		"service": &"Paladin", "sprite": &"sammuel", "trainer_location": "inside the abbey",
		"greeting": "Hello adventurer. I am Brother Sammuel, follower of the light."}),
	NpcDefinition.new(900002, {"title": "Farseer Lopaa",
		"service": &"Shaman", "sprite": &"shaman_mentor", "trainer_location": "beside the abbey entrance",
		"refresh_saved_name": true,
		"greeting": "Hello adventurer, I am Farseer Lopaa, a storm-chaser."}),
]

var npc_id: int
var title: String
var tile: Vector2i:
	get:
		return ValleyRoute.layout_info().contacts[npc_id]
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
			return ("Speak with %s, he always has supplies lying around. "
				+ "And %s is our own %s if you need some guidance.") % [
					display_name(JANOS_ID), contact.title, String(category).to_lower()]
	return ""


static func first_class_referral(category: StringName) -> String:
	for contact in CONTACTS:
		if contact.service == category and contact.trainer_location != "":
			return ("You don't look like %s... Anyway, go speak with %s, "
				+ "they will get you started. And check with %s, "
				+ "they might have some old equipment lying around.") % [
					category, contact.title, display_name(JANOS_ID)]
	return ""


func create_actor(start_tile: Vector2i) -> GridActor:
	var actor := GridActor.new(start_tile)
	actor.npc_id = npc_id
	actor.title = title
	actor.service = service
	actor.spawn_id = "fixed/%d" % npc_id
	actor.awards_experience = false
	actor.story_guard = story_guard
	return actor
