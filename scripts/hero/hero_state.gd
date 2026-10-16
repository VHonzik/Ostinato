class_name HeroState
extends RefCounted

## Warrior start, excess XP, and persistent learned abilities.
const MAX_RAGE: int = 100
const MAX_COMBO_POINTS: int = 5
const SWING_RAGE_PER_BASE_TURN: float = 7.0
const INCOMING_RAGE_PER_TURN: float = 3.0
const BASE_CRITICAL_CHANCE: float = 5.0
const BASE_OFF_HAND_DAMAGE_PERCENT: float = 50.0
const PRIMARY_STAT_BASE: int = 20
const BASE_WEAPON_POWER: int = 10
const WEAPON_POWER_PER_STRENGTH: int = 2
const AGILITY_CRIT_PERCENT: float = 1.0
const AGILITY_DODGE_PERCENT: float = 1.0

var rage: int = 0
var combo_points: int = 0
var rage_credit: float = 0.0
var rage_decay_credit: float = 0.0
var last_hit_rage_turn: int = -1
var last_enrage_roll_turn: int = -1
var class_progress: Dictionary[StringName, int] = {}
var warrior_progress: int:
	get:
		return progression_points(&"Warrior")
	set(value):
		class_progress[&"Warrior"] = value
var level: int = 1
var experience: int = 0
var strength: int
var agility: int
var stamina: int
var max_health: int
var health: int
var swing := SwingTimer.new()
var off_hand_swing := SwingTimer.new()
var melee := MeleeProfile.new()
var facing := Vector2i.DOWN
var learned_skills: Array[SkillDefinition] = []
var selected_class: StringName = &"Warrior"
var equipment: Dictionary = {}
var inventory: Array[Dictionary] = []
var copper: int = 0
var buffs: Dictionary = {}
var casting_credit: float = 0.0
var haste: float = 1.0
var cooldowns: Dictionary = {}
var potion_ready_turn: int = 0
var restoration: Dictionary = {}
var debuffs: Dictionary = {}
var _passive_hit_bonus: float = 0.0


func _init(development_build: bool = OS.is_debug_build()) -> void:
	_apply_level_stats()
	StarterGear.equip_travel_clothes(self)
	health = max_health
	for skill in SkillDefinition.starting_skills():
		learn_skill(skill)
	if development_build:
		for skill in SkillDefinition.development_skills():
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


func learn_skill(skill: SkillDefinition) -> bool:
	if skill == null or level < skill.training_level or find_skill(skill.id) != null:
		return false
	learned_skills.append(skill)
	refresh_stats()
	return true


func find_skill(identifier: StringName) -> SkillDefinition:
	for skill in learned_skills:
		if skill.id == identifier:
			return skill
	return null


func _apply_level_stats() -> void:
	refresh_stats()
	# Level-up restores health; rage is unchanged.
	health = max_health


func refresh_stats() -> void:
	var values := HeroData.stats_for_level(level)
	var attributes := {"strength": values[0], "agility": values[1], "stamina": values[2]}
	var haste_percent := 0.0
	for item in equipment.values():
		var data := ItemData.get_item(int(item.id))
		for stat in attributes:
			attributes[stat] += int(data.stats.get(stat, 0))
		haste_percent += float(data.stats.get("haste", 0))
	for buff in buffs.values():
		for stat in attributes:
			attributes[stat] += int(buff.get(stat, 0))
	strength = int(attributes.strength)
	agility = int(attributes.agility)
	stamina = int(attributes.stamina)
	haste = 1.0 + haste_percent / 100.0
	max_health = values[3] + mini(20, stamina) + maxi(0, stamina - 20) * 10
	health = mini(health, max_health)
	refresh_melee_stats()


