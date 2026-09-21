class_name SkillRank
extends RefCounted

## DATA-003 starting-rank subset. Training levels never gate retained-rank use.
enum Effect { PRACTICE, EXPERIENCE, DEATH_NOTICE, DAMAGE, HEAL, ARMOR }
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
var mana_cost: int = 0
var cast_seconds: float = 1.0
var range_tiles: int = 0
var minimum: int = 0
var maximum: int = 0
var duration: int = 0
var periodic_damage: int = 0
var source_id: int = 0


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
	return [catalog(&"fireball_1"), catalog(&"frost_armor_1")]


static func trainer_skills(category: StringName) -> Array[SkillRank]:
	if category == &"Druid":
		return [catalog(&"wrath_1"), catalog(&"healing_touch_1"), catalog(&"mark_1")]
	return starting_skills()


static func catalog(identifier: StringName) -> SkillRank:
	var rows := {
		&"fireball_1": ["Fireball", &"Mage", 133, Effect.DAMAGE, Target.ENEMY,
			30, 1.5, 7, 14, 22, 4, 1],
		&"frost_armor_1": ["Frost Armor", &"Mage", 168, Effect.ARMOR, Target.SELF,
			60, 1.0, 0, 30, 30, 1800, 0],
		&"wrath_1": ["Wrath", &"Druid", 5176, Effect.DAMAGE, Target.ENEMY,
			20, 1.5, 6, 12, 14, 0, 0],
		&"healing_touch_1": ["Healing Touch", &"Druid", 5185, Effect.HEAL, Target.ALLY,
			25, 1.5, 8, 37, 51, 0, 0],
		&"mark_1": ["Mark of the Wild", &"Druid", 1126, Effect.ARMOR, Target.ALLY,
			20, 1.0, 6, 25, 25, 1800, 0],
	}
	if not rows.has(identifier):
		for skill in development_skills():
			if skill.id == identifier:
				return skill
		return null
	var row: Array = rows[identifier]
	var skill := SkillRank.new(identifier, row[0], row[1], 1, 1, "", row[3])
	skill.source_id = row[2]
	skill.target = row[4]
	skill.mana_cost = row[5]
	skill.cast_seconds = row[6]
	skill.range_tiles = row[7]
	skill.minimum = row[8]
	skill.maximum = row[9]
	skill.duration = row[10]
	skill.periodic_damage = row[11]
	skill.description = "%s rank 1: %d mana, %.1f seconds, range %d tiles. " % [
		skill.title, skill.mana_cost, skill.cast_seconds, skill.range_tiles]
	match skill.effect:
		Effect.DAMAGE:
			skill.description += "%d–%d damage." % [skill.minimum, skill.maximum]
			if skill.periodic_damage > 0:
				skill.description += " Plus 1 damage every 2 turns for 4 turns."
		Effect.HEAL:
			skill.description += "Restore %d–%d health." % [skill.minimum, skill.maximum]
		Effect.ARMOR:
			skill.description += "+%d armor for 1800 turns; refreshes, never stacks with itself." % skill.minimum
			if identifier == &"frost_armor_1":
				skill.description += " Melee attackers are chilled for 5 turns."
	return skill


static func development_skills() -> Array[SkillRank]:
	return [
		SkillRank.new(&"practice_1", "Practice", &"Development", 1, 1,
			"One turn; 0 mana. Reports a harmless practice cast.", Effect.PRACTICE, true),
		SkillRank.new(&"experience_1", "Gain 450 XP", &"Development", 1, 1,
			"One turn; 0 mana. Awards 450 XP through ordinary leveling.", Effect.EXPERIENCE, true),
		SkillRank.new(&"death_1", "Death trigger", &"Development", 1, 1,
			"One turn; 0 mana. Die and begin the next Loop.", Effect.DEATH_NOTICE, true),
	]
