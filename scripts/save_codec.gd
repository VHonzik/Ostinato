class_name SaveCodec
extends RefCounted

## Explicit demo revision-2 fields; JSON keeps RNG int64 values as decimal strings.
const WORLD_FIELDS: Array[String] = [
	"bounds", "player_tile", "movement_speed", "movement_credit", "turn_count",
	"global_cooldown_until", "stalker_schedule", "stalker_arrived",
	"class_selected", "ever_accepted_quest", "hotbar_locked",
]
const HERO_FIELDS: Array[String] = [
	"level", "experience", "health", "mana", "selected_class", "copper",
	"casting_credit", "last_mana_turn", "facing", "potion_ready_turn",
	"spell_power", "healing_power", "spell_hit", "spell_critical", "haste",
]
const ACTOR_FIELDS: Array[String] = [
	"tile", "home_tile", "alive", "wander_area", "title", "relationship", "engaged",
	"returning_home", "blocked_turns", "aggro_range", "max_health", "health", "facing",
	"awards_experience", "corpse_visible", "died_on_turn", "service", "chilled_until",
	"movement_credit", "story_guard", "stalker", "spawn_id", "loot_table", "loot_assigned",
	"loot_copper", "chest", "creature_type", "rooted_until", "root_skill",
	"slowed_until", "polymorphed_until", "polymorphed_on_turn",
]
const MELEE_FIELDS: Array[String] = [
	"level", "player", "armor", "attack_power", "damage_min", "damage_max",
	"interval", "critical", "dodge", "hit", "parry", "block", "block_value",
]


static func capture(session: GameSession) -> Dictionary:
	var world := session.world
	var data := {
		"seed": str(session.seed_value), "loop": session.loop_count,
		"world": _fields(world, WORLD_FIELDS), "hero": _fields(world.hero, HERO_FIELDS),
		"random": str(world.random.state), "combat_random": str(world.combat_random.state),
		"blocked": [], "sight": [], "actors": [], "learned": [],
		"equipment": world.hero.equipment.duplicate(true),
		"inventory": world.hero.inventory.duplicate(true),
		"buffs": world.hero.buffs.duplicate(true), "hotbar": [],
		"periodic": world.periodic_effects.duplicate(true), "messages": Array(world.messages),
		"hero_swing": [world.hero.swing.remaining, world.hero.swing._active],
		"vendor_stock": world.vendor_stock.duplicate(true), "loot_quests": Array(world.loot_quests),
		"cooldowns": world.hero.cooldowns.duplicate(true),
		"restoration": world.hero.restoration.duplicate(true),
		"resistances": world.hero.resistances.duplicate(true), "indoors": [],
	}
	for tile in world.indoor_tiles:
		data.indoors.append([tile.x, tile.y])
	for identifier in world.hotbar:
		data.hotbar.append(String(identifier))
	for skill in world.hero.learned_skills:
		data.learned.append(String(skill.id))
	for tile in world.blocked_tiles:
		data.blocked.append([tile.x, tile.y])
	for tile in world.sight_blockers:
		data.sight.append([tile.x, tile.y])
	for actor in world.actors:
		data.actors.append({
			"state": _fields(actor, ACTOR_FIELDS), "melee": _fields(actor.melee, MELEE_FIELDS),
			"swing": [actor.swing.remaining, actor.swing._active],
			"buffs": actor.buffs.duplicate(true), "loot": actor.loot.duplicate(true),
			"resistances": actor.resistances.duplicate(true),
		})
	return data