func refresh_melee_stats() -> void:
	var armor := 0
	var critical_bonus := 0.0
	for item in equipment.values():
		var data := ItemData.get_item(int(item.id))
		armor += int(data.armor)
		critical_bonus += float(data.stats.get("crit", 0.0))
	for buff in buffs.values():
		armor += int(buff.get("armor", 0))
		critical_bonus += float(buff.get("critical_percent", 0))
	melee.damage_multiplier = 1.0
	melee.player = true
	melee.level = level
	melee.attack_power = maxi(0, BASE_WEAPON_POWER
		+ (strength - PRIMARY_STAT_BASE) * WEAPON_POWER_PER_STRENGTH)
	melee.armor = armor
	var agility_per_percent := lerpf(12.9, 20.0, (clampi(level, 1, 60) - 1) / 59.0)
	var base_agility_percent := PRIMARY_STAT_BASE / agility_per_percent
	var bonus_agility := agility - PRIMARY_STAT_BASE
	melee.critical = BASE_CRITICAL_CHANCE + base_agility_percent
	melee.critical += bonus_agility * AGILITY_CRIT_PERCENT + critical_bonus
	melee.critical += ClassToolkitRules.magnitude(self, &"cruelty_1")
	melee.critical += ClassToolkitRules.magnitude(self, &"conviction_1")
	melee.hit -= _passive_hit_bonus
	_passive_hit_bonus = ClassToolkitRules.magnitude(self, &"precision_1")
	melee.hit += _passive_hit_bonus
	melee.dodge = 3.25 + base_agility_percent + bonus_agility * AGILITY_DODGE_PERCENT
	melee.damage_min = 1.0
	melee.damage_max = 2.0
	melee.interval = 2.0
	if equipment.has("weapons"):
		var weapon := ItemData.get_item(int(equipment.weapons.id))
		melee.damage_min = float(weapon.minimum)
		melee.damage_max = float(weapon.maximum)
		melee.interval = float(weapon.interval)
	for key in buffs:
		var buff: Dictionary = buffs[key]
		melee.damage_multiplier *= 1.0 + int(buff.get("physical_percent", 0)) / 100.0
	melee.armor = floori(melee.armor * (1.0 + ClassToolkitRules.magnitude(self, &"toughness_1") / 100.0))
	if buffs.has(&"evasion_1"):
		melee.dodge += SkillDefinition.catalog(&"evasion_1").minimum


func has_off_hand_weapon() -> bool:
	return (equipment.has("weapons")
		and ItemData.get_item(int(equipment.weapons.id)).weapon_style == "dual_wield")


func off_hand_melee() -> MeleeProfile:
	var weapon := MeleeProfile.new()
	weapon.player = true
	weapon.level = level
	weapon.attack_power = melee.attack_power
	weapon.critical = melee.critical
	weapon.hit = melee.hit
	var off_hand_percent := BASE_OFF_HAND_DAMAGE_PERCENT
	off_hand_percent += ClassToolkitRules.magnitude(self, &"ambidexterity_1")
	weapon.damage_multiplier = melee.damage_multiplier * off_hand_percent / 100.0
	if has_off_hand_weapon():
		var data := ItemData.get_item(int(equipment.weapons.id))
		weapon.damage_min = float(data.off_minimum)
		weapon.damage_max = float(data.off_maximum)
		weapon.interval = float(data.off_interval)
	return weapon


func weapon_id(off_hand: bool = false) -> int:
	if off_hand and not has_off_hand_weapon():
		return 0
	return int(equipment.get("weapons", {}).get("id", 0))


func attack_haste() -> float:
	var multiplier := haste
	for buff in buffs.values():
		multiplier *= 1.0 + float(buff.get("haste_percent", 0)) / 100.0
	return multiplier


func gain_combo_point() -> void:
	if find_skill(&"relentless_assault_1") != null:
		combo_points = mini(MAX_COMBO_POINTS, combo_points + 1)


func gain_rage(amount: float) -> void:
	rage_credit += amount
	var whole := floori(rage_credit + 0.000001)
	rage_credit = maxf(0.0, rage_credit - whole)
	rage = mini(MAX_RAGE, rage + whole)
	if rage == MAX_RAGE:
		rage_credit = 0.0


func decay_rage() -> void:
	if rage == 0:
		rage_decay_credit = 0.0
		return
	rage_decay_credit += 0.5 if find_skill(&"anger_management_1") != null else 2.0
	var whole := floori(rage_decay_credit + 0.000001)
	rage_decay_credit -= whole
	rage = maxi(0, rage - whole)


func progression_points(category: StringName) -> int:
	return class_progress.get(category, 0)
