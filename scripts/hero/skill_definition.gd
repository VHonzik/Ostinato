class_name SkillDefinition
extends RefCounted

## Learned class skills. Current character level never gates retained-skill use.
enum Effect { PRACTICE, EXPERIENCE, DEATH_NOTICE, ARMOR, GOLD, SUMMON, EXECUTION_SENTENCE, PASSIVE, KILL_STALKER, MORTAL_STRIKE, BATTLE_SHOUT, CLASS_POINTS, CHARGE, EXECUTE, TOOLKIT }
enum Target { NONE, ENEMY, ALLY, SELF }

var id: StringName
var title: String
var class_tab: StringName
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
var critical_percent: int = 0
var damage_taken_percent: int = 0
var health_cap_percent: int = 0
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
var periodic_damage: float = 0.0
var periodic_duration: int = 0
var family: StringName = &""
var school: int = 0
var cooldown_seconds: int = 0
var delay_turns: int = 0
var coefficient: float = 0.0
var detail: String = ""



func _init(
	identifier: StringName, display_name: String, category: StringName,
	learn_level: int, detail: String, action: Effect,
	is_development: bool = false
) -> void:
	id = identifier
	title = display_name
	class_tab = category
	training_level = learn_level
	description = detail
	effect = action
	development_only = is_development


static func starting_skills(category: StringName = &"Warrior") -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for identifier: StringName in ClassSkillData.STARTERS.get(category, []):
		result.append(catalog(identifier))
	return result


static func trainer_skills(category: StringName) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for identifier in all_skills():
		if (all_skills()[identifier].class_tab == String(category)
			and (category not in ClassSkillData.PLAYABLE_CLASSES
				or ClassSkillData.is_playable_skill(StringName(identifier)))):
			result.append(catalog(StringName(identifier)))
	result.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		if a.progress_required == b.progress_required:
			return a.title < b.title
		return a.progress_required < b.progress_required)
	return result


static func all_skills() -> Dictionary:
	var skills := ClassSkillData.SKILLS.duplicate()
	skills.merge(ClassSkillData.STARTER_SKILLS, true)
	skills.merge(ClassToolkitData.skills(), true)
	return skills


func cost(hero: HeroState) -> int:
	return SkillCost.quote(hero, self).rage_cost


func execute_eligible(target_actor: GridActor) -> bool:
	return (target_actor != null and target_actor.alive and target_actor.health > 0
		and target_actor.max_health > 0
		and target_actor.health * 100 <= target_actor.max_health * execute_health_percent)


func resource_name() -> String:
	return "rage"


func available_resource(hero: HeroState) -> int:
	return hero.rage


static func catalog(identifier: StringName) -> SkillDefinition:
	var skills := all_skills()
	if not skills.has(String(identifier)):
		for skill in development_skills():
			if skill.id == identifier:
				return skill
		return null
	var row: Dictionary = skills[String(identifier)]
	var skill := SkillDefinition.new(identifier, row.title, StringName(row.class_tab),
		row.training_level, "", Effect[row.effect])
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
	skill.description = "%s: %d rage, %.1f turns, range %d tiles. " % [
		skill.title, skill.rage_cost, skill.cast_seconds, skill.range_tiles]
	if skill.minimum_range_tiles > 0:
		skill.description += "Minimum range: %d tiles. " % skill.minimum_range_tiles
	skill.description += skill.detail
	return skill


static func development_skills() -> Array[SkillDefinition]:
	return [
		SkillDefinition.new(&"practice_1", "Practice", &"Development", 1,
			"One turn; 0 rage. Reports a harmless practice cast.", Effect.PRACTICE, true),
		SkillDefinition.new(&"experience_1", "Gain 450 XP", &"Development", 1,
			"One turn; 0 rage. Awards 450 XP through ordinary leveling.", Effect.EXPERIENCE, true),
		SkillDefinition.new(&"gold_1", "Gain 1 gold", &"Development", 1,
			"One turn; 0 rage. Adds 1 gold (10,000 copper).", Effect.GOLD, true),
		SkillDefinition.new(&"death_1", "Death trigger", &"Development", 1,
			"One turn; 0 rage. Die and begin the next Loop.", Effect.DEATH_NOTICE, true),
		SkillDefinition.new(&"kill_stalker_1", "Kill stalker", &"Development", 1,
			"One turn; 0 rage. Kill the first living stalker anywhere. Defeat all present stalkers to win. "
			+ "No living stalker: no turn spent.", Effect.KILL_STALKER, true),
		SkillDefinition.new(&"class_points_1", "Gain 30 class XP", &"Development", 1,
			"One turn; 0 rage. Awards 30 cumulative class XP to the selected class.",
			Effect.CLASS_POINTS, true),
	]
