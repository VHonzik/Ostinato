class_name QuestObjective
extends RefCounted

enum Kind { KILL, LOOT, LOCATION, TALK }

var kind: Kind
var count: int
var npc_id: int = 0
var item_id: int = 0
var location_id: StringName = &""


func _init(objective_kind: Kind, required: int) -> void:
	kind = objective_kind
	count = required


static func kill(identity: int, required: int) -> QuestObjective:
	var objective := QuestObjective.new(Kind.KILL, required)
	objective.npc_id = identity
	return objective


static func loot(identity: int, required: int) -> QuestObjective:
	var objective := QuestObjective.new(Kind.LOOT, required)
	objective.item_id = identity
	return objective


static func location(identity: StringName, required: int = 1) -> QuestObjective:
	var objective := QuestObjective.new(Kind.LOCATION, required)
	objective.location_id = identity
	return objective


static func talk(identity: int, required: int = 1) -> QuestObjective:
	var objective := QuestObjective.new(Kind.TALK, required)
	objective.npc_id = identity
	return objective


func progress(hero: HeroState, recorded: int) -> int:
	if kind != Kind.LOOT:
		return recorded
	var total := 0
	for item in hero.inventory:
		if not item.is_empty() and int(item.id) == item_id:
			total += int(item.quantity)
	return mini(total, count)


func matches(event_kind: Kind, identity: int, location: StringName) -> bool:
	if kind != event_kind:
		return false
	return location_id == location if kind == Kind.LOCATION else npc_id == identity


func label() -> String:
	match kind:
		Kind.LOOT:
			return ItemData.get_item(item_id).title
		Kind.KILL:
			return NorthshireData.CREATURES[str(npc_id)].title
		Kind.LOCATION:
			return ValleyLandmarks.objective_label(location_id)
		Kind.TALK:
			return "Speak with " + NpcDefinition.display_name(npc_id)
	return ""