static func restore(data: Variant, development_build: bool) -> GridWorld:
	if not data is Dictionary:
		return null
	var keys := ["seed", "loop", "world", "hero", "random", "combat_random",
		"blocked", "sight", "actors", "learned", "equipment", "inventory",
		"buffs", "hotbar", "periodic", "messages", "hero_swing", "indoors",
		"vendor_stock", "loot_quests", "cooldowns", "restoration", "resistances"]
	for key in keys:
		if not data.has(key):
			return null
	for key in ["seed", "random", "combat_random"]:
		if (not data[key] is String or not data[key].is_valid_int()
			or str(int(data[key])) != data[key]):
			return null
	if not _integer(data.loop, 1):
		return null
	var world := GridWorld.new(Rect2i(0, 0, 1, 1), Vector2i.ZERO, int(data.seed), false)
	if not _restore_fields(world, data.world, WORLD_FIELDS):
		return null
	if not _restore_fields(world.hero, data.hero, HERO_FIELDS):
		return null
	if (world.bounds.size.x < 1 or world.bounds.size.y < 1
		or world.bounds.size.x > 1024 or world.bounds.size.y > 1024
		or not world.bounds.has_point(world.player_tile)
		or world.turn_count < 0 or world.movement_speed <= 0 or world.movement_credit < 0
		or world.hero.level < 1
		or world.hero.experience < 0 or world.hero.copper < 0
		or world.hero.haste <= 0 or world.hero.potion_ready_turn < 0
		or world.hero.casting_credit < 0 or world.hero.casting_credit >= 1.0
		or world.hero.selected_class not in [&"Mage", &"Druid"]):
		return null
	world.hero._apply_level_stats()
	if world.hero.experience >= world.hero.experience_to_next_level():
		return null
	if not _tiles(data.indoors, world.indoor_tiles, world.bounds):
		return null
	if not _tiles(data.blocked, world.blocked_tiles, world.bounds):
		return null
	if not _tiles(data.sight, world.sight_blockers, world.bounds):
		return null
	if world.blocked_tiles.has(world.player_tile):
		return null
	if not data.actors is Array or data.actors.size() > 1000:
		return null
	for record in data.actors:
		if (not record is Dictionary or not record.has_all(["state", "melee", "swing", "buffs", "loot", "resistances"])):
			return null
		var actor := GridActor.new(Vector2i.ZERO)
		if not _restore_fields(actor, record.state, ACTOR_FIELDS):
			return null
		if not _restore_fields(actor.melee, record.melee, MELEE_FIELDS):
			return null
		if not _restore_swing(actor.swing, record.swing) or not _buffs(record.buffs):
			return null
		if (not world.bounds.has_point(actor.tile) or not world.bounds.has_point(actor.home_tile)
			or actor.max_health <= 0 or actor.health < 0 or actor.health > actor.max_health
			or actor.relationship < 0 or actor.relationship > 2
			or actor.melee.level < 1 or actor.melee.interval <= 0
			or actor.melee.armor < 0 or actor.melee.damage_min < 0
			or actor.melee.damage_max < actor.melee.damage_min
			or actor.movement_credit < 0 or actor.blocked_turns < 0
			or (actor.alive and not world.is_open(actor.tile))):
			return null
		if not record.loot is Array or record.loot.size() > 100:
			return null
		for item in record.loot:
			if not _item(item) or item.is_empty():
				return null
			actor.loot.append(_normalized_item(item))
		if not _number_map(record.resistances, 0) or actor.loot_copper < 0:
			return null
		actor.resistances = _normalized_numbers(record.resistances)
		actor.buffs = _normalized_buffs(record.buffs)
		world.actors.append(actor)
	if not data.learned is Array or data.learned.size() > 1000:
		return null
	world.hero.learned_skills.clear()
	var learned: Array[String] = []
	for identifier in data.learned:
		if not identifier is String or learned.has(identifier):
			return null
		var skill := SkillRank.catalog(StringName(identifier))
		if skill == null:
			return null
		learned.append(identifier)
		if development_build or not skill.development_only:
			world.hero.learned_skills.append(skill)
	if not learned.has("fireball_1") or not learned.has("frost_armor_1"):
		return null
	if not _inventory(data.inventory) or not data.equipment is Dictionary:
		return null
	for slot in data.equipment:
		var item: Variant = data.equipment[slot]
		if not _item(item) or item.is_empty():
			return null
		if (not InventoryRules.fits_slot(ItemData.get_item(int(item.id)), slot)
			or int(item.quantity) != 1 or world.hero.level < int(ItemData.get_item(int(item.id)).level)):
			return null
	world.hero.inventory.clear()
	for item in data.inventory:
		world.hero.inventory.append(_normalized_item(item))
	world.hero.equipment.clear()
	for slot in data.equipment:
		world.hero.equipment[slot] = _normalized_item(data.equipment[slot])
	if not _buffs(data.buffs) or not _restore_swing(world.hero.swing, data.hero_swing):
		return null
	world.hero.buffs = _normalized_buffs(data.buffs)
	if world.hero.equipment.has("main_hand") and world.hero.equipment.has("off_hand"):
		if ItemData.get_item(int(world.hero.equipment.main_hand.id)).two_handed:
			return null
	if world.hero.equipment.has("off_hand"):
		if ItemData.get_item(int(world.hero.equipment.off_hand.id)).weapon:
			return null
	world.hero.refresh_stats()
	world.hero.health = int(data.hero.health)
	world.hero.mana = int(data.hero.mana)
	if (world.hero.health <= 0 or world.hero.health > world.hero.max_health
		or world.hero.mana < 0 or world.hero.mana > world.hero.max_mana):
		return null
	if (not _number_map(data.vendor_stock, -1) or not _number_map(data.cooldowns, 0)
		or not _number_map(data.resistances, 0)):
		return null
	for key in data.vendor_stock:
		if not world.vendor_stock.has(key):
			return null
	if data.vendor_stock.size() != world.vendor_stock.size():
		return null
	world.vendor_stock = _normalized_numbers(data.vendor_stock)
	world.hero.cooldowns = _normalized_numbers(data.cooldowns)
	world.hero.resistances = _normalized_numbers(data.resistances)
	if not data.loot_quests is Array:
		return null
	for quest in data.loot_quests:
		if not quest is String:
			return null
		world.loot_quests.append(quest)
	if not data.restoration is Dictionary:
		return null
	for kind in data.restoration:
		var effect: Variant = data.restoration[kind]
		if kind not in ["food", "water"] or not _number_map(effect, 0):
			return null
		if not effect.has_all(["total", "duration", "started", "delivered"]):
			return null
		if effect.duration < 1 or effect.started > world.turn_count or effect.delivered > effect.total:
			return null
		world.hero.restoration[kind] = _normalized_numbers(effect)
	if not data.hotbar is Array or data.hotbar.size() != 5:
		return null
	world.hotbar.clear()
	for identifier in data.hotbar:
		if not identifier is String or (identifier != "" and not learned.has(identifier)):
			return null
		world.hotbar.append(StringName(identifier))
	if not data.periodic is Array:
		return null
	for effect in data.periodic:
		if not effect is Dictionary or not effect.has_all(["actor", "next", "remaining"]):
			return null
		if (not _integer(effect.actor, -1) or effect.actor >= world.actors.size()
			or not _integer(effect.next, world.turn_count + 1)
			or not _integer(effect.remaining, 1) or effect.remaining > 100):
			return null
		var identifier: Variant = effect.get("skill", "fireball_1")
		if not identifier is String:
			return null
		var skill := SkillRank.catalog(StringName(identifier))
		if skill == null or skill.periodic_damage <= 0:
			return null
		if int(effect.actor) == -1 and skill.effect != SkillRank.Effect.HEAL_OVER_TIME:
			return null
		if not _integer(effect.get("amount", 1), 0):
			return null
		world.periodic_effects.append({"actor": int(effect.actor), "skill": identifier,
			"next": int(effect.next), "remaining": int(effect.remaining),
			"amount": int(effect.get("amount", 1))})
	if not data.messages is Array or data.messages.size() > GridWorld.CHAT_LIMIT:
		return null
	for message in data.messages:
		if not message is String:
			return null
		world.messages.append(message)
	world.random.state = int(data.random)
	world.combat_random.state = int(data.combat_random)
	return world


