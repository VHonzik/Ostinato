class_name SkillRank
extends RefCounted

## Learned class ranks. Current character level never gates retained-rank use.
enum Effect { PRACTICE, EXPERIENCE, DEATH_NOTICE, ARMOR, GOLD, SUMMON, JUDGEMENT, PASSIVE, KILL_STALKER, MORTAL_STRIKE, BATTLE_SHOUT, CLASS_POINTS, CHARGE, HEROIC_STRIKE, EXECUTE, TOOLKIT }
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
var execute_health_percent: int = 0
var execute_rage_cap: int = 0
var execute_damage_per_rage: int = 0
var physical_percent: int = 0
var haste_percent: int = 0
var duration_per_combo: int = 0
var rage_generated: int = 0
var travel_speed: int = 0
var cast_seconds: float = 1.0
var range_tiles: int = 0
var minimum_range_tiles: int = 0
var minimum: int = 0
var maximum: int = 0
var duration: int = 0
var family: StringName = &""
var school: int = 0
var cooldown_seconds: int = 0
var coefficient: float = 0.0
var detail: String = ""



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


static func starting_skills(category: StringName = &"Warrior") -> Array[SkillRank]:
	var result: Array[SkillRank] = []
	for identifier: StringName in ClassSkillData.STARTERS.get(category, []):
		result.append(catalog(identifier))
	return result


static func trainer_skills(category: StringName) -> Array[SkillRank]:
	var result: Array[SkillRank] = []
	for identifier in all_ranks():
		if (all_ranks()[identifier].class_tab == String(category)
			and (category not in ClassSkillData.PLAYABLE_CLASSES
				or ClassSkillData.is_playable_rank(StringName(identifier)))):
			result.append(catalog(StringName(identifier)))
	return result


static func all_ranks() -> Dictionary:
	var ranks := ClassSkillData.RANKS.duplicate()
	ranks.merge(ClassSkillData.LOOP_RANKS, true)
	ranks.merge(ClassToolkitData.ranks(), true)
	return ranks


func cost(hero: HeroState) -> int:
	return ClassToolkitRules.cost(hero, self)


func execute_eligible(target_actor: GridActor) -> bool:
	return (target_actor != null and target_actor.alive and target_actor.health > 0
		and target_actor.max_health > 0
		and target_actor.health * 100 <= target_actor.max_health * execute_health_percent)


func resource_name() -> String:
	return "rage"


func available_resource(hero: HeroState) -> int:
	return hero.rage


func spend_resource(hero: HeroState) -> void:
	hero.rage -= cost(hero)


static func catalog(identifier: StringName) -> SkillRank:
	var ranks := all_ranks()
	if not ranks.has(String(identifier)):
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
		elif field in ["family", "class_tab"]:
			skill.set(field, StringName(row[field]))
		else:
			skill.set(field, row[field])
	if skill.effect == Effect.PASSIVE:
		skill.description = skill.title + ": " + skill.detail
		return skill
	skill.description = "%s rank %d: %d rage, %.1f turns, range %d tiles. " % [
		skill.title, skill.rank, skill.rage_cost, skill.cast_seconds, skill.range_tiles]
	if skill.effect == Effect.HEROIC_STRIKE:
		skill.description = "%s rank %d: %d rage, next main-hand swing, range %d tiles. " % [
			skill.title, skill.rank, skill.rage_cost, skill.range_tiles]
	if skill.minimum_range_tiles > 0:
		skill.description += "Minimum range: %d tiles. " % skill.minimum_range_tiles
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
		SkillRank.new(&"class_points_1", "Gain 30 class XP", &"Development", 1, 1,
			"One turn; 0 rage. Awards 30 cumulative class XP to the selected class.",
			Effect.CLASS_POINTS, true),
	]
