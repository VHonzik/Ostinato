class_name SkillRank
extends RefCounted

## Warrior abilities and retained legacy ranks. Training levels never gate retained-rank use.
enum Effect { PRACTICE, EXPERIENCE, DEATH_NOTICE, DAMAGE, HEAL, ARMOR, HEAL_OVER_TIME, ROOT, POLYMORPH, NOVA, CHANNEL, CONJURE, GOLD, SUMMON, CURSE, FEAR, STUN, LIFE_TAP, JUDGEMENT, PURIFY, RESURRECT, PASSIVE, PET_COMMAND, KILL_STALKER, SLAM, BATTLE_SHOUT, CLASS_POINTS, CHARGE }
enum Target { NONE, ENEMY, ALLY, SELF }

var id: StringName
var title: String
var class_tab: StringName
var rank: int
var training_level: int
var description: String
var effect: Effect
var development_only: bool
var target: Target = Target.NONE
var rage_cost: int = 0
var progress_required: int = 0
var weapon_multiplier: float = 1.0
var physical_percent: int = 0
var rage_generated: int = 0
var travel_speed: int = 0
var mana_cost: int = 0
var cast_seconds: float = 1.0
var range_tiles: int = 0
var minimum_range_tiles: int = 0
var minimum: int = 0
var maximum: int = 0
var duration: int = 0
var periodic_damage: int = 0
var source_id: int = 0
var training_cost: int = 0
var prerequisite: StringName = &""
var family: StringName = &""
var school: int = 0
var cooldown_seconds: int = 0
var scaling_max: int = 0
var scaling_rate: float = 0.0
var coefficient: float = 0.0
var tick_seconds: int = 0
var tick_coefficient: float = 0.0
var item_id: int = 0
var mana_percent: int = 0
var detail: String = ""
var free_instant: bool = false



func _init(
	identifier: StringName, display_name: String, category: StringName,
	rank_number: int, learn_level: int, detail: String, action: Effect,
	is_development: bool = false
) -> void:
	id = identifier
	title = display_name
	class_tab = category
	rank = rank_number
	training_level = learn_level
	description = detail
	effect = action
	development_only = is_development


static func starting_skills() -> Array[SkillRank]:
	return [catalog(&"slam_1"), catalog(&"battle_shout_1")]


static func trainer_skills(category: StringName) -> Array[SkillRank]:
	var result: Array[SkillRank] = []
	for identifier in all_ranks():
		if all_ranks()[identifier].class_tab == String(category):
			result.append(catalog(StringName(identifier)))
	return result


static func all_ranks() -> Dictionary:
	var ranks := TrainerData.RANKS.duplicate()
	ranks.merge(ClassSkillData.RANKS)
	return ranks


func cost(hero: HeroState) -> int:
	if class_tab == &"Warrior":
		return rage_cost
	return mana_cost + int(HeroData.stats_for_level(hero.level)[6] * mana_percent / 100.0)


func resource_name() -> String:
	return "rage" if class_tab == &"Warrior" or development_only else "mana"


func available_resource(hero: HeroState) -> int:
	return hero.rage if resource_name() == "rage" else hero.mana


func spend_resource(hero: HeroState) -> void:
	if resource_name() == "rage":
		hero.rage -= cost(hero)
	else:
		hero.mana -= cost(hero)


