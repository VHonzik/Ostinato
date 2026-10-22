extends "res://bench/priority_sim.gd"
## Full retained kit on the current requested rotation; no gameplay overrides.

const STALKER: Dictionary = {
	"id": "Stalker", "hero_level": 5, "profile": "stalker", "count": 1}
const SKIPS: Dictionary = {
	"anger_management_1": "Between-fight rage retention needs a route trial.",
	"victory_rush_1": "Terminal Stalker victory stops kill healing.",
	"sweeping_strikes_1": "No second enemy.",
	"pursuit_of_justice_1": "Route value; this fight opens with Charge.",
	"relentless_assault_1": "Core combo dependency; not a meaningful isolated removal."}
const OFF_HAND_ONLY: Array[String] = ["ambidexterity_1", "combat_potency_1",
	"main_gauche_1", "catalytic_venom_1"]

var disabled: Array[StringName] = []
var gifts: bool = true
var baseline_samples: int = 200
var removal_samples: int = 100
var passives: Array[Dictionary] = []
var baseline_only: bool = false


func _initialize() -> void:
	build = "All"
	selected_class = &"Warrior"
	case_id = "Stalker"
	for arg in OS.get_cmdline_user_args():
		if arg == "smoke":
			smoke = true
			baseline_samples = 2
			removal_samples = 2
		elif arg.begins_with("shard="):
			shard = int(arg.trim_prefix("shard="))
		elif arg == "baseline_only":
			baseline_only = true
	for category in ClassSkillData.PLAYABLE_CLASSES:
		kit_skills[category] = SkillDefinition.trainer_skills(category)
		for skill: SkillDefinition in kit_skills[category]:
			if skill.effect == SkillDefinition.Effect.PASSIVE:
				passives.append({"id": String(skill.id), "name": skill.title,
					"class": String(category), "skip": SKIPS.get(String(skill.id), "")})
	started = Time.get_ticks_msec()
	if smoke:
		_check_charm_accounting()
	call_deferred("_run")


func _run() -> void:
	for weapon in range(3):
		if shard >= 0 and weapon != shard:
			continue
		for with_gifts in [false, true]:
			gifts = with_gifts
			for prepared in [false, true]:
				_measure_full(weapon, prepared, baseline_samples, "baseline", "")
		if baseline_only:
			continue
		gifts = true
		for passive in passives:
			if not String(passive.skip).is_empty():
				continue
			if weapon != 2 and passive.id in OFF_HAND_ONLY:
				continue
			disabled.assign([StringName(passive.id)])
			for prepared in [false, true]:
				_measure_full(weapon, prepared, removal_samples, "ablation", passive.name)
			disabled.clear()
	var setup := {"baseline_samples": baseline_samples, "ablation_samples": removal_samples,
		"baseline_only": baseline_only,
		"passives": passives, "weapons": WEAPONS, "stalker": NorthshireData.STALKER,
		"gear": {"armor": 85, "neck": 70001, "ring_1": 70002, "ring_2": 70003},
		"entry": "Level 5, common gear, all four kits learned. Cold: full HP, zero rage, no buffs. Prepared: live casts from zero rage (poisons, Windfury, Shield, Shout last), no health/rage refill or banked points/stacks. Six-tile Charge. Preparation turns excluded from fight duration and recorded separately.",
		"policy": "Current priority bench intent policy, fixed for full/removal: live sidestep out of marked Fel Breath before other actions; emergency defenses and potion; Juggernaut MS, full Lava, empowered durable-target Judgement, 5CP Eviscerate, Execute, empty Shield, MS, other actions. No pilot selection or adaptation after removal.",
		"gifts": "Already-earned War Horn, Lucky charm, Ancestral totem and Wartorn Banner. In melee, use totem then banner, each via live one-turn item action. Charm works from bags. Horn is not useful for a single already-engaged target and is not cast. Gifts stay available in every removal, independently of training eligibility. Baseline also runs without gifts.",
		"dependencies": "Removing Seal of Command also makes Judgement unavailable. Removing Maelstrom suppresses full-stack Lava casts in this policy. Removing Art of War removes the stronger empowered-critical opportunity. These are family effects, not isolated flat damage contributions.",
		"seeds": "1830000 + fight index, same across every weapon, entry and removal; first removal_samples baseline seeds are paired. Streams can diverge after a removed proc.",
		"accounting": "Effective boss HP, healing and player HP loss reconciled every fight. First three seeds per cell replay on plain GridWorld, matching outcome/HP/turns/rage/RNG. Observer handles the exact charm-break event separately from its following attack log.",
		"limits": "Stalker only, fully learned retained kits; no partial/native learning, route or reinforcements. No tuning changes. Fixed bot is not optimal or human acceptance."}
	if not BenchIO.write_result({"setup": setup, "rows": rows, "replayed": replayed,
		"seconds": (Time.get_ticks_msec() - started) / 1000.0}):
		quit(1)
		return
	print("COMPLETE full-unlock Stalker: %d cells, %d replays, %.1fs" % [
		rows.size(), replayed, (Time.get_ticks_msec() - started) / 1000.0])
	quit()


