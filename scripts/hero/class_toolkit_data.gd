class_name ClassToolkitData
extends RefCounted

## Provisional v0.1 tuning. Passive rows: title, class, XP, magnitude, chance, duration, detail.
const PASSIVES: Dictionary = {
	"cruelty_1": ["Cruelty", "Warrior", 60, 10, 0.0, 0, "+10% weapon critical chance."],
	"incite_1": ["Incite", "Warrior", 80, 10, 0.0, 10, "+10% Heroic Strike critical chance. A natural Heroic Strike crit guarantees the next queued strike's crit for 10 turns; that guaranteed crit cannot renew Incite."],
	"warrior_flurry_1": ["Flurry", "Warrior", 120, 20, 0.0, 10, "Weapon crits grant 3 charges of +20% attack haste for 10 turns. Ordinary main/off-hand swings consume charges. Shaman Flurry upgrades this same effect."],
	"battle_trance_1": ["Battle Trance", "Warrior", 180, 0, 0.0, 8, "Direct physical, Holy and Nature active crits make the next rage-costing active free within 8 turns. Queued strikes and finishers cannot trigger it."],
	"sudden_death_1": ["Sudden Death", "Warrior", 210, 0, 0.2, 8, "Landed direct physical actives have a 20% chance to allow one free Execute at any health within 8 turns. Ordinary swings scale that chance with base weapon speed against a 2.4-turn reference; dual-wield hands share the chance budget. The proc Execute spends no extra rage."],
	"victory_rush_1": ["Victory Rush", "Warrior", 240, 10, 0.0, 0, "Enemy kills heal 10% of maximum health. Summons and friendly actors do not qualify."],
	"sweeping_strikes_1": ["Sweeping Strikes", "Warrior", 270, 50, 0.0, 0, "Landed direct physical actives copy 50% of their damage to one other hostile enemy in melee. Copies cannot proc, crit or generate rage/combo points."],
	"wrecking_crew_1": ["Wrecking Crew", "Warrior", 300, 25, 0.0, 6, "Weapon crits grant +25% physical damage for 6 turns."],
	"juggernaut_1": ["Juggernaut", "Warrior", 330, 2, 0.0, 6, "Charge cooldown is 2 turns shorter; arrival guarantees the next Mortal Strike crit within 6 turns."],
	"improved_shields_1": ["Improved Shields", "Shaman", 20, 50, 0.0, 0, "Lightning Shield has 6 charges and deals 50% more damage."],
	"shaman_flurry_1": ["Flurry", "Shaman", 40, 30, 0.0, 10, "Weapon crits grant 3 charges of +30% attack haste for 10 turns, replacing rather than stacking with Warrior Flurry."],
	"static_shock_1": ["Static Shock", "Shaman", 80, 0, 0.2, 0, "Landed primary weapon attacks have a 20% chance to discharge a Lightning Shield charge, ignoring its retaliation cooldown."],
	"elemental_weapons_1": ["Elemental Weapons", "Shaman", 100, 40, 0.0, 0, "Windfury bonus damage increases 40%; Strength of Earth grants 50% more Strength."],
	"elemental_assault_1": ["Elemental Assault", "Shaman", 140, 20, 0.0, 8, "Earth Shock deals 20% more damage. A weapon crit empowers the next Earth Shock by another 50% within 8 turns."],
	"spirit_hunt_1": ["Spirit Hunt", "Shaman", 180, 50, 0.0, 0, "Spirit wolves heal you for 50% of their actual damage dealt."],
	"elemental_warding_1": ["Elemental Warding", "Shaman", 200, 15, 0.0, 0, "Take 15% less nonphysical damage."],
	"toughness_1": ["Toughness", "Shaman", 220, 20, 0.0, 0, "+20% armor."],
	"improved_earth_shock_1": ["Improved Earth Shock", "Shaman", 240, 1, 0.0, 1, "Earth Shock cooldown is 1 turn shorter; its interrupt also stuns for 1 enemy turn."],
	"benediction_1": ["Benediction", "Paladin", 20, 20, 0.0, 0, "Paladin actives cost 20% less rage, rounded up."],
	"conviction_1": ["Conviction", "Paladin", 40, 3, 0.0, 0, "+3% weapon and direct Holy/Nature critical chance."],
	"vengeance_1": ["Vengeance", "Paladin", 80, 3, 0.0, 10, "Primary attack crits grant +3% damage, stacking 3 times for 10 turns."],
	"art_of_war_1": ["Art of War", "Paladin", 100, 3, 0.0, 10, "Every third landed primary Holy event guarantees your next Judgement crit for 10 turns. At most one event counts per world-turn action, including Seal damage."],
	"heart_of_the_crusader_1": ["Heart of the Crusader", "Paladin", 140, 3, 0.0, 10, "Landed Judgement gives +3% critical chance against that enemy for 10 turns."],
	"divine_purpose_1": ["Divine Purpose", "Paladin", 160, 0, 0.15, 8, "Landed Judgement has a 15% chance to make the next Judgement free within 8 turns."],
	"pursuit_of_justice_1": ["Pursuit of Justice", "Paladin", 180, 20, 0.0, 0, "+20% movement credit: periodically move an extra tile in the chosen direction, stopping at obstacles."],
	"eye_for_an_eye_1": ["Eye for an Eye", "Paladin", 200, 30, 0.0, 0, "Surviving an incoming critical hit reflects 30% of damage taken as Holy damage. Reflections cannot proc."],
	"guardians_favor_1": ["Guardian's Favor", "Paladin", 220, 10, 0.0, 1, "Divine Shield cooldown is 10 turns shorter and its duration is 1 turn longer."],
	"sacred_duty_1": ["Sacred Duty", "Paladin", 240, 0, 0.25, 8, "Landed Judgement has a 25% chance to guarantee the next Judgement crit within 8 turns."],
	"sanctity_of_battle_1": ["Sanctity of Battle", "Paladin", 260, 35, 0.0, 0, "Judgement deals +35 Holy damage. Its cooldown is divided by current attack haste, rounded up to at least 1 turn."],
	"opportunity_1": ["Opportunity", "Rogue", 20, 20, 0.0, 0, "Direct physical actives deal 20% more damage from behind."],
	"ambidexterity_1": ["Ambidexterity", "Rogue", 40, 25, 0.0, 0, "Raises off-hand weapon damage from 50% to 75% in any class. Dual-wield pairs are always usable; off-hand swings grant no ordinary rage."],
	"combat_potency_1": ["Combat Potency", "Rogue", 100, 5, 0.2, 0, "Landed ordinary off-hand swings have a 20% chance to grant 5 rage."],
	"seal_fate_1": ["Seal Fate", "Rogue", 120, 1, 0.0, 0, "Direct active crits grant one additional combo point after Relentless Assault. Finishers and bonus strikes do not qualify."],
	"main_gauche_1": ["Main Gauche", "Rogue", 140, 100, 0.15, 0, "Landed main-hand swings have a 15% chance for an off-hand bonus strike. Requires an off-hand weapon; no recursive procs or rage."],
	"restless_blades_1": ["Restless Blades", "Rogue", 180, 1, 0.0, 0, "Finishers reduce remaining offensive and defensive ability cooldowns by 1 turn per 2 points spent, rounded up."],
	"bandits_guile_1": ["Bandit's Guile", "Rogue", 200, 5, 0.0, 12, "Every 4 landed direct active attacks grant +5% damage, up to 15%, for 12 turns. Misses and finishers do not advance it."],
	"ruthlessness_1": ["Ruthlessness", "Rogue", 220, 1, 0.6, 0, "After a finisher spends points, 60% chance to refund 1 combo point."],
	"relentless_strikes_1": ["Relentless Strikes", "Rogue", 240, 15, 0.2, 0, "Finishers have a 20% chance per point spent to refund 15 rage, after spending."],
	"precision_1": ["Precision", "Rogue", 260, 5, 0.0, 0, "+5% weapon and direct Holy/Nature hit chance."],
}
const ACTIVES: Dictionary = {
	"whirlwind_1": {"title": "Whirlwind", "class_tab": "Warrior", "progress_required": 200, "rage_cost": 25, "cooldown_seconds": 8, "weapon_multiplier": 1.0, "family": "whirlwind", "effect": "TOOLKIT", "target": "NONE", "range_tiles": 1, "detail": "One weapon attack against each adjacent enemy in stable actor order. Each landed hit can crit/proc and build combo points. Stops on terminal death; one class XP use."},
	"windfury_weapon_1": {"title": "Windfury Weapon", "class_tab": "Shaman", "progress_required": 60, "rage_cost": 10, "duration": 30, "coefficient": 0.2, "weapon_multiplier": 1.0, "family": "windfury_weapon", "effect": "ARMOR", "target": "SELF", "detail": "Enchant the current main-hand weapon for 30 turns. Landed primary main-hand swings/physical actives have 20% chance for 2 weapon bonus strikes, at most once per 3 turns. Bonuses do not proc or grant rage/combo points."},
	"earth_shock_1": {"title": "Earth Shock", "class_tab": "Shaman", "progress_required": 120, "rage_cost": 15, "cooldown_seconds": 7, "range_tiles": 3, "weapon_multiplier": 1.0, "minimum": 24, "school": 3, "family": "earth_shock", "effect": "TOOLKIT", "target": "ENEMY", "detail": "100% weapon damage + 24 as Nature damage; hit/crit apply, armor does not. Interrupts and delays the enemy's next swing by 1 turn. One turn; a landed attack builds combo points."},
	"feral_spirit_1": {"title": "Feral Spirit", "class_tab": "Shaman", "progress_required": 160, "rage_cost": 25, "cooldown_seconds": 30, "duration": 12, "minimum": 50, "weapon_multiplier": 0.5, "family": "feral_spirit", "effect": "TOOLKIT", "target": "NONE", "detail": "Summon 2 wolves on free adjacent tiles for 12 turns, replacing your wolves. Each has 50 health and strikes every 2 turns for 50% of your weapon damage at summoning. They follow your selected enemy, grant no XP/rage/points and can be attacked. Requires 2 free or replaceable tiles."},
	"blessing_of_might_1": {"title": "Blessing of Might", "class_tab": "Paladin", "progress_required": 60, "rage_cost": 10, "duration": 30, "minimum": 6, "family": "blessing_of_might", "effect": "ARMOR", "target": "SELF", "detail": "+6 Strength for 30 turns. Stacks with Battle Shout and Strength of Earth."},
	"divine_shield_1": {"title": "Divine Shield", "class_tab": "Paladin", "progress_required": 120, "rage_cost": 20, "cooldown_seconds": 30, "duration": 3, "minimum": 30, "family": "divine_shield", "effect": "ARMOR", "target": "SELF", "detail": "Immune to all incoming damage for 3 turns; deal 30% less damage. Costs one action; weapon timing continues. Guardian's Favor extends it."},
	"evasion_1": {"title": "Evasion", "class_tab": "Rogue", "progress_required": 60, "rage_cost": 15, "cooldown_seconds": 20, "duration": 5, "minimum": 40, "family": "evasion", "effect": "ARMOR", "target": "SELF", "detail": "+40% dodge for 5 turns, including attacks from behind. Costs one action."},
	"instant_poison_1": {"title": "Instant Poison", "class_tab": "Rogue", "progress_required": 80, "rage_cost": 10, "duration": 30, "minimum": 8, "coefficient": 0.3, "family": "instant_poison", "effect": "ARMOR", "target": "SELF", "detail": "Coat your current main/off-hand weapons for 30 turns. Each landed primary weapon attack has 30% chance to add 8 Nature damage. Bonus strikes cannot trigger poison."},
	"eviscerate_1": {"title": "Eviscerate", "class_tab": "Rogue", "progress_required": 160, "rage_cost": 15, "range_tiles": 1, "weapon_multiplier": 0.75, "minimum": 12, "family": "eviscerate", "effect": "TOOLKIT", "target": "ENEMY", "detail": "Requires points. Spend all held combo points for 75% weapon damage plus 12 per point as physical damage. Misses spend points/rage; finisher refunds follow spending. Builds no new attack points. One turn."},
}


static func ranks() -> Dictionary:
	var result := ACTIVES.duplicate(true)
	for identifier in PASSIVES:
		var row: Array = PASSIVES[identifier]
		result[identifier] = {"title": row[0], "class_tab": row[1],
			"progress_required": row[2], "minimum": row[3], "coefficient": row[4],
			"duration": row[5], "detail": "Passive: " + row[6],
			"family": String(identifier).trim_suffix("_1"), "effect": "PASSIVE", "target": "NONE"}
	for row: Dictionary in result.values():
		row["rank"] = 1
		row["training_level"] = 1
	return result
