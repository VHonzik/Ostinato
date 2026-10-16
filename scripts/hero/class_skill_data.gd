class_name ClassSkillData
extends RefCounted

## Starter and Warrior skills for the four-class toolkit.
const PLAYABLE_CLASSES: Array[StringName] = [&"Warrior", &"Shaman", &"Paladin", &"Rogue"]
const MAINTENANCE_FAMILIES: Array[StringName] = [
	&"battle_shout", &"windfury_weapon", &"lightning_shield", &"seal_of_command",
	&"instant_poison", &"deadly_poison", &"blessing_of_might",
]
const STARTERS: Dictionary = {
	&"Warrior": [&"mortal_strike_1", &"whirlwind_1"],
	&"Shaman": [&"lightning_shield_1", &"earth_shock_1"],
	&"Paladin": [&"seal_of_command_1", &"execution_sentence_1"],
	&"Rogue": [&"slice_and_dice_1", &"relentless_assault_1"],
}
const WARRIOR_SKILLS: Array[StringName] = [
	&"mortal_strike_1", &"whirlwind_1", &"battle_shout_1", &"anger_management_1", &"charge_1",
	&"execute_1",
]
# Starter tuning is provisional; full class slices extend this runnable set.
const STARTER_SKILLS: Dictionary = {
	"lightning_shield_1": {
		"title": "Lightning Shield", "class_tab": "Shaman", "training_level": 1,
		"rage_cost": 0, "cast_seconds": 1.0, "duration": 30, "minimum": 10,
		"family": "lightning_shield", "effect": "ARMOR", "target": "SELF", "school": 3,
		"detail": "Three Nature-damage charges for 30 turns. At most one discharge per 3 turns. Refreshing counts as a use."
	},
	"seal_of_command_1": {
		"title": "Seal of Command", "class_tab": "Paladin",
		"training_level": 1, "rage_cost": 10, "cast_seconds": 1.0, "duration": 30,
		"weapon_multiplier": 0.25, "family": "seal_of_command", "school": 1,
		"effect": "ARMOR", "target": "SELF",
		"detail": "Landed main-hand swings add 25% weapon damage as Holy damage for 30 turns. Bonus damage grants no rage, class XP or combo points. Execution Sentence leaves the seal active."
	},
	"execution_sentence_1": {
		"title": "Execution Sentence", "class_tab": "Paladin", "training_level": 1,
		"rage_cost": 20, "cast_seconds": 1.0, "range_tiles": 2, "cooldown_seconds": 6,
		"weapon_multiplier": 1.5, "delay_turns": 1, "family": "execution_sentence", "school": 1,
		"effect": "EXECUTION_SENTENCE", "target": "ENEMY",
		"detail": "Requires Seal of Command. Sentence the target to 150% weapon damage as Holy damage after 1 further turn. Damage and hit/crit are fixed when cast; later attacks do not build it up. Impact ignores range and armor, triggers attack rewards once, and leaves your current target unchanged. Lost if the target dies first. One turn; seal remains active."
	},
	"slice_and_dice_1": {
		"title": "Slice and Dice", "class_tab": "Rogue", "training_level": 1,
		"rage_cost": 15, "cast_seconds": 1.0, "haste_percent": 30,
		"duration": 5, "duration_per_combo": 3, "family": "slice_and_dice",
		"effect": "ARMOR", "target": "SELF",
		"detail": "Requires at least 1 combo point. Spend all held points for +30% attack speed, lasting 5 turns plus 3 per point. With Eviscerate learned, also attack your current melee target. Usable without a target. Ordinary ability cooldowns are unchanged."
	},
	"relentless_assault_1": {
		"title": "Relentless Assault", "class_tab": "Rogue", "training_level": 1,
		"family": "relentless_assault", "effect": "PASSIVE", "target": "NONE",
		"detail": "Passive: landed direct active attacks and ordinary main-hand hits grant 1 player-held combo point, up to 5, across classes and targets. At most 1 Relentless Assault point per turn. Off-hand hits, procs, buffs and misses grant none. Points reset on death."
	},
}
const CLASSES: Array[StringName] = PLAYABLE_CLASSES
const SKILLS: Dictionary = {
	"mortal_strike_1": {
		"title": "Mortal Strike", "class_tab": "Warrior", "training_level": 1,
		"rage_cost": 30, "cast_seconds": 1.0, "range_tiles": 1, "cooldown_seconds": 4,
		"family": "mortal_strike", "effect": "MORTAL_STRIKE", "target": "ENEMY",
		"weapon_multiplier": 2.0,
		"detail": "200% weapon damage. One turn; weapon timing continues. 4-turn cooldown."
	},
	"battle_shout_1": {
		"title": "Battle Shout", "class_tab": "Warrior", "training_level": 1,
		"progress_required": 20, "cast_seconds": 1.0, "duration": 60, "cooldown_seconds": 30,
		"family": "battle_shout", "effect": "BATTLE_SHOUT", "target": "SELF",
		"physical_percent": 10, "rage_generated": 10,
		"detail": "Increases physical damage by 10% for 60 turns and instantly generates 10 rage. 30-turn cooldown."
	},
	"anger_management_1": {
		"title": "Anger Management", "class_tab": "Warrior",
		"training_level": 1, "progress_required": 40,
		"family": "anger_management", "effect": "PASSIVE", "target": "NONE",
		"detail": "Passive: out-of-combat rage decay becomes 0.5 per turn. Retained across Loops."
	},
	"charge_1": {
		"title": "Charge", "class_tab": "Warrior", "training_level": 1,
		"progress_required": 80, "cast_seconds": 1.0, "range_tiles": 9,
		"minimum_range_tiles": 2, "cooldown_seconds": 10,
		"family": "charge", "effect": "CHARGE", "target": "ENEMY",
		"travel_speed": 4, "rage_generated": 10,
		"detail": "Wind up for one turn, then move at 4 tiles per turn to the nearest empty melee tile. Holds the target in place until melee arrival. Cannot act or cancel during Charge. Generates 10 rage on arrival. 10-turn cooldown."
	},
	# Execute tuning is provisional until combat playtesting.
	"execute_1": {
		"title": "Execute", "class_tab": "Warrior", "training_level": 1,
		"progress_required": 140, "rage_cost": 15, "cast_seconds": 1.0, "range_tiles": 1,
		"family": "execute", "effect": "EXECUTE", "target": "ENEMY",
		"weapon_multiplier": 1.5, "minimum": 25, "execute_health_percent": 20,
		"execute_rage_cap": 30, "execute_damage_per_rage": 2,
		"detail": "Requires a melee target at or below 20% health and at least 15 rage. Spend up to 30 current rage for 150% weapon damage + 25 + 2 damage per rage above 15. Physical hit and crit rules apply; misses spend rage. One turn, no cooldown; weapon timing continues. A landed attack builds Relentless Assault; no combo points are spent."
	},
}


static func is_playable_skill(identifier: StringName) -> bool:
	return (identifier in WARRIOR_SKILLS or STARTER_SKILLS.has(String(identifier))
		or ClassToolkitData.PASSIVES.has(String(identifier))
		or ClassToolkitData.ACTIVES.has(String(identifier)))
