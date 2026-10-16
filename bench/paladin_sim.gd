extends "res://bench/warrior_identity_sim.gd"

const PaladinWorld = preload("res://bench/paladin_world.gd")
const ENCOUNTERS: Array[Dictionary] = [
	{"id": "1xL4", "hero_level": 3, "profile": "38", "count": 1},
	{"id": "3xL4", "hero_level": 3, "profile": "38", "count": 3},
	{"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1},
]
var build: String = "Paladin"
var kit_skills: Dictionary = {}


func _initialize() -> void:
	samples = 100
	pilot_samples = 20
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
			pilot_samples = 2
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	for category in ["Paladin", "Warrior+Paladin", "All"]:
		build = category
		for weapon in range(3):
			if shard >= 0 and weapon != shard:
				continue
			for prepared in [false, true]:
				for index in range(ENCOUNTERS.size()):
					var encounter := ENCOUNTERS[index]
					var policy := _choose_policy(encounter, weapon, prepared)
					_measure(encounter, index, weapon, prepared,
						encounter.id == "Stalker", policy)
					rows[-1].build = build
	var setup := {"samples_per_cell": samples, "pilot_samples_per_policy": pilot_samples,
		"cases": ENCOUNTERS, "weapons": WEAPONS,
		"gear": "Common armor 85, neck 70001, rings 70002/70003; weapon 5579/5580/2224.",
		"kits": "Full named kits. Paladin-only clears initial Warrior learning. Selected Paladin.",
		"entry": "All enemies adjacent and hostile. Cold: full HP, zero rage, no buffs. Prepared: full HP, 90 rage, known maintenance buffs and mixed poisons; no assigned procs, combo points or summons.",
		"policies": "Choose Holy-first, physical-first or Holy-first without ground on %d independent pilot seeds per policy. Maintain buffs, use defenses below 50%% HP, summon allies and spend combo points at 3+. Holy-first: Sentence, ground, Shock, Mortal Strike. Physical-first: Mortal Strike, Shock, Sentence, ground. Follow targets without kiting." % pilot_samples,
		"potions": "One Minor Healing Potion in Stalker fights, used at 40+ missing HP.",
		"seeds": "Same as warrior bench: pilot 1500000 (+10000 for Stalker); measured 1600000 + encounter_index*10000 + fight_index. Shared across builds and weapon/entry states.",
		"accounting": "Pooled effective enemy HP removed, overkill excluded. Passives embedded. First up to 10 seeds per cell replayed on plain GridWorld, checking outcomes, HP, turns, rage, class XP and RNG.",
		"limitations": "Fixed stationary bot policies; isolated fights, no reinforcement schedule, route, kill XP, level-up heals or uncommon gear. Prepared entry constructed. Exploratory comparisons, not balance acceptance."}
	if not BenchIO.write_result({"setup": setup, "pilots": pilots, "rows": rows,
		"replayed": replayed, "seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE Paladin: %d cells, %d fights, %d replays" % [
		rows.size(), rows.size() * samples, replayed])
	quit()


func _choose_policy(encounter: Dictionary, weapon: int, prepared: bool) -> String:
	var chosen := "holy"
	var best := [-1, -100000000, -1]
	for policy in ["holy", "physical", "no_ground"]:
		var score := [0, 0, 0]
		for index in range(pilot_samples):
			var result := _battle(encounter, weapon, prepared, encounter.id == "Stalker",
				policy, 1500000 + (10000 if encounter.id == "Stalker" else 0) + index, true)
			score[0] += int(result.win)
			score[1] -= int(result.enemy_hp)
			score[2] += int(result.hp)
		pilots.append({"build": build, "case": encounter.id, "weapon": STYLES[weapon],
			"prepared": prepared, "policy": policy, "score": score})
		if score[0] > best[0] or (score[0] == best[0] and (score[1] > best[1]
			or (score[1] == best[1] and score[2] > best[2]))):
			best = score
			chosen = policy
	return chosen


func _battle(encounter: Dictionary, weapon: int, prepared: bool, potion: bool,
	policy: String, seed_value: int, traced: bool) -> Dictionary:
	var world: GridWorld = (PaladinWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12),
		seed_value, false) if traced else
		GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false))
	var hero := world.hero
	hero.level = int(encounter.hero_level)
	hero.selected_class = &"Paladin"
	hero.learned_skills.clear()
	for category in ClassSkillData.PLAYABLE_CLASSES:
		if build == "Paladin" and category != &"Paladin":
			continue
		if build == "Warrior+Paladin" and category not in [&"Warrior", &"Paladin"]:
			continue
		hero.class_progress[category] = 1000
		for skill in kit_skills[category]:
			hero.learned_skills.append(skill)
	hero.equipment.clear()
	var gear := {"armor": 85, "neck": 70001, "ring_1": 70002,
		"ring_2": 70003, "weapons": WEAPONS[weapon]}
	for slot: String in gear:
		hero.equipment[slot] = ItemData.instance(int(gear[slot]))
	hero.refresh_stats()
	hero.health = hero.max_health
	hero.rage = 90 if prepared else 0
	hero.inventory[0] = ItemData.instance(118, 1) if potion else {}
	if prepared:
		_prepare(world)
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
			enemy.max_health = int(data.health)
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
	while not world.is_terminal() and world.turn_count < 300:
		var living := enemies.filter(func(enemy: GridActor) -> bool: return enemy.alive)
		if living.is_empty():
			break
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
		var choices: Array[StringName] = []
		for id in [&"battle_shout_1", &"blessing_of_might_1", &"seal_of_command_1",
			&"lightning_shield_1", &"windfury_weapon_1"]:
			if not hero.buffs.has(id):
				choices.append(id)
		if hero.health * 2 < hero.max_health:
			choices.append_array([&"divine_shield_1", &"evasion_1"])
		choices.append_array([&"earth_elemental_1", &"feral_spirit_1", &"execute_1"])
		if not hero.buffs.has(&"instant_poison_1"):
			choices.append(&"instant_poison_1")
		if hero.combo_points >= 3 and not hero.buffs.has(&"slice_and_dice_1"):
			choices.append(&"slice_and_dice_1")
		if policy == "physical":
			choices.append_array([&"mortal_strike_1", &"earth_shock_1", &"judgement_1",
				&"execution_sentence_1", &"consecration_1"])
		else:
			choices.append_array([&"judgement_1", &"execution_sentence_1"])
			if policy != "no_ground":
				choices.append(&"consecration_1")
			choices.append_array([&"earth_shock_1", &"mortal_strike_1"])
		if living.size() > 1:
			choices.append(&"whirlwind_1")
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
					if route.size() > 1:
						assert(world.move_player(route[1] - world.player_tile))
					else:
						world.wait_turn()
			else:
				var route := world.charge_route(target)
				if GridWorld.tile_distance(world.player_tile, target.tile) > 1 and route.size() > 1:
					assert(world.move_player(route[1] - world.player_tile))
				else:
					world.wait_turn()
	var enemy_hp := 0
	for enemy in enemies:
		enemy_hp += enemy.health
	assert(world.turn_count < 300 or enemy_hp == 0 or hero.health == 0)
	var result := {"seed": seed_value, "win": enemy_hp == 0, "hp": hero.health,
		"enemy_hp": enemy_hp, "turns": world.turn_count, "rage": hero.rage,
		"combat_random": str(world.combat_random.state), "class_xp": hero.progression_points(&"Paladin")}
	if traced:
		var trace := world as PaladinWorld
		assert(trace.valid_accounting and trace.damage_total == initial_hp - enemy_hp)
		result.merge({"damage": trace.damage.duplicate(true), "damage_total": trace.damage_total,
			"casts": trace.casts.duplicate(), "activations": trace.activations.duplicate()})
	world.discard()
	return result


func _prepare(world: GridWorld) -> void:
	for id in [&"battle_shout_1", &"blessing_of_might_1", &"seal_of_command_1",
		&"lightning_shield_1", &"windfury_weapon_1", &"instant_poison_1"]:
		var skill := world.hero.find_skill(id)
		if skill != null:
			SpellEffects.resolve(world, skill, null)
	if world.hero.find_skill(&"catalytic_venom_1") != null and world.hero.has_off_hand_weapon():
		var weapon := ItemData.get_item(world.hero.weapon_id())
		var faster := PoisonRules.Hands.MAIN if weapon.interval < weapon.off_interval else PoisonRules.Hands.OFF
		PoisonRules.coat(world, world.hero.find_skill(&"instant_poison_1"), faster)
		PoisonRules.coat(world, world.hero.find_skill(&"deadly_poison_1"),
			PoisonRules.Hands.OFF if faster == PoisonRules.Hands.MAIN else PoisonRules.Hands.MAIN)
