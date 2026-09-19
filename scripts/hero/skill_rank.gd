class_name SkillRank
extends RefCounted

## Initial FR-017/046/050 rank records. Real spell execution arrives with combat.
enum Effect { PREVIEW, PRACTICE, EXPERIENCE, DEATH_NOTICE }

var id: StringName
var title: String
var class_tab: StringName
var rank: int
var training_level: int
var description: String
var effect: Effect
var development_only: bool


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
	return [
		SkillRank.new(&"fireball_1", "Fireball", &"Mage", 1, 1,
			"Known starting spell (133). Combat casting arrives in milestone 4.", Effect.PREVIEW),
		SkillRank.new(&"frost_armor_1", "Frost Armor", &"Mage", 1, 1,
			"Known starting spell (168). Armor effects arrive in milestone 4.", Effect.PREVIEW),
	]


static func development_skills() -> Array[SkillRank]:
	return [
		SkillRank.new(&"practice_1", "Practice", &"Development", 1, 1,
			"One turn; 0 mana. Reports a harmless practice cast.", Effect.PRACTICE, true),
		SkillRank.new(&"experience_1", "Gain 450 XP", &"Development", 1, 1,
			"One turn; 0 mana. Awards 450 XP through ordinary leveling.", Effect.EXPERIENCE, true),
		SkillRank.new(&"death_1", "Death trigger", &"Development", 1, 1,
			"One turn; 0 mana. Reports invocation; death state arrives in milestone 3.",
			Effect.DEATH_NOTICE, true),
	]
