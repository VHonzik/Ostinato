extends "res://bench/paladin_sim.gd"

const PriorityWorld = preload("res://bench/priority_world.gd")
const CURRENT_CASES: Array[Dictionary] = [
	{"id": "1xL4", "hero_level": 3, "profile": "38", "count": 1},
	{"id": "2xL4", "hero_level": 3, "profile": "38", "count": 2},
	{"id": "3xL4", "hero_level": 3, "profile": "38", "count": 3},
	{"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1},
	{"id": "Pull", "hero_level": 3, "profile": "38", "count": 1},
	{"id": "Durable3", "hero_level": 3, "profile": "38", "count": 3, "health_scale": 3},
	{"id": "BankedPull", "hero_level": 3, "profile": "38", "count": 1},
]
var case_id: String = ""
var variants: Array[String] = ["intent", "ms_first", "four_stacks", "judge_first", "haste_first"]


func _initialize() -> void:
	samples = 30
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
	builds = ["Shaman starter", "Shaman", "Paladin", "Warrior+Shaman+Paladin",
		"Warrior+Shaman+Rogue", "Warrior+Paladin+Rogue", "Shaman+Paladin+Rogue", "All"]
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	var expected_cells := 0
	for category in builds:
		build = category
		selected_class = &"Warrior" if build == "All" else StringName(build.get_slice("+", 0).get_slice(" ", 0))
		for policy in variants:
			if build != "All" and policy != "intent":
				continue
			for weapon in range(3):
				if shard >= 0 and weapon != shard:
					continue
				for prepared in [false, true]:
					for index in range(CURRENT_CASES.size()):
						if build != "All" and index >= 5:
							continue
						var encounter := CURRENT_CASES[index]
						case_id = encounter.id
						expected_cells += 1
						_measure(encounter, index, weapon, prepared, case_id == "Stalker", policy)
						rows[-1].build = build
						rows[-1].variant = policy
	var setup := {"samples": samples, "builds": builds, "variants": variants,
		"cases": CURRENT_CASES, "expected_cells": expected_cells, "weapons": WEAPONS,
		"entry": "Cold: zero rage, full health, no buffs. Prepared: cast known poisons, Windfury, Shield, Shout last from zero rage. Real turns, decay and regeneration; no health refill. Mixed coatings for DW. No points/procs/stacks except BankedPull's declared five Maelstrom. Preparation turns saved separately.",
		"rules": "Live production rules only. Shaman starter knows only its free pair. Other named kits fully learned; initial Warrior learning cleared. Selected class is first named class. Common gear; hero level 3 for thugs and 5 for Stalker. One minor potion only against Stalker. No gift items.",
		"policies": "Live Stalker: sidestep marked Fel Breath before other actions, cancelling interruptible commitments if needed. Intent: emergency defenses/potion; Charge then Juggernaut MS; full Lava; empowered Judgement on durable target; 5CP Eviscerate; Execute; empty Shield; WW and ground at 3+; MS; other actions. Alternate policies change one priority: MS first, spend Lava at 4+, empowered Judgement before Lava, or 5CP finisher before payoffs when haste is absent. These comparisons run only on All; every build runs intent.",
		"cases_detail": "Ordinary groups adjacent. Stalker starts six away, Charge if known. Pull starts six away with Charge unavailable. Durable3 triples only thug HP, a synthetic stress case. BankedPull seeds five Maelstrom stacks. Durable3/BankedPull only on All.",
		"accounting": "Every measured fight reconciles enemy HP and player HP/healing. First ten seeds per cell replay on plain GridWorld, including RNG state. Observer world never changes combat. Preparation and active decisions recorded.",
		"limitations": "Fixed bots, isolated fights and common gear; no route, reinforcements, XP, level-up healing or uncommon gear. No final balance, visual or human acceptance claim."}
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE priorities: %d cells, %d fights, %d plain-world replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	return (PriorityWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
		if traced else GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false))


func _learn_skills(hero: HeroState) -> void:
	hero.learned_skills.clear()
	if build == "Shaman starter":
		hero.learned_skills.append_array(SkillDefinition.starting_skills(&"Shaman"))
		return
	for category in ClassSkillData.PLAYABLE_CLASSES:
		if build != "All" and String(category) not in build.split("+"):
			continue
		for skill in kit_skills[category]:
			hero.learned_skills.append(SkillDefinition.catalog(skill.id))


