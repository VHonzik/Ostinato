class_name SaveCodec
extends RefCounted

## Explicit demo save fields; JSON keeps RNG int64 values as decimal strings.
const WORLD_FIELDS: Array[String] = [
	"bounds", "player_tile", "movement_speed", "movement_credit", "turn_count",
	"global_cooldown_until", "stalker_schedule", "stalkers_arrived",
	"class_selected", "ever_accepted_quest", "hotbar_locked", "northshire", "trainer_referral_received",
]
const HERO_FIELDS: Array[String] = [
	"combo_points", "rage", "rage_credit", "rage_decay_credit", "last_hit_rage_turn",
	"last_enrage_roll_turn",
	"level", "experience", "health", "selected_class", "copper",
	"casting_credit", "facing", "potion_ready_turn",
]
const ACTOR_FIELDS: Array[String] = [
	"tile", "home_tile", "alive", "wander_area", "title", "relationship", "engaged",
	"returning_home", "blocked_turns", "aggro_range", "max_health", "health", "facing",
	"awards_experience", "corpse_visible", "died_on_turn", "service",
	"movement_credit", "story_guard", "stalker", "spawn_id", "loot_table", "loot_assigned",
	"loot_copper", "chest", "creature_type",
	"npc_id", "population_slot",
	"summon_kind", "summon_skill", "expires_turn",
	"stunned_until",
]
const MELEE_FIELDS: Array[String] = [
	"level", "player", "armor", "attack_power", "damage_min", "damage_max",
	"interval", "damage_multiplier", "critical", "dodge", "hit",
]


static func capture(session: GameSession) -> Dictionary:
	var world := session.world
	if world == null or world.is_terminal():
		return {}
	var data := {
		"seed": str(session.seed_value), "loop": session.loop_count,
		"world": _fields(world, WORLD_FIELDS), "hero": _fields(world.hero, HERO_FIELDS),
		"random": str(world.random.state), "combat_random": str(world.combat_random.state),
		"blocked": [], "sight": [], "actors": [], "learned": [],
		"equipment": world.hero.equipment.duplicate(true),
		"inventory": world.hero.inventory.duplicate(true),
		"buffs": world.hero.buffs.duplicate(true), "hotbar": [],
		"messages": Array(world.messages),
		"hero_swing": [world.hero.swing.remaining, world.hero.swing._active],
		"off_hand_swing": [world.hero.off_hand_swing.remaining, world.hero.off_hand_swing._active],
		"quests": world.quests.duplicate(true), "population": world.population.duplicate(true),
		"vendor_stock": world.vendor_stock.duplicate(true), "loot_quests": Array(world.loot_quests),
		"cooldowns": world.hero.cooldowns.duplicate(true),
		"restoration": world.hero.restoration.duplicate(true),
		"indoors": [],
		"debuffs": world.hero.debuffs.duplicate(true),
		"stalker_deadlines": world.stalker_deadlines.duplicate(),
		"valley_route": world.valley_route,
		"starter_gear_received": world.starter_gear_received,
		"war_horn_received": world.war_horn_received,
		"lucky_charm_received": world.lucky_charm_received,
		"ancestral_totem_received": world.ancestral_totem_received,
		"war_banner_received": world.war_banner_received,
		"war_banner": {},
		"consecration": {},
	}
	if not world.war_banner.is_empty():
		var banner := world.war_banner
		data.war_banner = {"tile": [banner.tile.x, banner.tile.y], "until": banner.until}
	if not world.consecration.is_empty():
		var ground := world.consecration
		data.consecration = {"center": [ground.center.x, ground.center.y],
			"until": ground.until, "next_tick": ground.next_tick, "damage": ground.damage}
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
			"wander_ready_turn": actor.wander_ready_turn,
			"swing": [actor.swing.remaining, actor.swing._active],
			"buffs": actor.buffs.duplicate(true), "loot": actor.loot.duplicate(true),
			"threat": actor.threat.duplicate(true), "debuffs": actor.debuffs.duplicate(true),
		})
	return data


