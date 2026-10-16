extends SceneTree

const TracedWorld = preload("res://bench/warrior_identity_world.gd")
const BenchIO = preload("res://bench/bench_io.gd")
const WEAPONS: Array[int] = [5579, 5580, 2224]
const STYLES: Array[String] = ["2H", "Shield", "DW"]
const CASES: Array[Dictionary] = [
	{"id": "2xL3", "hero_level": 3, "profile": "80", "count": 2},
	{"id": "3xL3", "hero_level": 3, "profile": "80", "count": 3},
	{"id": "4xL3", "hero_level": 3, "profile": "80", "count": 4},
	{"id": "2xL4", "hero_level": 3, "profile": "38", "count": 2},
	{"id": "3xL4", "hero_level": 3, "profile": "38", "count": 3},
	{"id": "2xL5", "hero_level": 3, "profile": "103", "count": 2},
	{"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1},
]
var samples: int = 400
var pilot_samples: int = 100
var shard: int = -1
var smoke: bool = false
var skills: Array[SkillDefinition] = []
var rows: Array[Dictionary] = []
var pilots: Array[Dictionary] = []
var replayed: int = 0
var started: int = 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			samples = 2
			pilot_samples = 2
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
	skills = SkillDefinition.trainer_skills(&"Warrior")
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	for weapon in range(3):
		if shard >= 0 and weapon != shard:
			continue
		for prepared in [false, true]:
			var group_policy := _choose_policy(CASES[4], weapon, prepared)
			var single_policy := _choose_policy(CASES[6], weapon, prepared)
			for case_index in range(CASES.size()):
				var policy := single_policy if case_index == 6 else group_policy
				_measure(CASES[case_index], case_index, weapon, prepared, false, policy)
			_measure(CASES[6], 6, weapon, prepared, true, single_policy)
	var setup := {"commit": OS.get_environment("OSTINATO_BENCH_REVISION"), "samples_per_cell": samples,
		"pilot_samples_per_policy": pilot_samples, "warrior_skills": skills.map(func(skill: SkillDefinition) -> String: return skill.title),
		"gear": {"armor": 85, "neck": 70001, "ring_1": 70002, "ring_2": 70003,
			"weapons": WEAPONS}, "cases": CASES,
		"cold": "Full HP, 0 rage, no prebuffs or ready procs.",
		"prepared": "Full HP, 90 rage, fresh Battle Shout; no assigned Enrage, Wrecking Crew, Battle Trance or Sudden Death.",
		"opener": "Groups initially adjacent and hostile: attack the first target. Stalker: normal Charge from six tiles.",
		"policy_selection": "%d independent pilot seeds per candidate on 3xL4 and Stalker, separately per weapon and entry. Rank by wins, then least remaining enemy HP, then highest hero HP. Apply the chosen group policy to all group cases." % pilot_samples,
		"policies": {"spend": "Execute; maintain Battle Shout; Juggernaut Mortal Strike; Whirlwind versus 2+ targets; Mortal Strike; Whirlwind whenever affordable.",
			"reserve": "Same priority, but reserve 30 rage after single-target Whirlwind. Whirlwind still spends freely versus groups."},
		"targeting": "Focus first surviving enemy. After a kill prefer a targeted active if available; otherwise deliberately bump the new target, paying normal swing commitment.",
		"potions": "Groups: none. Stalker: paired runs with none or one Minor Healing Potion at 40+ missing HP.",
		"excluded": "No kill XP or level-up heals, kiting, route, reinforcements, food, retained non-Warrior skills or uncommon gear. Normal Victory Rush and end-of-turn regeneration remain.",
		"damage_accounting": "Pooled actual enemy HP removed over all fights, including losses. Overkill excluded. Sweeping Strikes separated from its parent attack. All passives embedded in affected damage; no counterfactual passive attribution.",
		"seeds": "Measured: 1600000 + case_index*10000 + fight_index, shared across weapons/entry/potion. Pilot: 1500000 + (10000 for Stalker) + fight_index.",
		"instrumentation": "First 10 measured seeds per cell replay on plain GridWorld: same outcome, hero HP, enemy HP, turn count and combat RNG state; every traced fight reconciles damage to enemy HP lost."}
	if not BenchIO.write_result({"setup": setup, "pilots": pilots, "rows": rows,
		"replayed": replayed, "seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE %d cells, %d measured fights, %d plain-world replays, %.1fs" % [
		rows.size(), rows.size() * samples, replayed, (Time.get_ticks_msec() - started) / 1000.0])
	quit()


func _choose_policy(encounter: Dictionary, weapon: int, prepared: bool) -> String:
	var chosen := "spend"
	var best := [-1, -100000000, -1]
	for policy in ["spend", "reserve"]:
		var wins := 0
		var remaining := 0
		var health := 0
		for index in range(pilot_samples):
			var fight := _battle(encounter, weapon, prepared, false, policy,
				1500000 + (10000 if encounter.id == "Stalker" else 0) + index, true)
			wins += int(fight.win)
			remaining += int(fight.enemy_hp)
			health += int(fight.hp)
		var score := [wins, -remaining, health]
		pilots.append({"case": encounter.id, "weapon": STYLES[weapon], "prepared": prepared,
			"policy": policy, "wins": wins, "enemy_hp_total": remaining, "hero_hp_total": health})
		if score[0] > best[0] or (score[0] == best[0] and (score[1] > best[1]
			or (score[1] == best[1] and score[2] > best[2]))):
			best = score
			chosen = policy
	return chosen


func _measure(encounter: Dictionary, case_index: int, weapon: int, prepared: bool,
	potion: bool, policy: String) -> void:
	var fights: Array[Dictionary] = []
	var damage: Dictionary = {}
	var casts: Dictionary = {}
	var activations: Dictionary = {}
	var wins := 0
	var damage_total := 0
	var enemy_total := 0
	var hp: Array[int] = []
	var turns: Array[int] = []
	for index in range(samples):
		var seed_value := 1600000 + case_index * 10000 + index
		var fight := _battle(encounter, weapon, prepared, potion, policy, seed_value, true)
		if index < mini(samples, 10):
			var plain := _battle(encounter, weapon, prepared, potion, policy, seed_value, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				if fight[key] != plain[key]:
					push_error("Replay mismatch %s %s seed %d field %s" % [encounter.id, STYLES[weapon], seed_value, key])
					quit(1)
					return
			replayed += 1
		wins += int(fight.win)
		damage_total += int(fight.damage_total)
		enemy_total += int(fight.enemy_hp)
		hp.append(int(fight.hp))
		turns.append(int(fight.turns))
		_accumulate(damage, fight.damage)
		_add_numbers(casts, fight.casts)
		_add_numbers(activations, fight.activations)
		fights.append(fight)
	var row := {"case": encounter.id, "hero_level": encounter.hero_level,
		"weapon": STYLES[weapon], "prepared": prepared, "potion": potion,
		"policy": policy, "runs": samples, "wins": wins, "win_percent": 100.0 * wins / samples,
		"median_hp": _median(hp), "median_turns": _median(turns),
		"mean_effective_damage": float(damage_total) / samples,
		"mean_enemy_hp": float(enemy_total) / samples,
		"damage_total": damage_total, "damage": damage, "casts": casts, "activations": activations,
		"fights": fights}
	rows.append(row)
	print("CELL %s %s %s potion=%s: %.1f%% wins; HP %.1f; turns %.1f; dealt %.1f; %s" % [
		encounter.id, STYLES[weapon], "prepared" if prepared else "cold", potion,
		row.win_percent, row.median_hp, row.median_turns, row.mean_effective_damage, policy])


func _battle(encounter: Dictionary, weapon: int, prepared: bool, potion: bool,
	policy: String, seed_value: int, traced: bool) -> Dictionary:
	var world: GridWorld
	if traced:
		world = TracedWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
	else:
		world = GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 12), seed_value, false)
	var hero := world.hero
	hero.level = int(encounter.hero_level)
	for skill in skills:
		if hero.find_skill(skill.id) == null:
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
		var shout := hero.find_skill(&"battle_shout_1")
		# Construct the declared prepared entry without granting extra combat procs.
		hero.buffs[shout.id] = {"armor": 0, "physical_percent": shout.physical_percent,
			"until": 1 + shout.duration}
		hero.refresh_stats()
	var enemies: Array[GridActor] = []
	if encounter.profile == "stalker":
		world._spawn_stalker(world.player_tile + Vector2i(0, -6))
		enemies.append(world.actors[0])
	else:
		var data: Dictionary = NorthshireData.CREATURES[encounter.profile]
		for index in range(int(encounter.count)):
			var enemy := GridActor.new(world.player_tile + [Vector2i.UP, Vector2i.RIGHT,
				Vector2i.LEFT, Vector2i.DOWN][index])
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
	var initial_enemy_hp := 0
	for index in range(enemies.size()):
		enemies[index].title = "Target %d" % index
		enemies[index].awards_experience = false
		initial_enemy_hp += enemies[index].health
	if traced:
		(world as TracedWorld).watch(enemies)
	if encounter.profile == "stalker":
		assert(world.cast_skill(&"charge_1", enemies[0]))
	else:
		assert(world.request_melee(enemies[0]))
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
		var acted := false
		var choices: Array[StringName] = [&"execute_1"]
		if not hero.buffs.has(&"battle_shout_1"):
			choices.append(&"battle_shout_1")
		if hero.buffs.has(&"juggernaut_1"):
			choices.append(&"mortal_strike_1")
		if living.size() > 1:
			choices.append(&"whirlwind_1")
		choices.append(&"mortal_strike_1")
		var whirlwind := hero.find_skill(&"whirlwind_1")
		if (policy == "spend" or living.size() > 1 or whirlwind.cost(hero) == 0
			or hero.rage - whirlwind.cost(hero) >= 30):
			choices.append(&"whirlwind_1")
		# A new auto target must be selected by an actual action. Prefer a valid direct
		# attack; otherwise the bump is a deliberate commitment with its normal cost.
		if world.auto_attack_target != target:
			choices = [&"execute_1", &"mortal_strike_1"]
		for identifier in choices:
			var skill := hero.find_skill(identifier)
			if (skill.cost(hero) > hero.rage
				or int(hero.cooldowns.get(String(world.cooldown_family(skill)), 0)) > world.turn_count):
				continue
			var candidate: GridActor = target if skill.target == SkillDefinition.Target.ENEMY else null
			if not world.valid_spell_target(skill, candidate) or not SpellEffects.can_apply(world, skill, candidate):
				continue
			if world.cast_skill(identifier, candidate):
				acted = true
				break
		if not acted:
			if world.auto_attack_target != target:
				assert(world.request_melee(target))
			else:
				world.wait_turn()
	var enemy_hp := 0
	for enemy in enemies:
		enemy_hp += enemy.health
	assert(world.turn_count < 300 or enemy_hp == 0 or hero.health == 0)
	var result := {"seed": seed_value, "win": enemy_hp == 0, "hp": hero.health,
		"enemy_hp": enemy_hp, "turns": world.turn_count, "rage": hero.rage,
		"combat_random": str(world.combat_random.state)}
	if traced:
		var trace := world as TracedWorld
		assert(trace.valid_accounting)
		assert(trace.damage_total == initial_enemy_hp - enemy_hp)
		result.merge({"damage": trace.damage.duplicate(true), "damage_total": trace.damage_total,
			"casts": trace.casts.duplicate(), "activations": trace.activations.duplicate()})
	world.discard()
	return result


func _accumulate(total: Dictionary, additions: Dictionary) -> void:
	for label: String in additions:
		if not total.has(label):
			total[label] = {"effective": 0, "raw": 0, "overkill": 0, "events": 0}
		_add_numbers(total[label], additions[label])


func _add_numbers(total: Dictionary, additions: Dictionary) -> void:
	for label in additions:
		total[label] = int(total.get(label, 0)) + int(additions[label])


func _median(values: Array[int]) -> float:
	values.sort()
	var middle := values.size() / 2
	return float(values[middle]) if values.size() % 2 else (values[middle - 1] + values[middle]) / 2.0
