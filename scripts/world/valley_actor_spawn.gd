@tool
class_name ValleyActorSpawn
extends Sprite2D

## Editor placeholder; live combat state belongs to GridActor.
@export var npc_id: int = 0
## Unique, permanent loot/save identity. Give duplicates a new ID.
@export var spawn_id: String = ""
## Stable turn order, independent of scene-tree order.
@export var turn_order: int = 0
## Zero keeps this actor stationary; two gives the current 5 by 5 patrol area.
@export_range(0, 20) var wander_radius: int = 0
## Nonempty for a treasure placeholder instead of an NPC.
@export var treasure_id: String = ""
@export var treasure_hint: String = ""


func tile() -> Vector2i:
	return Vector2i((position / 32.0).floor())


func create_actor() -> GridActor:
	var contact := NpcDefinition.find(npc_id)
	var actor := contact.create_actor(tile()) if contact != null else GridActor.new(tile())
	actor.tile = tile()
	actor.home_tile = actor.tile
	actor.spawn_id = spawn_id
	if treasure_id != "":
		actor.title = "Battered Chest"
		actor.chest = true
		actor.alive = false
		actor.loot_table = 2843
	elif contact == null:
		var data: Dictionary = NorthshireData.CREATURES[str(npc_id)]
		actor.npc_id = npc_id
		actor.title = String(data.title)
		actor.loot_table = npc_id
		actor.creature_type = "beast" if npc_id in [299, 69] else "humanoid"
		actor.relationship = (GridActor.Relationship.NEUTRAL if npc_id in [299, 69, 6]
			else GridActor.Relationship.HOSTILE)
		actor.aggro_range = 4
		actor.max_health = int(data.health)
		actor.health = actor.max_health
		actor.melee.level = int(data.level)
		actor.melee.armor = int(data.armor)
		actor.melee.damage_min = float(data.minimum)
		actor.melee.damage_max = float(data.maximum)
		actor.melee.attack_power = int(data.power)
		actor.melee.interval = float(data.interval)
	if wander_radius > 0:
		actor.wander_area = Rect2i(actor.tile - Vector2i.ONE * wander_radius,
			Vector2i.ONE * (wander_radius * 2 + 1))
	return actor


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if spawn_id.is_empty():
		warnings.append("Set a unique spawn_id before playing this actor.")
	if treasure_id.is_empty() and NpcDefinition.find(npc_id) == null \
		and not NorthshireData.CREATURES.has(str(npc_id)):
		warnings.append("Choose an existing contact or creature npc_id, or set treasure_id.")
	return warnings