static func restore(data: Variant, development_build: bool) -> GridWorld:
	if not _valid_envelope(data):
		return null
	var world := GridWorld.new(Rect2i(0, 0, 1, 1), Vector2i.ZERO, int(data.seed), false)
	# Restore into a new world. A failure never mutates the active session.
	if not _restore_world(world, data) or not _restore_hero_state(world, data):
		return null
	if not _restore_terrain(world, data) or not _restore_actors(world, data):
		return null
	# Preserve raw IDs too: release builds filter development skills from the hero,
	# but those saved IDs are still allowed in hotbar slots.
	var learned: Array[String] = []
	if not _restore_learning(world, data, development_build, learned):
		return null
	if not _restore_inventory(world, data) or not _restore_effects(world, data):
		return null
	if not _restore_merchants(world, data) or not _restore_action_state(world, data):
		return null
	if not _restore_ui(world, data, learned) or not _restore_quests(world, data):
		return null
	if not _restore_stalkers(world, data.get("stalker_deadlines")):
		return null
	world.random.state = int(data.random)
	world.combat_random.state = int(data.combat_random)
	# Development helpers belong to the running build, including saves predating a helper.
	if development_build:
		for skill in SkillDefinition.development_skills():
			if world.hero.find_skill(skill.id) == null:
				world.hero.learned_skills.append(skill)
	# Rebuild terminal state; a defeated group of stalkers must never resume play.
	world.check_terminal()
	return world