static func catalog(identifier: StringName) -> SkillRank:
	var ranks := all_ranks()
	if not ranks.has(String(identifier)):
		var command := ClassSkillData.pet_command(identifier)
		if command != null:
			return command
		for skill in development_skills():
			if skill.id == identifier:
				return skill
		return null
	var row: Dictionary = ranks[String(identifier)]
	var skill := SkillRank.new(identifier, row.title, StringName(row.class_tab),
		row.rank, row.training_level, "", Effect[row.effect])
	for field in row:
		if field == "effect":
			continue
		if field == "target":
			skill.target = Target[row.target]
		elif field in ["family", "class_tab", "prerequisite"]:
			skill.set(field, StringName(row[field]))
		else:
			skill.set(field, row[field])
	skill.description = "%s rank %d: %d %s, %.1f turns, range %d tiles. " % [
		skill.title, skill.rank, skill.rage_cost if skill.class_tab == &"Warrior" else skill.mana_cost,
		skill.resource_name(), skill.cast_seconds, skill.range_tiles]
	if skill.minimum_range_tiles > 0:
		skill.description += "Minimum range: %d tiles. " % skill.minimum_range_tiles
	if ClassSkillData.RANKS.has(String(identifier)) and skill.detail != "":
		if skill.mana_percent > 0:
			skill.description += "%d%% base mana. " % skill.mana_percent
		skill.description += skill.detail
		return skill
	match skill.effect:
		Effect.DAMAGE, Effect.CHANNEL, Effect.NOVA:
			skill.description += "%d–%d damage%s. " % [skill.minimum, skill.maximum,
				" each second for 3 turns" if skill.effect == Effect.CHANNEL else ""]
		Effect.HEAL:
			skill.description += "Restore %d–%d health. " % [skill.minimum, skill.maximum]
		Effect.ARMOR:
			var stat := "intellect" if skill.family == &"intellect" else "armor"
			if skill.family == &"thorns":
				stat = "nature damage to melee attackers"
			skill.description += "+%d %s for %d turns. " % [skill.minimum, stat, skill.duration]
			if skill.id == &"mark_2":
				skill.description += "+2 to all attributes. "
		Effect.POLYMORPH:
			skill.description += "Sheep one beast/humanoid/critter for 20 turns; heals rapidly; damage breaks. "
		Effect.ROOT:
			skill.description += "Root one enemy outdoors for 12 turns; damage can break. "
		Effect.CONJURE:
			skill.description += "Conjure food/water into inventory. "
	if skill.periodic_damage > 0:
		skill.description += "%d every %d turns for %d turns. " % [
			skill.periodic_damage, skill.tick_seconds, skill.duration]
	if skill.cooldown_seconds > 0:
		skill.description += "%d-turn cooldown. " % skill.cooldown_seconds
	if skill.family == &"frostbolt":
		skill.description += "Slows movement 40%. "
	if skill.family == &"frost_armor":
		skill.description += "Chills melee attackers for 5 turns. "
	if skill.mana_percent > 0:
		skill.description += "%d%% of base mana. " % skill.mana_percent
	skill.description += skill.detail
	return skill


static func development_skills() -> Array[SkillRank]:
	return [
		SkillRank.new(&"practice_1", "Practice", &"Development", 1, 1,
			"One turn; 0 rage. Reports a harmless practice cast.", Effect.PRACTICE, true),
		SkillRank.new(&"experience_1", "Gain 450 XP", &"Development", 1, 1,
			"One turn; 0 rage. Awards 450 XP through ordinary leveling.", Effect.EXPERIENCE, true),
		SkillRank.new(&"gold_1", "Gain 1 gold", &"Development", 1, 1,
			"One turn; 0 rage. Adds 1 gold (10,000 copper).", Effect.GOLD, true),
		SkillRank.new(&"death_1", "Death trigger", &"Development", 1, 1,
			"One turn; 0 rage. Die and begin the next Loop.", Effect.DEATH_NOTICE, true),
		SkillRank.new(&"kill_stalker_1", "Kill stalker", &"Development", 1, 1,
			"One turn; 0 rage. Kill the first living stalker anywhere and end the demo. "
			+ "No living stalker: no turn spent.", Effect.KILL_STALKER, true),
		SkillRank.new(&"class_points_1", "Gain 30 class points", &"Development", 1, 1,
			"One turn; 0 rage. Awards 30 progression points to the current class.",
			Effect.CLASS_POINTS, true),
	]
