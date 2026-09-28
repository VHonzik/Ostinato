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
var swing := SwingTimer.new()
var melee := MeleeProfile.new()
var facing := Vector2i.DOWN
var learned_skills: Array[SkillRank] = []
var selected_class: StringName = &"Mage"
var equipment: Dictionary = {}
var inventory: Array[Dictionary] = []
var copper: int = 0
var buffs: Dictionary = {}
var casting_credit: float = 0.0
var last_mana_turn: int = -5
var spell_power: int = 0
var healing_power: int = 0
var spell_hit: float = 0.0
var spell_critical: float = 0.0
var haste: float = 1.0
var resistances: Dictionary = {}
var cooldowns: Dictionary = {}
var potion_ready_turn: int = 0
var restoration: Dictionary = {}


func _init(development_build: bool = OS.is_debug_build()) -> void:
	_apply_level_stats()
	StarterGear.equip_outfit(self)
	health = max_health
	mana = max_mana
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
	refresh_stats()
	# Classic level-up refills resources after current equipment and buffs.
	health = max_health
	mana = max_mana


func refresh_stats() -> void:
	var values := HeroData.stats_for_level(level)
	var attributes := {"strength": values[0], "agility": values[1], "stamina": values[2],
		"intellect": values[3], "spirit": values[4]}
	for item in equipment.values():
		var data := ItemData.get_item(int(item.id))
		for stat in data.stats:
			attributes[stat] += int(data.stats[stat])
	for buff in buffs.values():
		for stat in attributes:
			attributes[stat] += int(buff.get(stat, 0))
	strength = attributes.strength
	agility = attributes.agility
	stamina = attributes.stamina
	intellect = attributes.intellect
	spirit = attributes.spirit
	max_health = values[5] + mini(20, stamina) + maxi(0, stamina - 20) * 10
	max_mana = values[6] + mini(20, intellect) + maxi(0, intellect - 20) * 15
	health = mini(health, max_health)
	mana = mini(mana, max_mana)
	refresh_melee_stats()


func refresh_melee_stats() -> void:
	var armor := 0
	for item in equipment.values():
		armor += int(ItemData.get_item(int(item.id)).armor)
	for buff in buffs.values():
		armor += int(buff.get("armor", 0))
	melee.player = true
	melee.level = level
	melee.attack_power = maxi(0, strength - 10)
	melee.armor = agility * 2 + armor
	var agility_per_percent := lerpf(12.9, 20.0, (clampi(level, 1, 60) - 1) / 59.0)
	melee.critical = agility / agility_per_percent
	melee.dodge = 3.25 + melee.critical
	melee.damage_min = 1.0
	melee.damage_max = 2.0
	melee.interval = 2.0
	if equipment.has("main_hand"):
		var weapon := ItemData.get_item(int(equipment.main_hand.id))
		melee.damage_min = float(weapon.minimum)
		melee.damage_max = float(weapon.maximum)
		melee.interval = float(weapon.interval)
	melee.block = 0.0
	melee.block_value = 0
	if equipment.has("off_hand"):
		var shield := ItemData.get_item(int(equipment.off_hand.id))
		if shield.shield:
			melee.block = 5.0
			melee.block_value = maxi(0, int(shield.block) + floori(strength / 20.0) - 1)