static func _fields(object: Object, names: Array[String]) -> Dictionary:
	var result := {}
	for field in names:
		var value: Variant = object.get(field)
		if value is Vector2i:
			value = [value.x, value.y]
		elif value is Rect2i:
			value = [value.position.x, value.position.y, value.size.x, value.size.y]
		elif value is StringName:
			value = String(value)
		result[field] = value
	return result


static func _restore_fields(object: Object, data: Variant, names: Array[String]) -> bool:
	if not data is Dictionary:
		return false
	for field in names:
		if not data.has(field):
			return false
		var value: Variant = data[field]
		var prototype: Variant = object.get(field)
		match typeof(prototype):
			TYPE_INT:
				if not _integer(value, -2147483648):
					return false
				value = int(value)
			TYPE_FLOAT:
				if not (value is float or value is int) or not is_finite(float(value)):
					return false
				value = float(value)
			TYPE_STRING, TYPE_STRING_NAME:
				if not value is String:
					return false
				if prototype is StringName:
					value = StringName(value)
			TYPE_BOOL:
				if not value is bool:
					return false
			TYPE_VECTOR2I, TYPE_RECT2I:
				var count := 2 if prototype is Vector2i else 4
				if not value is Array or value.size() != count:
					return false
				for number in value:
					if not _integer(number, -2147483648):
						return false
				value = Vector2i(int(value[0]), int(value[1])) if count == 2 else Rect2i(
					int(value[0]), int(value[1]), int(value[2]), int(value[3]))
			_:
				return false
		object.set(field, value)
	return true