func _measure_full(weapon: int, prepared: bool, count: int, phase: String,
	removed: String) -> void:
	var fights: Array[Dictionary] = []
	for index in range(count):
		var fight := _battle(STALKER, weapon, prepared, true, "intent", 1830000 + index, true)
		if index < mini(count, 3):
			var plain := _battle(STALKER, weapon, prepared, true, "intent", 1830000 + index, false)
			for key in ["win", "hp", "enemy_hp", "turns", "rage", "combat_random"]:
				assert(fight[key] == plain[key], "Full-unlock replay mismatch: " + key)
			replayed += 1
		fights.append(fight)
	rows.append({"build": "All" if gifts else "All (no gifts)", "weapon": STYLES[weapon],
		"prepared": prepared, "policy": "intent", "gifts": gifts, "phase": phase,
		"disabled": disabled.duplicate(), "removed": removed, "runs": count, "fights": fights})
	print("CELL %s %s prepared=%s gifts=%s removed=%s n=%d" % [
		phase, STYLES[weapon], prepared, gifts, removed, count])


func _create_world(seed_value: int, traced: bool) -> GridWorld:
	var world := super._create_world(seed_value, traced)
	if gifts:
		var items := [ItemData.WAR_HORN_ID, ItemData.LUCKY_CHARM_ID,
			ItemData.ANCESTRAL_TOTEM_ID, ItemData.WAR_BANNER_ID]
		for index in range(items.size()):
			world.hero.inventory[index + 1] = ItemData.instance(items[index])
	return world


func _learn_skills(hero: HeroState) -> void:
	super._learn_skills(hero)
	for index in range(hero.learned_skills.size() - 1, -1, -1):
		if hero.learned_skills[index].id in disabled:
			hero.learned_skills.remove_at(index)


func _try_item_action(world: GridWorld, target: GridActor) -> bool:
	if not gifts or GridWorld.tile_distance(world.player_tile, target.tile) > 1:
		return false
	if world.has_ancestral_totem():
		return world.use_ancestral_totem()
	if world.has_war_banner():
		return world.use_war_banner()
	return false


func _check_charm_accounting() -> void:
	var world := _create_world(1829999, true)
	world.hero.health = 10
	var targets: Array[GridActor] = []
	var observer := world as PriorityWorld
	observer.watch(targets)
	var target := NpcTarget.new(world, null)
	# Exercise the production damage/charm path and its following combat log.
	target.take_damage(20, &"hit")
	world.add_message("Observer check -> You: hit, 20 damage.")
	var saved := observer.metrics()
	assert(world.hero.health == 1 and saved.damage_taken == 9
		and saved.raw_damage_taken == 20 and saved.charm_breaks == 1)
	target.take_damage(5, &"hit")
	world.add_message("Observer check -> You: hit, 5 damage.")
	var dead := observer.metrics()
	assert(world.hero.health == 0 and dead.damage_taken == 10
		and dead.raw_damage_taken == 25 and dead.charm_breaks == 1)
	world.discard()
	print("PASS observer: one lethal charm save, then terminal HP loss; no double counting.")
