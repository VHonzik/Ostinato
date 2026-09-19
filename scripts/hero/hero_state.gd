class_name HeroState
extends RefCounted

## FR-015/016/017: mage baseline, excess XP, and explicit learned ranks.
var level: int = 1
var experience: int = 0
var strength: int
var agility: int
var stamina: int
var intellect: int
var spirit: int
var max_health: int
var max_mana: int
var health: int
var mana: int
var learned_skills: Array[SkillRank] = []


func _init(development_build: bool = OS.is_debug_build()) -> void:
	_apply_level_stats()
	for skill in SkillRank.starting_skills():
		learn_skill(skill)
	if development_build:
		for skill in SkillRank.development_skills():
			learn_skill(skill)


func experience_to_next_level() -> int:
	return HeroData.EXPERIENCE[mini(level - 1, HeroData.EXPERIENCE.size() - 1)]


func add_experience(amount: int) -> PackedInt32Array:
	var gained_levels := PackedInt32Array()
	if amount <= 0:
		return gained_levels
	experience += amount
	while experience >= experience_to_next_level():
		experience -= experience_to_next_level()
		level += 1
		_apply_level_stats()
		gained_levels.append(level)
	return gained_levels


func learn_skill(skill: SkillRank) -> bool:
	if skill == null or level < skill.training_level or find_skill(skill.id) != null:
		return false
	learned_skills.append(skill)
	return true


func find_skill(identifier: StringName) -> SkillRank:
	for skill in learned_skills:
		if skill.id == identifier:
			return skill
	return null


func _apply_level_stats() -> void:
	var values := HeroData.stats_for_level(level)
	strength = values[0]
	agility = values[1]
	stamina = values[2]
	intellect = values[3]
	spirit = values[4]
	max_health = values[5] + mini(20, stamina) + maxi(0, stamina - 20) * 10
	max_mana = values[6] + mini(20, intellect) + maxi(0, intellect - 20) * 15
	# Classic level-up restores resources; no regeneration or spending in this fixture.
	health = max_health
	mana = max_mana