static func _integer(value: Variant, minimum: int) -> bool:
	return ((value is int or value is float) and is_finite(float(value))
		and float(value) == floor(float(value)) and value >= minimum and value <= 2147483647)


static func _tiles(data: Variant, target: Dictionary[Vector2i, bool], bounds: Rect2i) -> bool:
	if not data is Array:
		return false
	for pair in data:
		if (not pair is Array or pair.size() != 2
			or not _integer(pair[0], -2147483648) or not _integer(pair[1], -2147483648)):
			return false
		var tile := Vector2i(int(pair[0]), int(pair[1]))
		if not bounds.has_point(tile):
			return false
		target[tile] = true
	return true


static func _restore_swing(swing: SwingTimer, data: Variant) -> bool:
	if (not data is Array or data.size() != 2 or not data[1] is bool
		or not (data[0] is float or data[0] is int) or not is_finite(float(data[0]))
		or data[0] < 0):
		return false
	swing.remaining = float(data[0])
	swing._active = data[1]
	return true


static func _buffs(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in data:
		var skill := SkillRank.catalog(StringName(key))
		if skill == null or skill.effect != SkillRank.Effect.ARMOR:
			return false
		var buff: Variant = data[key]
		if not _number_map(buff, 0) or not buff.has_all(["armor", "until"]):
			return false
		for stat in buff:
			if stat not in ["armor", "until", "intellect", "strength", "agility", "stamina", "spirit", "thorns"]:
				return false
	return true


static func _item(item: Variant) -> bool:
	if not item is Dictionary:
		return false
	if item.is_empty():
		return true
	return (item.has_all(["id", "starter", "quantity"]) and _integer(item.id, 1)
		and not ItemData.get_item(int(item.id)).is_empty() and item.starter is bool
		and _integer(item.quantity, 1) and item.quantity <= int(ItemData.get_item(int(item.id)).stack))


static func _inventory(data: Variant) -> bool:
	if not data is Array or data.size() != 40:
		return false
	for item in data:
		if not _item(item):
			return false
	return true



static func _normalized_item(item: Dictionary) -> Dictionary:
	return {} if item.is_empty() else {
		"id": int(item.id), "quantity": int(item.quantity), "starter": item.starter}


static func _normalized_buffs(buffs: Dictionary) -> Dictionary:
	var result := {}
	for key in buffs:
		result[StringName(key)] = _normalized_numbers(buffs[key])
	return result


static func _number_map(data: Variant, minimum: int) -> bool:
	if not data is Dictionary:
		return false
	for key in data:
		if not key is String or not _integer(data[key], minimum):
			return false
	return true


static func _normalized_numbers(data: Dictionary) -> Dictionary:
	var result := {}
	for key in data:
		result[key] = int(data[key])
	return result
