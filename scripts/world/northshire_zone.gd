class_name NorthshireZone
extends RefCounted

## Fixed single-floor valley and per-slot seeded populations (FR-029/030/032).
const NPCS: Array = [
	[197, "Marshal McBride", 18, 12, "Marshal"],
	[823, "Deputy Willem", 20, 16, ""],
	[196, "Eagan Peltskinner", 15, 17, ""],
	[198, "Khelden Bremen", 17, 8, "Mage"],
	[900001, "Druid trainer", 12, 15, "Druid"],
	[9296, "Milly Osworth", 27, 10, ""],
	[952, "Brother Neals", 22, 7, ""],
	[1212, "Bishop Farthing", 20, 6, ""],
	[375, "Priestess Anetta", 23, 9, "Priest"],
	[925, "Brother Sammuel", 16, 10, "Paladin"],
	[459, "Drusilla La Salle", 29, 18, "Warlock"],
	[915, "Jorik Kerridan", 29, 20, ""],
	[911, "Llane Beshere", 25, 17, ""],
	[900002, "Shaman trainer", 12, 17, "Shaman"],
	[900003, "Abbey supply trader", 16, 18, "Trader"],
	[1642, "Northshire Guard", 53, 14, ""],
	[152, "Brother Danil", 19, 9, ""],
	[190, "Dermot Johns", 15, 20, ""],
	[1213, "Godric Rothgar", 18, 20, ""],
	[78, "Janos Hammerknuckle", 21, 20, ""],
	[11940, "Merissa Stilwell", 23, 16, ""],
	[6373, "Dane Winslow", 28, 16, ""],
	[951, "Brother Paxton", 24, 6, ""],
	[11260, "Northshire Peasant", 27, 12, ""],
	[5403, "White Stallion", 9, 14, ""],
]
const AREAS: Dictionary = {
	"wolves": {"rect": Rect2i(3, 20, 11, 15), "types": [69, 299], "slots": 10},
	"vermin": {"rect": Rect2i(5, 2, 8, 7), "types": [6], "slots": 8},
	"workers": {"rect": Rect2i(29, 2, 9, 7), "types": [257], "slots": 8},
	"mine": {"rect": Rect2i(39, 2, 11, 7), "types": [80], "slots": 10},
	"vineyard": {"rect": Rect2i(34, 25, 15, 14), "types": [38], "slots": 10},
	"garrick": {"rect": Rect2i(49, 32, 4, 5), "types": [103], "slots": 1},
}


static func create_world(seed_value: int, development_build: bool) -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 56, 44), Vector2i(20, 14),
		seed_value, development_build)
	world.northshire = true
	world.stalker_schedule = true
	for x in range(56):
		world.blocked_tiles[Vector2i(x, 0)] = true
		world.blocked_tiles[Vector2i(x, 43)] = true
	for y in range(44):
		world.blocked_tiles[Vector2i(0, y)] = true
		world.blocked_tiles[Vector2i(55, y)] = true
	_building(world, Rect2i(14, 4, 12, 9), [Vector2i(20, 12), Vector2i(25, 10),
		Vector2i(18, 12)])
	_building(world, Rect2i(7, 12, 7, 7), [Vector2i(13, 15)])
	_building(world, Rect2i(48, 30, 6, 9), [Vector2i(48, 34)])
	# Echo Ridge mine is a traversable single-floor interior.
	for x in range(39, 51):
		for y in range(1, 10):
			world.indoor_tiles[Vector2i(x, y)] = true
	# River divides the vineyards; bridge crossings remain open.
	for y in range(19, 43):
		if y not in [22, 23, 24]:
			world.blocked_tiles[Vector2i(32, y)] = true
	world.sight_blockers.assign(world.blocked_tiles)
	# Water blocks movement, but not sight.
	for y in range(19, 43):
		world.sight_blockers.erase(Vector2i(32, y))
	for row in NPCS:
		var actor := GridActor.new(Vector2i(row[2], row[3]))
		actor.npc_id = int(row[0])
		actor.title = row[1]
		actor.service = StringName(row[4])
		actor.spawn_id = "fixed/%d" % actor.npc_id
		actor.awards_experience = false
		actor.story_guard = actor.npc_id == 1642
		world.actors.append(actor)
	for area in AREAS:
		for slot in range(int(AREAS[area].slots)):
			world.population.append({"area": area, "slot": slot, "ordinal": 0,
				"due": 0, "pending": true})
	tick_population(world)
	for index in range(12):
		var crate := GridActor.new(Vector2i(35 + index % 4 * 3, 26 + index / 4 * 4))
		crate.title = "Milly's Harvest"
		crate.chest = true
		crate.alive = false
		crate.loot_table = 161557
		crate.spawn_id = "vineyard/crate/%d" % index
		world.actors.append(crate)
	var chest := GridActor.new(Vector2i(10, 16))
	chest.title = "Abbey supplies"
	chest.chest = true
	chest.alive = false
	chest.spawn_id = "abbey/chest/0"
	world.actors.append(chest)
	return world