func _prepare(world: GridWorld) -> void:
	if world.hero.find_skill(&"instant_poison_1") != null:
		assert(world.cast_skill(&"instant_poison_1"))
		if world.hero.has_off_hand_weapon() and world.hero.find_skill(&"deadly_poison_1") != null:
			var weapon := ItemData.get_item(world.hero.weapon_id())
			var slower := PoisonRules.Hands.OFF if weapon.interval < weapon.off_interval else PoisonRules.Hands.MAIN
			assert(world.cast_skill(&"deadly_poison_1", null, slower))
	for id in [&"windfury_weapon_1", &"lightning_shield_1", &"battle_shout_1"]:
		if world.hero.find_skill(id) != null:
			assert(world.cast_skill(id))


func _open_battle(world: GridWorld, enemies: Array[GridActor]) -> void:
	if case_id == "Stalker":
		enemies[0].tile = world.player_tile + Vector2i(0, -6)
		enemies[0].home_tile = enemies[0].tile
		if world.hero.find_skill(&"charge_1") != null:
			assert(world.cast_skill(&"charge_1", enemies[0]))


func _battle_metrics(world: GridWorld) -> Dictionary:
	return (world as PriorityWorld).metrics() if world is PriorityWorld else {}


func _priority_choices(world: GridWorld, target: GridActor, living: Array,
	policy: String) -> Array[StringName]:
	var hero := world.hero
	var choices: Array[StringName] = []
	if hero.health * 2 < hero.max_health:
		for id in [&"divine_shield_1", &"evasion_1"]:
			if not hero.buffs.has(id):
				choices.append(id)
	if hero.buffs.has(&"juggernaut_1") or policy == "ms_first":
		choices.append(&"mortal_strike_1")
	var durable := target.health > 3.0 * MeleeRules.weapon_damage(hero.melee, 0.5) / hero.melee.interval
	var boosted := int(hero.buffs.get(&"art_of_war_1", {}).get("critical_ready", 0)) > 0
	if policy == "judge_first" and durable and boosted:
		choices.append(&"judgement_1")
	if policy == "haste_first" and hero.combo_points == 5 and not hero.buffs.has(&"slice_and_dice_1"):
		choices.append(&"eviscerate_1")
	if ClassToolkitRules.maelstrom_stacks(hero) >= (4 if policy == "four_stacks" else 5):
		choices.append(&"lava_burst_1")
	if durable and boosted:
		choices.append(&"judgement_1")
	if hero.combo_points == 5:
		choices.append(&"eviscerate_1")
	choices.append(&"execute_1")
	if not hero.buffs.has(&"lightning_shield_1"):
		choices.append(&"lightning_shield_1")
	var adjacent := 0
	for enemy: GridActor in living:
		adjacent += int(ClassToolkitRules.eligible(world, enemy, 1))
	if adjacent >= 3:
		choices.append_array([&"whirlwind_1", &"consecration_1"])
	choices.append(&"mortal_strike_1")
	if durable:
		choices.append(&"judgement_1")
	choices.append(&"feral_spirit_1")
	if GridWorld.tile_distance(world.player_tile, target.tile) > 1:
		choices.append(&"lava_burst_1")
	for id in [&"battle_shout_1", &"windfury_weapon_1", &"instant_poison_1"]:
		if not hero.buffs.has(id):
			choices.append(id)
	if durable and not PaladinRules.covers(world, target.tile):
		choices.append(&"consecration_1")
	if hero.rage >= 45:
		choices.append(&"whirlwind_1")
	return choices