static func _valid_envelope(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var keys := ["seed", "loop", "world", "hero", "random", "combat_random",
		"blocked", "sight", "actors", "learned", "equipment", "inventory",
		"buffs", "hotbar", "messages", "hero_swing", "indoors",
		"vendor_stock", "loot_quests", "cooldowns", "restoration", "quests", "population", "debuffs", "off_hand_swing", "consecration"]
	for key in keys:
		if not data.has(key):
			return false
	for key in ["seed", "random", "combat_random"]:
		if (not data[key] is String or not data[key].is_valid_int()
			or str(int(data[key])) != data[key]):
			return false
	if not _integer(data.loop, 1):
		return false
	return true


static func _restore_world(world: GridWorld, data: Dictionary) -> bool:
	if not _restore_fields(world, data.world, WORLD_FIELDS):
		return false
	if not data.get("valley_route", false) is bool:
		return false
	world.valley_route = data.get("valley_route", false)
	if not data.get("starter_gear_received", false) is bool:
		return false
	world.starter_gear_received = data.get("starter_gear_received", false)
	if not data.get("war_horn_received") is bool:
		return false
	world.war_horn_received = data.war_horn_received
	if not data.get("lucky_charm_received", false) is bool:
		return false
	world.lucky_charm_received = data.get("lucky_charm_received", false)
	if not data.get("ancestral_totem_received") is bool:
		return false
	world.ancestral_totem_received = data.ancestral_totem_received
	if not data.get("war_banner_received", false) is bool:
		return false
	world.war_banner_received = data.get("war_banner_received", false)
	if world.valley_route:
		if world.bounds != ValleyRoute.BOUNDS or not world.northshire:
			return false
		ValleyRoute.build_terrain(world)
		# Collision and indoor state below come from the saved attempt.
		world.blocked_tiles.clear()
		world.sight_blockers.clear()
		world.indoor_tiles.clear()
	if (world.bounds.size.x < 1 or world.bounds.size.y < 1
		or world.bounds.size.x > 1024 or world.bounds.size.y > 1024
		or not world.bounds.has_point(world.player_tile)
		or world.turn_count < 0 or world.movement_speed <= 0 or world.movement_credit < 0):
		return false
	return true


static func _restore_hero_state(world: GridWorld, data: Dictionary) -> bool:
	if not _restore_fields(world.hero, data.hero, HERO_FIELDS):
		return false
	if (world.hero.combo_points < 0 or world.hero.combo_points > HeroState.MAX_COMBO_POINTS
		or world.hero.rage < 0 or world.hero.rage > HeroState.MAX_RAGE
		or world.hero.rage_credit < 0.0 or world.hero.rage_credit >= 1.0
		or world.hero.rage_decay_credit < 0.0 or world.hero.rage_decay_credit >= 1.0
		or world.hero.last_hit_rage_turn < -1 or world.hero.last_hit_rage_turn > world.turn_count
		or world.hero.last_enrage_roll_turn < -1 or world.hero.last_enrage_roll_turn > world.turn_count
		or world.hero.level < 1
		or world.hero.experience < 0 or world.hero.copper < 0
		or world.hero.potion_ready_turn < 0
		or world.hero.casting_credit < 0 or world.hero.casting_credit >= 1.0
		or world.hero.selected_class not in ClassSkillData.CLASSES):
		return false
	if (world.hero.selected_class in ClassSkillData.PLAYABLE_CLASSES
		and int(data.loop) == 1 and world.hero.selected_class != &"Warrior"):
		return false
	world.hero._apply_level_stats()
	if world.hero.experience >= world.hero.experience_to_next_level():
		return false
	return true


static func _restore_terrain(world: GridWorld, data: Dictionary) -> bool:
	if not _tiles(data.indoors, world.indoor_tiles, world.bounds):
		return false
	if not _tiles(data.blocked, world.blocked_tiles, world.bounds):
		return false
	if not _tiles(data.sight, world.sight_blockers, world.bounds):
		return false
	if world.blocked_tiles.has(world.player_tile):
		return false
	return true


static func _restore_actors(world: GridWorld, data: Dictionary) -> bool:
	if not data.actors is Array or data.actors.size() > 1000:
		return false
	for record in data.actors:
		if (not record is Dictionary or not record.has_all(["state", "melee", "swing", "buffs", "loot", "threat", "debuffs"])):
			return false
		var actor := GridActor.new(Vector2i.ZERO)
		if not _restore_fields(actor, record.state, ACTOR_FIELDS):
			return false
		# Saves from before idle pacing have no deadline yet; stagger on the first idle turn.
		var wander_ready: Variant = record.get("wander_ready_turn", -1)
		if (not _integer(wander_ready, -1)
			or int(wander_ready) > world.turn_count + GridWorld.WANDER_MAX_TURNS):
			return false
		actor.wander_ready_turn = int(wander_ready)
		var contact := NpcDefinition.find(actor.npc_id)
		if world.valley_route and contact != null and contact.refresh_saved_name:
			actor.title = contact.title
		if not _restore_fields(actor.melee, record.melee, MELEE_FIELDS):
			return false
		if not _restore_swing(actor.swing, record.swing) or not _buffs(record.buffs):
			return false
		if (not world.bounds.has_point(actor.tile) or not world.bounds.has_point(actor.home_tile)
			or actor.max_health <= 0 or actor.health < 0 or actor.health > actor.max_health
			or actor.relationship < 0 or actor.relationship > 2
			or actor.melee.level < 1 or actor.melee.interval <= 0
			or actor.melee.armor < 0 or actor.melee.damage_min < 0
			or actor.melee.damage_max < actor.melee.damage_min
			or actor.movement_credit < 0 or actor.blocked_turns < 0
			or (actor.alive and not world.is_open(actor.tile))):
			return false
		if not record.loot is Array or record.loot.size() > 100:
			return false
		for item in record.loot:
			if not _item(item) or item.is_empty():
				return false
			actor.loot.append(_normalized_item(item))
		if actor.loot_copper < 0:
			return false
		if not _number_map(record.threat, 0) or not _debuffs(record.debuffs):
			return false
		for key in record.threat:
			if not key.is_valid_int() or int(key) < -1 or int(key) >= data.actors.size():
				return false
		actor.threat = _normalized_numbers(record.threat)
		actor.debuffs = _normalized_buffs(record.debuffs)
		if (actor.summon_kind not in ["", "earth_elemental", "wolf"]
			or actor.expires_turn < 0 or actor.stunned_until < 0):
			return false
		if actor.summon_kind != "":
			var summon := SummonRules.definition(actor)
			if (summon == null or (summon.effect != SkillDefinition.Effect.SUMMON and summon.family != &"feral_spirit")
				or SummonRules.slot(summon) != actor.summon_kind
				or actor.relationship != GridActor.Relationship.FRIENDLY or actor.awards_experience):
				return false
			if actor.alive and actor.summon_kind != "wolf" and SummonRules.active(world, actor.summon_kind) != null:
				return false
			if actor.summon_kind == "earth_elemental" and actor.expires_turn != 0:
				return false
			if actor.alive and actor.summon_kind == "wolf":
				var wolves := world.actors.filter(func(other: GridActor) -> bool:
					return other.alive and other.summon_kind == "wolf")
				if wolves.size() >= 2:
					return false
		actor.buffs = _normalized_buffs(record.buffs)
		world._hide_empty_corpse(actor)
		world.actors.append(actor)
	return true


static func _restore_learning(world: GridWorld, data: Dictionary,
	development_build: bool, learned: Array[String]) -> bool:
	if not data.learned is Array or data.learned.size() > 1000:
		return false
	world.hero.learned_skills.clear()
	for identifier in data.learned:
		if not identifier is String or learned.has(identifier):
			return false
		var skill := SkillDefinition.catalog(StringName(identifier))
		if skill == null:
			return false
		if (world.hero.selected_class in ClassSkillData.PLAYABLE_CLASSES
			and not skill.development_only and not ClassSkillData.is_playable_skill(skill.id)):
			return false
		learned.append(identifier)
		if development_build or not skill.development_only:
			world.hero.learned_skills.append(skill)
	# New classes may be saved before visiting their trainer, or after learning one starter.
	var mandatory: Array = ClassSkillData.STARTERS[&"Warrior"]
	for identifier: StringName in mandatory:
		if not learned.has(String(identifier)):
			return false
	if world.hero.combo_points > 0 and not learned.has("relentless_assault_1"):
		return false
	return true


static func _restore_inventory(world: GridWorld, data: Dictionary) -> bool:
	if not _inventory(data.inventory) or not data.equipment is Dictionary:
		return false
	for slot in data.equipment:
		var item: Variant = data.equipment[slot]
		if not _item(item) or item.is_empty():
			return false
		if (not InventoryRules.fits_slot(ItemData.get_item(int(item.id)), slot)
			or int(item.quantity) != 1):
			return false
	world.hero.inventory.clear()
	for item in data.inventory:
		world.hero.inventory.append(_normalized_item(item))
	world.hero.equipment.clear()
	for slot in data.equipment:
		world.hero.equipment[slot] = _normalized_item(data.equipment[slot])
	return true


static func _restore_effects(world: GridWorld, data: Dictionary) -> bool:
	if (not _buffs(data.buffs) or not _restore_swing(world.hero.swing, data.hero_swing)
		or not _restore_swing(world.hero.off_hand_swing, data.off_hand_swing)):
		return false
	world.hero.buffs = _normalized_buffs(data.buffs)
	for key in world.hero.buffs:
		if ((ClassToolkitData.PASSIVES.has(String(key)) or ClassToolkitData.ACTIVES.has(String(key)))
			and (world.hero.find_skill(key) == null
				or (int(world.hero.buffs[key].until) > 0
					and int(world.hero.buffs[key].until) <= world.turn_count))):
			return false
	for actor in world.actors:
		if (actor.summon_kind != "" and actor.summon_skill != ItemData.ANCESTRAL_TOTEM_HOTBAR_ID
			and world.hero.find_skill(actor.summon_skill) == null):
			return false
		if actor.debuffs.has(&"deadly_poison_1") and world.hero.find_skill(&"deadly_poison_1") == null:
			return false
		if actor.debuffs.has(&"execution_sentence_1"):
			var sentence := world.hero.find_skill(&"execution_sentence_1")
			var effect: Dictionary = actor.debuffs[&"execution_sentence_1"]
			if (sentence == null or not actor.alive or actor.relationship == GridActor.Relationship.FRIENDLY
				or int(effect.until) <= world.turn_count
				or int(effect.until) > world.turn_count + sentence.delay_turns):
				return false
	if not _debuffs(data.debuffs) or data.debuffs.has("deadly_poison_1"):
		return false
	if (data.debuffs.has("execution_sentence_1") or not _restore_consecration(world, data.consecration)
		or not _restore_war_banner(world, data.get("war_banner", {}))):
		return false
	world.hero.debuffs = _normalized_buffs(data.debuffs)
	world.hero.refresh_stats()
	world.hero.health = int(data.hero.health)
	if (world.hero.health <= 0 or world.hero.health > world.hero.max_health):
		return false
	return true


static func _restore_merchants(world: GridWorld, data: Dictionary) -> bool:
	if not data.vendor_stock is Dictionary:
		return false
	var initial_stock := MerchantData.initial_stock(world.actors)
	if data.vendor_stock.size() != initial_stock.size():
		return false
	# A merchant instance owns its stock; duplicate identities cannot share a pool.
	var merchant_ids: Array[String] = []
	for actor in world.actors:
		if actor.service != &"Trader":
			continue
		if (actor.spawn_id.is_empty() or merchant_ids.has(actor.spawn_id)
			or MerchantData.catalog(actor.npc_id).is_empty()):
			return false
		merchant_ids.append(actor.spawn_id)
	for merchant_id in initial_stock:
		if not data.vendor_stock.has(merchant_id):
			return false
		var stock: Variant = data.vendor_stock[merchant_id]
		var initial: Dictionary = initial_stock[merchant_id]
		if not _number_map(stock, -1) or stock.size() != initial.size():
			return false
		for key in initial:
			if not stock.has(key):
				return false
			if (int(initial[key]) == -1 and stock[key] != -1
				or int(initial[key]) >= 0 and (stock[key] < 0 or stock[key] > initial[key])):
				return false
		world.vendor_stock[merchant_id] = _normalized_numbers(stock)
	return true


static func _restore_action_state(world: GridWorld, data: Dictionary) -> bool:
	if not _number_map(data.cooldowns, 0):
		return false
	world.hero.cooldowns = _normalized_numbers(data.cooldowns)
	if not data.restoration is Dictionary:
		return false
	for kind in data.restoration:
		var effect: Variant = data.restoration[kind]
		if kind != "food" or not _number_map(effect, 0):
			return false
		if not effect.has_all(["total", "duration", "started", "delivered"]):
			return false
		if effect.duration < 1 or effect.started > world.turn_count or effect.delivered > effect.total:
			return false
		world.hero.restoration[kind] = _normalized_numbers(effect)
	return true


static func _restore_ui(world: GridWorld, data: Dictionary, learned: Array[String]) -> bool:
	if not data.hotbar is Array or data.hotbar.size() != GridWorld.HOTBAR_SIZE:
		return false
	world.hotbar.clear()
	for identifier in data.hotbar:
		if not identifier is String:
			return false
		if (identifier != "" and identifier != String(GridWorld.FOOD_HOTBAR_ID)
			and identifier != String(ItemData.WAR_HORN_HOTBAR_ID)
			and identifier != String(ItemData.ANCESTRAL_TOTEM_HOTBAR_ID)
			and identifier != String(ItemData.WAR_BANNER_HOTBAR_ID)
			and not learned.has(identifier)
			and world.hero.find_skill(StringName(identifier)) == null):
			return false
		world.hotbar.append(StringName(identifier))
	if not data.messages is Array or data.messages.size() > GridWorld.CHAT_LIMIT:
		return false
	for message in data.messages:
		if not message is String:
			return false
		world.messages.append(message)
	return true


static func _restore_quests(world: GridWorld, data: Dictionary) -> bool:
	if not data.loot_quests is Array:
		return false
	for quest in data.loot_quests:
		if not quest is String:
			return false
		world.loot_quests.append(quest)
	if (not QuestRules.restore(world, data.quests) or not data.population is Array
		or not data.population.is_empty()
		or world.actors.any(func(actor: GridActor) -> bool: return actor.population_slot != -1)):
		return false
	return true


static func _restore_stalkers(world: GridWorld, deadlines: Variant) -> bool:
	if (not deadlines is Array or deadlines.size() != GridWorld.STALKER_DEADLINES.size()
		or world.stalkers_arrived < 0 or world.stalkers_arrived > deadlines.size()):
		return false
	var expected := ValleyRoute.STALKER_DEADLINES if world.valley_route else GridWorld.STALKER_DEADLINES
	world.stalker_deadlines.clear()
	for index in range(deadlines.size()):
		if (not _integer(deadlines[index], 1)
			or int(deadlines[index]) != expected[index]):
			return false
		world.stalker_deadlines.append(int(deadlines[index]))
	var identities: Array[String] = []
	for actor in world.actors:
		if not actor.spawn_id.begins_with("gate/stalker/"):
			continue
		if not actor.stalker or actor.summon_kind != "" or identities.has(actor.spawn_id):
			return false
		identities.append(actor.spawn_id)
	if identities.size() != world.stalkers_arrived:
		return false
	for index in range(world.stalkers_arrived):
		if (identities[index] != "gate/stalker/%d" % index
			or world.stalker_deadlines[index] > world.turn_count):
			return false
	return true


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
		var skill := SkillDefinition.catalog(StringName(key))
		if skill == null or skill.effect not in [SkillDefinition.Effect.ARMOR, SkillDefinition.Effect.BATTLE_SHOUT, SkillDefinition.Effect.PASSIVE]:
			return false
		var buff: Variant = data[key]
		if not _number_map(buff, 0) or not buff.has_all(["armor", "until"]):
			return false
		if int(buff.until) == 0 and (skill.effect != SkillDefinition.Effect.PASSIVE or skill.duration != 0):
			return false
		for stat in buff:
			if stat not in ["armor", "until", "strength", "agility", "stamina",
				"charges", "ready", "weapon_id", "off_weapon_id", "physical_percent",
				"haste_percent", "critical_percent", "immunity", "bonus_percent", "critical_ready"]:
				if stat not in ["main_until", "off_until"] or not PoisonRules.is_poison(skill):
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
		result[key] = float(data[key]) if key == "damage_credit" else int(data[key])
	return result


static func _restore_war_banner(world: GridWorld, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		return true
	if (data.size() != 2 or not data.has_all(["tile", "until"])
		or not data.tile is Array or data.tile.size() != 2
		or not _integer(data.tile[0], -2147483648) or not _integer(data.tile[1], -2147483648)
		or not _integer(data.until, world.turn_count + 1)
		or int(data.until) > world.turn_count + int(ItemData.get_item(ItemData.WAR_BANNER_ID).duration)):
		return false
	var tile := Vector2i(int(data.tile[0]), int(data.tile[1]))
	if not world.bounds.has_point(tile) or world.blocked_tiles.has(tile):
		return false
	world.war_banner = {"tile": tile, "until": int(data.until)}
	return true


static func _restore_consecration(world: GridWorld, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		return true
	var skill := world.hero.find_skill(&"consecration_1")
	if (skill == null or data.size() != 4
		or not data.has_all(["center", "until", "next_tick", "damage"])
		or not data.center is Array or data.center.size() != 2
		or not _integer(data.center[0], -2147483648) or not _integer(data.center[1], -2147483648)
		or not _integer(data.until, world.turn_count + 1)
		or int(data.until) > world.turn_count + skill.duration
		or not _integer(data.next_tick, world.turn_count + 1)
		or int(data.next_tick) != world.turn_count + 1
		or not (data.damage is float or data.damage is int)
		or not is_finite(float(data.damage)) or data.damage < 0):
		return false
	var center := Vector2i(int(data.center[0]), int(data.center[1]))
	if not world.bounds.has_point(center) or world.blocked_tiles.has(center):
		return false
	world.consecration = {"center": center, "until": int(data.until),
		"next_tick": int(data.next_tick), "damage": float(data.damage)}
	return true


static func _debuffs(data: Variant) -> bool:
	if not data is Dictionary or data.size() > 100:
		return false
	for key in data:
		if not key is String or not data[key] is Dictionary or not data[key].has("until"):
			return false
		var effect: Dictionary = data[key].duplicate()
		if key == "execution_sentence_1":
			if (effect.size() != 3 or not effect.has_all(["until", "damage", "critical"])
				or not _integer(effect.until, 1) or not _integer(effect.damage, 0)
				or not _integer(effect.critical, 0) or effect.critical > 1):
				return false
			continue
		if key == "deadly_poison_1":
			if not effect.has_all(["stacks", "next_tick", "damage_credit"]):
				return false
			var credit: Variant = effect.damage_credit
			if (not (credit is int or credit is float) or not is_finite(float(credit))
				or credit < 0 or credit >= 1 or not _integer(effect.stacks, 1)
				or effect.stacks > SkillDefinition.catalog(&"deadly_poison_1").maximum
				or not _integer(effect.next_tick, 1) or not _integer(effect.until, 1)
				or effect.next_tick > effect.until):
				return false
			effect.erase("damage_credit")
		if not _number_map(effect, 0):
			return false
		for field in data[key]:
			if field not in ["until", "bonus"]:
				if key != "deadly_poison_1" or field not in ["stacks", "next_tick", "damage_credit"]:
					return false
	return true