static func _building(world: GridWorld, rectangle: Rect2i, doors: Array[Vector2i]) -> void:
	for x in range(rectangle.position.x, rectangle.end.x):
		for y in range(rectangle.position.y, rectangle.end.y):
			var tile := Vector2i(x, y)
			if (x in [rectangle.position.x, rectangle.end.x - 1]
				or y in [rectangle.position.y, rectangle.end.y - 1]):
				if not doors.has(tile):
					world.blocked_tiles[tile] = true
			else:
				world.indoor_tiles[tile] = true


static func npc_name(identity: int) -> String:
	for row in NPCS:
		if int(row[0]) == identity:
			return row[1]
	return "the quest contact"


static func tick_population(world: GridWorld) -> void:
	for record in world.population:
		if not record.pending or int(record.due) > world.turn_count:
			continue
		# At most 95 ordinary world actors; reserve five stalker positions.
		var ordinary := 0
		for actor in world.actors:
			if actor.alive and not actor.stalker and actor.summon_kind == "":
				ordinary += 1
		if ordinary >= 100 - GridWorld.STALKER_DEADLINES.size():
			continue
		var area: Dictionary = AREAS[record.area]
		var identity := "%s/%d/%d" % [record.area, record.slot, record.ordinal]
		var generator := RandomNumberGenerator.new()
		generator.seed = world.seed_value ^ int(identity.hash()) ^ 49979687
		var kind: int = area.types[generator.randi_range(0, area.types.size() - 1)]
		var rectangle: Rect2i = area.rect
		var start := generator.randi_range(0, rectangle.size.x * rectangle.size.y - 1)
		for offset in range(rectangle.size.x * rectangle.size.y):
			var index := (start + offset) % (rectangle.size.x * rectangle.size.y)
			var tile := rectangle.position + Vector2i(index % rectangle.size.x, index / rectangle.size.x)
			if not world.is_open(tile):
				continue
			var data: Dictionary = NorthshireData.CREATURES[str(kind)]
			var actor := GridActor.new(tile, rectangle)
			actor.npc_id = kind
			actor.title = data.title
			actor.spawn_id = identity
			actor.population_slot = world.population.find(record)
			actor.loot_table = kind
			actor.relationship = GridActor.Relationship.HOSTILE if kind in [38, 103] else GridActor.Relationship.NEUTRAL
			actor.creature_type = "beast" if kind in [69, 299] else "humanoid"
			actor.max_health = int(data.health)
			actor.health = actor.max_health
			actor.melee.level = int(data.level)
			actor.melee.armor = int(data.armor)
			actor.melee.damage_min = float(data.minimum)
			actor.melee.damage_max = float(data.maximum)
			actor.melee.attack_power = int(data.power)
			actor.melee.interval = float(data.interval)
			world.actors.append(actor)
			record.pending = false
			break


static func died(world: GridWorld, actor: GridActor) -> void:
	if actor.population_slot < 0:
		return
	var record: Dictionary = world.population[actor.population_slot]
	record.ordinal += 1
	record.due = actor.died_on_turn + 30
	record.pending = true


static func restore(world: GridWorld, records: Variant) -> bool:
	if not records is Array or records.size() > 95:
		return false
	var expected := 0
	for area in AREAS.values():
		expected += int(area.slots)
	if world.northshire and records.size() != expected:
		return false
	if not world.northshire and not records.is_empty():
		return false
	var identities: Array[String] = []
	for record in records:
		if (not record is Dictionary or not record.has_all(["area", "slot", "ordinal", "due", "pending"])
			or not record.area is String or not AREAS.has(record.area)
			or not record.pending is bool):
			return false
		for field in ["slot", "ordinal", "due"]:
			if not SaveCodec._integer(record[field], 0):
				return false
		var key := "%s/%d" % [record.area, record.slot]
		if identities.has(key) or record.slot >= int(AREAS[record.area].slots):
			return false
		identities.append(key)
		world.population.append({"area": record.area, "slot": int(record.slot),
			"ordinal": int(record.ordinal), "due": int(record.due), "pending": record.pending})
	var living_slots: Array[int] = []
	for actor in world.actors:
		if actor.population_slot >= world.population.size() or actor.population_slot < -1:
			return false
		if actor.population_slot < 0 or not actor.alive:
			continue
		var record: Dictionary = world.population[actor.population_slot]
		if (record.pending or living_slots.has(actor.population_slot)
			or actor.spawn_id != "%s/%d/%d" % [record.area, record.slot, record.ordinal]
			or not AREAS[record.area].types.has(actor.npc_id)):
			return false
		living_slots.append(actor.population_slot)
	for index in range(world.population.size()):
		if not world.population[index].pending and not living_slots.has(index):
			return false
	return true


static func greeting(identity: int) -> String:
	match identity:
		197:
			return ("The Burning Legion is invading across the continent. Our cities are besieged. "
				+ "Help the abbey, but stay clear of the gate.")
		9296, 11260:
			return ("Bandits have taken the vineyards. Surely the guards can handle a few thieves? "
				+ "I have heard nothing from Stormwind.")
		823, 1642:
			return "Something terrible is coming through the gate. The marshal needs every hand."
		952, 951, 1212, 375:
			return "Refugees speak of demons and burning cities. We are sheltering those we can."
	return "Welcome to Northshire. There are frightening rumors, but the abbey still stands."