func _battle(encounter: Dictionary, weapon: int, prepared: bool, potion: bool,
	policy: String, seed_value: int, traced: bool) -> Dictionary:
	var world := _create_world(seed_value, traced)
	var hero := world.hero
	hero.level = int(encounter.hero_level)
	hero.selected_class = selected_class
	_learn_skills(hero)
	hero.equipment.clear()
	var gear := {"armor": 85, "neck": 70001, "ring_1": 70002,
		"ring_2": 70003, "weapons": WEAPONS[weapon]}
	for slot: String in gear:
		hero.equipment[slot] = ItemData.instance(int(gear[slot]))
	hero.refresh_stats()
	hero.health = hero.max_health
	hero.rage = 0
	hero.inventory[0] = ItemData.instance(118, 1) if potion else {}
	if prepared:
		_prepare(world)
	var entry_turn := world.turn_count
	var enemies: Array[GridActor] = []
	if encounter.profile == "stalker":
		world._spawn_stalker(world.player_tile + Vector2i.UP)
		enemies.append(world.actors[0])
	else:
		var data: Dictionary = NorthshireData.CREATURES[encounter.profile]
		for index in range(int(encounter.count)):
			var enemy := GridActor.new(world.player_tile + GridWorld.DIRECTIONS[index * 2])
			enemy.relationship = GridActor.Relationship.HOSTILE
			enemy.engaged = true
			enemy.max_health = int(data.health) * int(encounter.get("health_scale", 1))
			enemy.health = enemy.max_health
			enemy.melee.level = int(data.level)
			enemy.melee.armor = int(data.armor)
			enemy.melee.damage_min = float(data.minimum)
			enemy.melee.damage_max = float(data.maximum)
			enemy.melee.attack_power = int(data.power)
			enemy.melee.interval = float(data.interval)
			world.actors.append(enemy)
			enemies.append(enemy)
	var initial_hp := 0
	for index in range(enemies.size()):
		enemies[index].title = "Target %d" % index
		enemies[index].awards_experience = false
		initial_hp += enemies[index].health
	if traced:
		(world as PaladinWorld).watch(enemies)
	if encounter.id in ["Pull", "BankedPull"]:
		enemies[0].tile = world.player_tile + Vector2i(0, -6)
		enemies[0].home_tile = enemies[0].tile
		hero.cooldowns["charge"] = 999
		if encounter.id == "BankedPull":
			if hero.find_skill(&"maelstrom_weapon_1") != null:
				hero.buffs[&"maelstrom_weapon_1"] = {"armor": 0, "until": 0, "charges": 5}
	else:
		_open_battle(world, enemies)
	while not world.is_terminal() and world.turn_count < 300:
		var living := enemies.filter(func(enemy: GridActor) -> bool: return enemy.alive)
		if living.is_empty():
			break
		if StalkerDodge.try_dodge(world):
			continue
		if world.pending_skill != null:
			world.continue_cast()
			continue
		if world.pending_melee != null:
			world.continue_melee()
			continue
		if potion and not hero.inventory[0].is_empty() and hero.max_health - hero.health >= 40:
			assert(world.consume_item(0))
			continue
		var target: GridActor = living[0]
		if _try_item_action(world, target):
			continue
		var choices := _priority_choices(world, target, living, policy)
		var acted := false
		for id in choices:
			var skill := hero.find_skill(id)
			if skill == null or skill.cost(hero) > hero.rage:
				continue
			if int(hero.cooldowns.get(String(world.cooldown_family(skill)), 0)) > world.turn_count:
				continue
			if id == &"feral_spirit_1" and world.actors.any(
				func(actor: GridActor) -> bool: return actor.alive and actor.summon_kind == "wolf"):
				continue
			var candidate: GridActor = target if skill.target == SkillDefinition.Target.ENEMY else null
			if not world.valid_spell_target(skill, candidate) or not SpellEffects.can_apply(world, skill, candidate):
				continue
			if world.cast_skill(id, candidate):
				acted = true
				break
		if not acted:
			if world.auto_attack_target != target:
				if not world.request_melee(target):
					var route := world.charge_route(target)
					if route.size() > 1 and StalkerDodge.safe_to_move(world, route[1] - world.player_tile):
						assert(world.move_player(route[1] - world.player_tile))
					else:
						world.wait_turn()
			else:
				var route := world.charge_route(target)
				if (GridWorld.tile_distance(world.player_tile, target.tile) > 1 and route.size() > 1
					and StalkerDodge.safe_to_move(world, route[1] - world.player_tile)):
					assert(world.move_player(route[1] - world.player_tile))
				else:
					world.wait_turn()
	var enemy_hp := 0
	for enemy in enemies:
		enemy_hp += enemy.health
	assert(world.turn_count < 300 or enemy_hp == 0 or hero.health == 0)
	var result := {"seed": seed_value, "win": enemy_hp == 0, "hp": hero.health,
		"enemy_hp": enemy_hp, "turns": world.turn_count - entry_turn,
		"preparation_turns": entry_turn, "rage": hero.rage,
		"combat_random": str(world.combat_random.state)}
	if traced:
		var trace := world as PaladinWorld
		assert(trace.valid_accounting and trace.damage_total == initial_hp - enemy_hp)
		result.merge({"damage": trace.damage.duplicate(true), "damage_total": trace.damage_total,
			"casts": trace.casts.duplicate(), "activations": trace.activations.duplicate()})
	if traced and world is PriorityWorld:
		var observer := world as PriorityWorld
		result.merge({"stack_gains": observer.stack_gains, "full_lava": observer.full_lava,
			"decisions": observer.decision_log, "remaining_stacks": ClassToolkitRules.maelstrom_stacks(hero)})
	result.merge(_battle_metrics(world))
	world.discard()
	return result


func _try_item_action(_world: GridWorld, _target: GridActor) -> bool:
	return false
