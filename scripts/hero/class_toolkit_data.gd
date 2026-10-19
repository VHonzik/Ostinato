class_name ClassToolkitData
extends RefCounted

## Provisional v0.1 tuning. Passive rows: title, class, training copper, magnitude, chance, duration, detail, level.

const PASSIVES: Dictionary = {
	"slice_and_dice_1": ["Slice and Dice", "Rogue", 10, 30, 0.0, 5, "Eviscerate grants +30% attack speed for 5 turns plus 3 per combo point spent, even on a miss. Refreshes without stacking. No extra rage or action; ordinary ability cooldowns are unchanged.", 1],
	"cruelty_1": ["Cruelty", "Warrior", 90, 10, 0.0, 0, "+10% weapon critical chance.", 2],
	"enrage_1": ["Enrage", "Warrior", 15, 10, 0.3, 10, "Surviving enemy hits that deal damage have a 30% chance to grant +10% physical damage and +5 percentage points of attack critical chance for 10 turns, at any health. At most one roll per world turn. Refreshes without stacking; misses, dodges and immune hits cannot trigger it.", 1],
	"recklessness_1": ["Recklessness", "Warrior", 45, 20, 0.0, 0, "As health falls, gain physical damage and take more damage: scales smoothly from no bonus at full health to +20% physical damage dealt and +10% damage taken at 25% health. Both bonuses stay capped below 25%. Healing immediately reduces both effects. Applies in every class once learned.", 2],
	"battle_trance_1": ["Battle Trance", "Warrior", 250, 0, 0.0, 0, "Direct physical, Holy and Nature active crits make the next rage-costing active free until used. Finishers cannot trigger it.", 4],
	"sudden_death_1": ["Sudden Death", "Warrior", 405, 0, 0.2, 0, "Landed direct physical active attacks other than Execute have a 20% chance to allow one free Execute at any health until used. Auto-attacks and bonus damage cannot trigger it. The proc Execute spends no extra rage.", 5],
	"victory_rush_1": ["Victory Rush", "Warrior", 285, 10, 0.0, 0, "Enemy kills heal 10% of maximum health. Summons and friendly actors do not qualify.", 4],
	"sweeping_strikes_1": ["Sweeping Strikes", "Warrior", 370, 50, 0.0, 0, "Landed direct physical actives copy 50% of their damage to one other hostile enemy in melee. Copies cannot proc, crit or generate rage/combo points.", 5],
	"wrecking_crew_1": ["Wrecking Crew", "Warrior", 450, 25, 0.0, 10, "Weapon crits grant +25% physical damage for 10 turns.", 5],
	"juggernaut_1": ["Juggernaut", "Warrior", 495, 2, 0.0, 0, "Charge cooldown is 2 turns shorter; arrival guarantees the next Mortal Strike crit until used.", 5],
	"improved_shields_1": ["Improved Shields", "Shaman", 60, 50, 0.0, 0, "Lightning Shield has 6 charges and deals 50% more damage.", 2],
	"shaman_flurry_1": ["Flurry", "Shaman", 90, 30, 0.0, 0, "Weapon crits grant 3 charges of +30% attack haste until consumed. Ordinary main/off-hand swings consume charges.", 2],
	"static_shock_1": ["Static Shock", "Shaman", 180, 0, 0.2, 0, "Landed primary weapon attacks have a 20% chance to discharge a Lightning Shield charge, ignoring its retaliation cooldown.", 3],
	"elemental_weapons_1": ["Elemental Weapons", "Shaman", 225, 40, 0.0, 0, "Windfury bonus damage increases 40%.", 3],
	"elemental_assault_1": ["Elemental Assault", "Shaman", 270, 20, 0.0, 0, "Earth Shock deals 20% more damage. A weapon crit empowers the next Earth Shock by another 50% until used.", 3],
	"spirit_hunt_1": ["Spirit Hunt", "Shaman", 435, 50, 0.0, 0, "Spirit wolves heal you for 50% of their actual damage dealt.", 4],
	"toughness_1": ["Toughness", "Shaman", 480, 20, 0.0, 0, "+20% armor.", 5],
	"improved_earth_shock_1": ["Improved Earth Shock", "Shaman", 540, 1, 0.0, 1, "Earth Shock cooldown is 1 turn shorter; its interrupt also stuns for 1 enemy turn.", 5],
	"conviction_1": ["Conviction", "Paladin", 100, 3, 0.0, 0, "+3% weapon and direct Holy/Nature critical chance.", 2],
	"vengeance_1": ["Vengeance", "Paladin", 170, 3, 0.0, 10, "Primary attack crits grant +3% damage, stacking 3 times for 10 turns.", 3],
	"art_of_war_1": ["Art of War", "Paladin", 135, 3, 0.0, 0, "Every third landed primary Holy event guarantees your next Execution Sentence crit until used. Progress does not expire. At most one event counts per world-turn action, including Seal damage.", 3],
	"heart_of_the_crusader_1": ["Heart of the Crusader", "Paladin", 235, 3, 0.0, 10, "Landed Execution Sentence gives +3% critical chance against that enemy for 10 turns.", 4],
	"divine_purpose_1": ["Divine Purpose", "Paladin", 270, 0, 0.15, 0, "Landed Execution Sentence has a 15% chance to make the next Execution Sentence free until used.", 4],
	"pursuit_of_justice_1": ["Pursuit of Justice", "Paladin", 305, 20, 0.0, 0, "+20% movement credit: periodically move an extra tile in the chosen direction, stopping at obstacles.", 4],
	"eye_for_an_eye_1": ["Eye for an Eye", "Paladin", 340, 30, 0.0, 0, "Surviving an incoming critical hit reflects 30% of damage taken as Holy damage. Reflections cannot proc.", 5],
	"guardians_favor_1": ["Guardian's Favor", "Paladin", 370, 10, 0.0, 1, "Divine Shield cooldown is 10 turns shorter and its duration is 1 turn longer.", 5],
	"sacred_duty_1": ["Sacred Duty", "Paladin", 415, 0, 0.25, 0, "Landed Execution Sentence has a 25% chance to guarantee the next Execution Sentence crit until used.", 5],
	"sanctity_of_battle_1": ["Sanctity of Battle", "Paladin", 470, 35, 0.0, 0, "Execution Sentence deals +35 Holy damage. Its cooldown is divided by current attack haste, rounded up to at least 1 turn.", 5],
	"ambidexterity_1": ["Ambidexterity", "Rogue", 60, 25, 0.0, 0, "Raises off-hand weapon damage from 50% to 75% in any class. Dual-wield pairs are always usable; off-hand swings grant no ordinary rage.", 2],
	"combat_potency_1": ["Combat Potency", "Rogue", 120, 5, 0.2, 0, "Landed ordinary off-hand swings have a 20% chance to grant 5 rage.", 3],
	"seal_fate_1": ["Seal Fate", "Rogue", 150, 1, 0.0, 0, "Direct active crits grant one additional combo point after Relentless Assault. Finishers and bonus strikes do not qualify.", 3],
	"main_gauche_1": ["Main Gauche", "Rogue", 190, 100, 0.15, 0, "Landed main-hand swings have a 15% chance for an off-hand bonus strike. Requires an off-hand weapon; no recursive procs or rage.", 3],
	"restless_blades_1": ["Restless Blades", "Rogue", 270, 1, 0.0, 0, "Finishers reduce remaining offensive and defensive ability cooldowns by 1 turn per 2 points spent, rounded up.", 4],
	"catalytic_venom_1": ["Catalytic Venom", "Rogue", 310, 1, 0.0, 0, "While dual wielding, Instant Poison on your faster base-speed weapon also applies one stack of the slower weapon's Deadly Poison. Both coatings must be active. Equal-speed weapons do not catalyze. No extra roll or recursive procs.", 5],
	"bandits_guile_1": ["Bandit's Guile", "Rogue", 370, 5, 0.0, 10, "Every 4 landed direct active attacks grant +5% damage, up to 15%, for 10 turns. Misses and finishers do not advance it.", 5],
	"ruthlessness_1": ["Ruthlessness", "Rogue", 340, 1, 0.6, 0, "After a finisher spends points, 60% chance to refund 1 combo point.", 5],
	"relentless_strikes_1": ["Relentless Strikes", "Rogue", 400, 15, 0.2, 0, "Finishers have a 20% chance per point spent to refund 15 rage, after spending.", 5],
	"precision_1": ["Precision", "Rogue", 430, 5, 0.0, 0, "+5% weapon and direct Holy/Nature hit chance.", 5],
}
const ACTIVES: Dictionary = {
	"whirlwind_1": {"title": "Whirlwind", "class_tab": "Warrior", "training_level": 1, "training_copper": 0, "rage_cost": 15, "cast_seconds": 1.0, "weapon_multiplier": 0.7, "family": "whirlwind", "effect": "TOOLKIT", "target": "NONE", "range_tiles": 1, "detail": "70% weapon damage to each adjacent neutral or hostile enemy in sight (3x3 area), in stable actor order. One turn, no cooldown; weapon timing continues. Each landed hit can crit/proc; Relentless Assault grants at most one base point per turn. Keeps your selected attack target. Stops on terminal death."},
	"windfury_weapon_1": {"title": "Windfury Weapon", "class_tab": "Shaman", "training_level": 2, "training_copper": 135, "rage_cost": 0, "duration": 60, "coefficient": 0.25, "weapon_multiplier": 1.0, "family": "windfury_weapon", "effect": "ARMOR", "target": "SELF", "detail": "Enchant the current main-hand weapon for 60 turns. Landed primary main-hand swings/physical actives have 25% chance for 2 weapon bonus strikes, at most once per 3 turns. Bonuses do not proc or grant rage/combo points."},
	"earth_shock_1": {"title": "Earth Shock", "class_tab": "Shaman", "training_level": 1, "training_copper": 0, "rage_cost": 15, "cooldown_seconds": 7, "range_tiles": 3, "weapon_multiplier": 0.0, "minimum": 24, "school": 3, "family": "earth_shock", "effect": "TOOLKIT", "target": "ENEMY", "detail": "24 Nature damage, independent of weapon damage and Strength; hit/crit and level differences apply, armor does not. Interrupts and delays the enemy's next swing by 1 turn. One turn; a landed attack builds combo points."},
	"feral_spirit_1": {"title": "Feral Spirit", "class_tab": "Shaman", "training_level": 4, "training_copper": 390, "rage_cost": 25, "cooldown_seconds": 30, "duration": 12, "minimum": 50, "weapon_multiplier": 0.75, "family": "feral_spirit", "effect": "TOOLKIT", "target": "NONE", "detail": "Summon 2 wolves on free adjacent tiles for 12 turns, replacing your wolves. Each has 50 health and strikes every 2 turns for 75% of your weapon damage at summoning. They follow your selected enemy, grant no XP/rage/points and can be attacked. Requires 2 free or replaceable tiles."},
	"blessing_of_might_1": {"title": "Blessing of Might", "class_tab": "Paladin", "training_level": 2, "training_copper": 70, "rage_cost": 0, "duration": 60, "minimum": 6, "family": "blessing_of_might", "effect": "ARMOR", "target": "SELF", "detail": "+6 Strength for 60 turns. No rage cost; one turn. Stacks with Battle Shout."},
	"consecration_1": {"title": "Consecration", "class_tab": "Paladin", "training_level": 3, "training_copper": 200, "rage_cost": 5, "cooldown_seconds": 12, "duration": 6, "range_tiles": 1, "periodic_damage": 2.5, "weapon_multiplier": 0.06, "family": "consecration", "school": 1, "effect": "TOOLKIT", "target": "NONE", "detail": "Consecrate the fixed 3x3 area around you for 6 turns, replacing your previous ground. Each turn deals 2.5 + 6% weapon damage as Holy to visible neutral or hostile enemies inside. Damage is fixed when cast; no crits, combo points or attack procs. Ticks begin this turn before weapon swings and enemy actions. No damage reduction; one turn."},
	"divine_shield_1": {"title": "Divine Shield", "class_tab": "Paladin", "training_level": 3, "training_copper": 200, "rage_cost": 20, "cooldown_seconds": 30, "duration": 3, "minimum": 30, "family": "divine_shield", "effect": "ARMOR", "target": "SELF", "detail": "Immune to all incoming damage for 3 turns; deal 30% less damage. Costs one action; weapon timing continues. Guardian's Favor extends it."},
	"evasion_1": {"title": "Evasion", "class_tab": "Rogue", "training_level": 2, "training_copper": 90, "rage_cost": 15, "cooldown_seconds": 20, "duration": 5, "minimum": 40, "family": "evasion", "effect": "ARMOR", "target": "SELF", "detail": "+40% dodge for 5 turns, including attacks from behind. Costs one action."},
	"instant_poison_1": {"title": "Instant Poison", "class_tab": "Rogue", "training_level": 4, "training_copper": 230, "rage_cost": 0, "duration": 60, "minimum": 8, "coefficient": 0.3, "family": "instant_poison", "effect": "ARMOR", "target": "SELF", "detail": "Coat your chosen weapon hand(s) for 60 turns. Replaces that hand's poison. Each landed primary weapon attack has 30% chance to add 8 Nature damage. Bonus strikes cannot trigger poison. No rage cost; one turn."},
	"deadly_poison_1": {"title": "Deadly Poison", "class_tab": "Rogue", "training_level": 4, "training_copper": 230, "rage_cost": 0, "duration": 60, "maximum": 5, "periodic_damage": 1.5, "periodic_duration": 12, "coefficient": 0.3, "family": "deadly_poison", "effect": "ARMOR", "target": "SELF", "detail": "Coat your chosen weapon hand(s) for 60 turns, replacing that hand's poison. Landed primary weapon attacks have 30% chance to add a Deadly stack. Up to 5 shared stacks per enemy deal 1.5 Nature damage each per turn for 12 turns. Ticks resolve at the turn boundary before weapon swings and enemy actions. Applications refresh duration without delaying ticks. No crits or proc chains. No rage cost; one turn."},
}


static func skills() -> Dictionary:
	var result := ACTIVES.duplicate(true)
	for identifier in PASSIVES:
		var row: Array = PASSIVES[identifier]
		result[identifier] = {"title": row[0], "class_tab": row[1],
			"training_copper": row[2], "training_level": row[7], "minimum": row[3], "coefficient": row[4],
			"duration": row[5], "detail": "Passive: " + row[6],
			"family": String(identifier).trim_suffix("_1"), "effect": "PASSIVE", "target": "NONE"}
	result["slice_and_dice_1"].merge({"haste_percent": 30, "duration_per_combo": 3})
	result["enrage_1"]["critical_percent"] = 5
	result["recklessness_1"].merge({"damage_taken_percent": 10, "health_cap_percent": 25})
	return result
