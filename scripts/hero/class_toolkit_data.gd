class_name ClassToolkitData
extends RefCounted

## Provisional v0.1 tuning. Passive rows: title, class, XP, magnitude, chance, duration, detail.
const EARTH_ELEMENTAL_DAMAGE_MIN: float = 2.0
const EARTH_ELEMENTAL_DAMAGE_MAX: float = 4.0
const EARTH_ELEMENTAL_SWING_TURNS: float = 2.5

const PASSIVES: Dictionary = {
	"eviscerate_1": ["Eviscerate", "Rogue", 5, 12, 0.0, 0, "Slice and Dice also attacks your current melee target for 75% weapon damage plus 12 per combo point spent as physical damage. Hit/crit and armor apply. Misses still spend points; finisher refunds happen once after spending. Builds no new attack points. No extra rage or turn. Slice and Dice remains usable without a target."],
	"cruelty_1": ["Cruelty", "Warrior", 60, 10, 0.0, 0, "+10% weapon critical chance."],
	"enrage_1": ["Enrage", "Warrior", 10, 10, 0.3, 6, "Surviving enemy hits that deal damage have a 30% chance to grant +10% physical damage and +5 percentage points of attack critical chance for 6 turns, at any health. At most one roll per world turn. Refreshes without stacking; misses, dodges and immune hits cannot trigger it."],
	"recklessness_1": ["Recklessness", "Warrior", 30, 20, 0.0, 0, "As health falls, gain physical damage and take more damage: scales smoothly from no bonus at full health to +20% physical damage dealt and +10% damage taken at 25% health. Both bonuses stay capped below 25%. Healing immediately reduces both effects. Applies in every class once learned."],
	"battle_trance_1": ["Battle Trance", "Warrior", 165, 0, 0.0, 0, "Direct physical, Holy and Nature active crits make the next rage-costing active free until used. Finishers cannot trigger it."],
	"sudden_death_1": ["Sudden Death", "Warrior", 270, 0, 0.2, 0, "Landed direct physical active attacks other than Execute have a 20% chance to allow one free Execute at any health until used. Auto-attacks and bonus damage cannot trigger it. The proc Execute spends no extra rage."],
	"victory_rush_1": ["Victory Rush", "Warrior", 190, 10, 0.0, 0, "Enemy kills heal 10% of maximum health. Summons and friendly actors do not qualify."],
	"sweeping_strikes_1": ["Sweeping Strikes", "Warrior", 245, 50, 0.0, 0, "Landed direct physical actives copy 50% of their damage to one other hostile enemy in melee. Copies cannot proc, crit or generate rage/combo points."],
	"wrecking_crew_1": ["Wrecking Crew", "Warrior", 300, 25, 0.0, 6, "Weapon crits grant +25% physical damage for 6 turns."],
	"juggernaut_1": ["Juggernaut", "Warrior", 330, 2, 0.0, 0, "Charge cooldown is 2 turns shorter; arrival guarantees the next Mortal Strike crit until used."],
	"improved_shields_1": ["Improved Shields", "Shaman", 20, 50, 0.0, 0, "Lightning Shield has 6 charges and deals 50% more damage."],
	"shaman_flurry_1": ["Flurry", "Shaman", 30, 30, 0.0, 0, "Weapon crits grant 3 charges of +30% attack haste until consumed. Ordinary main/off-hand swings consume charges."],
	"static_shock_1": ["Static Shock", "Shaman", 60, 0, 0.2, 0, "Landed primary weapon attacks have a 20% chance to discharge a Lightning Shield charge, ignoring its retaliation cooldown."],
	"elemental_weapons_1": ["Elemental Weapons", "Shaman", 75, 40, 0.0, 0, "Windfury bonus damage increases 40%."],
	"elemental_assault_1": ["Elemental Assault", "Shaman", 90, 20, 0.0, 0, "Earth Shock deals 20% more damage. A weapon crit empowers the next Earth Shock by another 50% until used."],
	"spirit_hunt_1": ["Spirit Hunt", "Shaman", 145, 50, 0.0, 0, "Spirit wolves heal you for 50% of their actual damage dealt."],
	"toughness_1": ["Toughness", "Shaman", 160, 20, 0.0, 0, "+20% armor."],
	"improved_earth_shock_1": ["Improved Earth Shock", "Shaman", 180, 1, 0.0, 1, "Earth Shock cooldown is 1 turn shorter; its interrupt also stuns for 1 enemy turn."],
	"benediction_1": ["Benediction", "Paladin", 15, 20, 0.0, 0, "Paladin actives cost 20% less rage, rounded up."],
	"conviction_1": ["Conviction", "Paladin", 45, 3, 0.0, 0, "+3% weapon and direct Holy/Nature critical chance."],
	"vengeance_1": ["Vengeance", "Paladin", 75, 3, 0.0, 10, "Primary attack crits grant +3% damage, stacking 3 times for 10 turns."],
	"art_of_war_1": ["Art of War", "Paladin", 60, 3, 0.0, 0, "Every third landed primary Holy event guarantees your next Judgement crit until used. Progress does not expire. At most one event counts per world-turn action, including Seal damage."],
	"heart_of_the_crusader_1": ["Heart of the Crusader", "Paladin", 105, 3, 0.0, 10, "Landed Judgement gives +3% critical chance against that enemy for 10 turns."],
	"divine_purpose_1": ["Divine Purpose", "Paladin", 120, 0, 0.15, 0, "Landed Judgement has a 15% chance to make the next Judgement free until used."],
	"pursuit_of_justice_1": ["Pursuit of Justice", "Paladin", 135, 20, 0.0, 0, "+20% movement credit: periodically move an extra tile in the chosen direction, stopping at obstacles."],
	"eye_for_an_eye_1": ["Eye for an Eye", "Paladin", 150, 30, 0.0, 0, "Surviving an incoming critical hit reflects 30% of damage taken as Holy damage. Reflections cannot proc."],
	"guardians_favor_1": ["Guardian's Favor", "Paladin", 165, 10, 0.0, 1, "Divine Shield cooldown is 10 turns shorter and its duration is 1 turn longer."],
	"sacred_duty_1": ["Sacred Duty", "Paladin", 185, 0, 0.25, 0, "Landed Judgement has a 25% chance to guarantee the next Judgement crit until used."],
	"sanctity_of_battle_1": ["Sanctity of Battle", "Paladin", 210, 35, 0.0, 0, "Judgement deals +35 Holy damage. Its cooldown is divided by current attack haste, rounded up to at least 1 turn."],
	"opportunity_1": ["Opportunity", "Rogue", 15, 20, 0.0, 0, "Direct physical actives deal 20% more damage from behind."],
	"ambidexterity_1": ["Ambidexterity", "Rogue", 30, 25, 0.0, 0, "Raises off-hand weapon damage from 50% to 75% in any class. Dual-wield pairs are always usable; off-hand swings grant no ordinary rage."],
	"combat_potency_1": ["Combat Potency", "Rogue", 60, 5, 0.2, 0, "Landed ordinary off-hand swings have a 20% chance to grant 5 rage."],
	"seal_fate_1": ["Seal Fate", "Rogue", 75, 1, 0.0, 0, "Direct active crits grant one additional combo point after Relentless Assault. Finishers and bonus strikes do not qualify."],
	"main_gauche_1": ["Main Gauche", "Rogue", 95, 100, 0.15, 0, "Landed main-hand swings have a 15% chance for an off-hand bonus strike. Requires an off-hand weapon; no recursive procs or rage."],
	"restless_blades_1": ["Restless Blades", "Rogue", 135, 1, 0.0, 0, "Finishers reduce remaining offensive and defensive ability cooldowns by 1 turn per 2 points spent, rounded up."],
	"catalytic_venom_1": ["Catalytic Venom", "Rogue", 155, 1, 0.0, 0, "While dual wielding, Instant Poison on your faster base-speed weapon also applies one stack of the slower weapon's Deadly Poison. Both coatings must be active. Equal-speed weapons do not catalyze. No extra roll or recursive procs."],
	"bandits_guile_1": ["Bandit's Guile", "Rogue", 185, 5, 0.0, 12, "Every 4 landed direct active attacks grant +5% damage, up to 15%, for 12 turns. Misses and finishers do not advance it."],
	"ruthlessness_1": ["Ruthlessness", "Rogue", 170, 1, 0.6, 0, "After a finisher spends points, 60% chance to refund 1 combo point."],
	"relentless_strikes_1": ["Relentless Strikes", "Rogue", 200, 15, 0.2, 0, "Finishers have a 20% chance per point spent to refund 15 rage, after spending."],
	"precision_1": ["Precision", "Rogue", 215, 5, 0.0, 0, "+5% weapon and direct Holy/Nature hit chance."],
}
const ACTIVES: Dictionary = {
	"whirlwind_1": {"title": "Whirlwind", "class_tab": "Warrior", "progress_required": 0, "rage_cost": 15, "cast_seconds": 1.0, "weapon_multiplier": 0.7, "family": "whirlwind", "effect": "TOOLKIT", "target": "NONE", "range_tiles": 1, "detail": "70% weapon damage to each adjacent neutral or hostile enemy in sight (3x3 area), in stable actor order. One turn, no cooldown; weapon timing continues. Each landed hit can crit/proc; Relentless Assault grants at most one base point per turn. Keeps your selected attack target. Stops on terminal death; one class XP use."},
	"booming_shout_1": {"title": "Booming Shout", "class_tab": "Warrior", "progress_required": 315, "rage_cost": 0, "cast_seconds": 1.0, "cooldown_seconds": 30, "range_tiles": 4, "minimum": 1, "family": "booming_shout", "effect": "TOOLKIT", "target": "NONE", "detail": "Deal exactly 1 damage to every neutral or hostile NPC within 4 tiles (9x9 area), in sight, engaging them. Guaranteed hit; no crits, armor reduction, damage bonuses, attack procs or combo points. Keeps your selected attack target. One turn; 30-turn cooldown."},
	"windfury_weapon_1": {"title": "Windfury Weapon", "class_tab": "Shaman", "progress_required": 45, "rage_cost": 0, "duration": 60, "coefficient": 0.25, "weapon_multiplier": 1.0, "family": "windfury_weapon", "effect": "ARMOR", "target": "SELF", "detail": "Enchant the current main-hand weapon for 60 turns. Landed primary main-hand swings/physical actives have 25% chance for 2 weapon bonus strikes, at most once per 3 turns. Bonuses do not proc or grant rage/combo points."},
	"earth_shock_1": {"title": "Earth Shock", "class_tab": "Shaman", "progress_required": 0, "rage_cost": 15, "cooldown_seconds": 7, "range_tiles": 3, "weapon_multiplier": 0.0, "minimum": 24, "school": 3, "family": "earth_shock", "effect": "TOOLKIT", "target": "ENEMY", "detail": "24 Nature damage, independent of weapon damage and Strength; hit/crit and level differences apply, armor does not. Interrupts and delays the enemy's next swing by 1 turn. One turn; a landed attack builds combo points."},
	"earth_elemental_1": {"title": "Earth Elemental", "class_tab": "Shaman", "progress_required": 110, "rage_cost": 25, "cooldown_seconds": 60, "minimum": 40, "range_tiles": 4, "family": "earth_elemental", "effect": "SUMMON", "target": "NONE", "detail": "Summon one mobile Earth Elemental with 40 health until killed or Loop reset. Repeatedly taunts already engaged hostile enemies within 4 tiles and sight of itself, making them attack it while in range. Follows your selected engaged enemy or returns to you; attacks for 2-4 physical damage every 2.5 turns. Cannot summon while one is alive. One turn; requires a free adjacent tile."},
	"feral_spirit_1": {"title": "Feral Spirit", "class_tab": "Shaman", "progress_required": 130, "rage_cost": 25, "cooldown_seconds": 30, "duration": 12, "minimum": 50, "weapon_multiplier": 0.75, "family": "feral_spirit", "effect": "TOOLKIT", "target": "NONE", "detail": "Summon 2 wolves on free adjacent tiles for 12 turns, replacing your wolves. Each has 50 health and strikes every 2 turns for 75% of your weapon damage at summoning. They follow your selected enemy, grant no XP/rage/points and can be attacked. Requires 2 free or replaceable tiles."},
	"blessing_of_might_1": {"title": "Blessing of Might", "class_tab": "Paladin", "progress_required": 30, "rage_cost": 10, "duration": 30, "minimum": 6, "family": "blessing_of_might", "effect": "ARMOR", "target": "SELF", "detail": "+6 Strength for 30 turns. Stacks with Battle Shout."},
	"divine_shield_1": {"title": "Divine Shield", "class_tab": "Paladin", "progress_required": 90, "rage_cost": 20, "cooldown_seconds": 30, "duration": 3, "minimum": 30, "family": "divine_shield", "effect": "ARMOR", "target": "SELF", "detail": "Immune to all incoming damage for 3 turns; deal 30% less damage. Costs one action; weapon timing continues. Guardian's Favor extends it."},
	"evasion_1": {"title": "Evasion", "class_tab": "Rogue", "progress_required": 45, "rage_cost": 15, "cooldown_seconds": 20, "duration": 5, "minimum": 40, "family": "evasion", "effect": "ARMOR", "target": "SELF", "detail": "+40% dodge for 5 turns, including attacks from behind. Costs one action."},
	"instant_poison_1": {"title": "Instant Poison", "class_tab": "Rogue", "progress_required": 115, "rage_cost": 10, "duration": 30, "minimum": 8, "coefficient": 0.3, "family": "instant_poison", "effect": "ARMOR", "target": "SELF", "detail": "Coat your chosen weapon hand(s) for 30 turns. Replaces that hand's poison. Each landed primary weapon attack has 30% chance to add 8 Nature damage. Bonus strikes cannot trigger poison. One turn."},
	"deadly_poison_1": {"title": "Deadly Poison", "class_tab": "Rogue", "progress_required": 115, "rage_cost": 10, "duration": 30, "maximum": 5, "periodic_damage": 1.5, "periodic_duration": 12, "coefficient": 0.3, "family": "deadly_poison", "effect": "ARMOR", "target": "SELF", "detail": "Coat your chosen weapon hand(s) for 30 turns, replacing that hand's poison. Landed primary weapon attacks have 30% chance to add a Deadly stack. Up to 5 shared stacks per enemy deal 1.5 Nature damage each per turn for 12 turns. Applications refresh duration without delaying ticks. No crits or proc chains. One turn."},
}


static func skills() -> Dictionary:
	var result := ACTIVES.duplicate(true)
	for identifier in PASSIVES:
		var row: Array = PASSIVES[identifier]
		result[identifier] = {"title": row[0], "class_tab": row[1],
			"progress_required": row[2], "minimum": row[3], "coefficient": row[4],
			"duration": row[5], "detail": "Passive: " + row[6],
			"family": String(identifier).trim_suffix("_1"), "effect": "PASSIVE", "target": "NONE"}
	result["eviscerate_1"].merge({"weapon_multiplier": 0.75, "range_tiles": 1})
	result["enrage_1"]["critical_percent"] = 5
	result["recklessness_1"].merge({"damage_taken_percent": 10, "health_cap_percent": 25})
	for row: Dictionary in result.values():
		row["training_level"] = 1
	return result
