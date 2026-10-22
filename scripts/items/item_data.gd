class_name ItemData
extends RefCounted

const WAR_HORN_ID: int = 71001
const WAR_HORN_HOTBAR_ID: StringName = &"item_war_horn"
const LUCKY_CHARM_ID: int = 71002
const BROKEN_LUCKY_CHARM_ID: int = 71003
const ANCESTRAL_TOTEM_ID: int = 71004
const ANCESTRAL_TOTEM_HOTBAR_ID: StringName = &"item_ancestral_totem"
const WAR_BANNER_ID: int = 71005
const WAR_BANNER_HOTBAR_ID: StringName = &"item_war_banner"
const POTION_HOTBAR_ID: StringName = &"potion_118"
const HOTBAR_ITEMS: Dictionary[StringName, int] = {
	&"food_117": 117, POTION_HOTBAR_ID: 118,
	&"food_2070": 2070, &"food_4536": 4536, &"food_4540": 4540,
	WAR_HORN_HOTBAR_ID: WAR_HORN_ID, ANCESTRAL_TOTEM_HOTBAR_ID: ANCESTRAL_TOTEM_ID,
	WAR_BANNER_HOTBAR_ID: WAR_BANNER_ID,
}
const ELEMENTAL_DAMAGE_MIN: float = 2.0
const ELEMENTAL_DAMAGE_MAX: float = 4.0
const ELEMENTAL_SWING_TURNS: float = 2.5


## Compact equipment setups and valley supplies.
const ITEMS: Dictionary = {
	"71005": {
		"title": "Wartorn Banner", "quality": 1, "slot": "",
		"level": 1, "stack": 1, "buy": 0, "sell": 0, "armor": 0,
		"two_handed": false, "unique": true, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "war_banner", "quest": "", "tradable": false,
		"duration": 10, "radius": 3, "reduction_percent": 10,
		"note": "Single use. No rage cost; one turn. Place a nonblocking banner on a free adjacent tile for 10 turns. You and friendly summons within 3 tiles take 10% less damage. Leaving range immediately removes protection. Lost on Loop reset.",
	},
	"71004": {
		"title": "Ancestral totem", "quality": 1, "slot": "",
		"level": 1, "stack": 1, "buy": 0, "sell": 0, "armor": 0,
		"two_handed": false, "unique": true, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "ancestral_totem", "quest": "", "tradable": false,
		"summon_health": 40, "taunt_range": 4, "summon_title": "Earth Elemental",
		"note": "Single use. No rage cost; one turn. Summons a mobile Earth Elemental with 40 health until killed or Loop reset. It follows you or an engaged foe and taunts already engaged hostiles within 4 tiles and sight of itself. Attacks for 2-4 physical damage every 2.5 turns. Requires a free adjacent tile and no living elemental. Lost on Loop reset.",
	},
	"71002": {
		"title": "Lucky charm", "quality": 1, "slot": "",
		"level": 1, "stack": 1, "buy": 0, "sell": 0, "armor": 0,
		"two_handed": false, "unique": true, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "", "tradable": false,
		"note": "Passive while in Bags. When a hit would kill you, leaves you at 1 HP and becomes a Broken lucky charm. Protects against one hit only. Lost on Loop reset.",
	},
	"71003": {
		"title": "Broken lucky charm", "quality": 0, "slot": "",
		"level": 1, "stack": 1, "buy": 0, "sell": 0, "armor": 0,
		"two_handed": false, "unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "", "tradable": false,
		"note": "Broken. Has no effect. Lost on Loop reset.",
	},
	"71001": {
		"title": "War Horn", "quality": 1, "slot": "",
		"level": 1, "stack": 1, "buy": 0, "sell": 0, "armor": 0,
		"two_handed": false, "unique": true, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "war_horn", "quest": "", "tradable": false,
		"cast_turns": 2, "cooldown": 30,
		"note": "Reusable. Deal exactly 1 damage to every neutral or hostile NPC on screen and in sight, engaging them. No attack procs or combo points; keeps your attack target. 2-turn cast; 30-turn cooldown after completion. Lost on Loop reset.",
	},
	"35": {
		"title": "Bent Staff", "quality": 0, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 10,
		"sell": 2, "armor": 0, "two_handed": true,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 3, "maximum": 5, "interval": 2.9,
		"stats": {}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "two_hand",
	},
	"2139": {
		"title": "Balanced Daggers", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 2, "maximum": 4, "interval": 1.6,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "dual_wield", "off_minimum": 2,
		"off_maximum": 4, "off_interval": 1.6,
	},
	"2129": {
		"title": "Guard Sword and Shield", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 40, "two_handed": false,
		"unique": false, "weapon": true, "shield": true,
		"minimum": 3, "maximum": 5, "interval": 2.4,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "shield_pair",
	},
	"85": {
		"title": "Patrol Armor", "quality": 1, "slot": "armor",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 90, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"2572": {
		"title": "Runed Linen Armor", "quality": 2, "slot": "armor",
		"level": 5, "stack": 1, "buy": 300,
		"sell": 30, "armor": 130, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"strength": 2, "stamina": 1, "crit": 1.0, "haste": 5.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"117": {
		"title": "Tough Jerky", "quality": 1, "slot": "",
		"level": 1, "stack": 20, "buy": 5,
		"sell": 1, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "food", "quest": "",
		"tradable": true, "restore": 61, "duration": 18,
	},
	"118": {
		"title": "Minor Healing Potion", "quality": 1, "slot": "",
		"level": 1, "stack": 5, "buy": 20,
		"sell": 5, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "health", "quest": "",
		"tradable": true, "restore_min": 30, "restore_max": 40,
		"cooldown": 120,
	},
	"7073": {
		"title": "Broken Fang", "quality": 0, "slot": "",
		"level": 0, "stack": 5, "buy": 25,
		"sell": 6, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "",
		"tradable": true,
	},
	"7074": {
		"title": "Chipped Claw", "quality": 0, "slot": "",
		"level": 0, "stack": 5, "buy": 16,
		"sell": 4, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "",
		"tradable": true,
	},
	"4865": {
		"title": "Ruined Pelt", "quality": 0, "slot": "",
		"level": 0, "stack": 5, "buy": 20,
		"sell": 5, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "",
		"tradable": true,
	},
	"750": {
		"title": "Tough Wolf Meat", "quality": 1, "slot": "",
		"level": 0, "stack": 20, "buy": 0,
		"sell": 0, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "wolves",
		"tradable": false,
	},
	"4560": {
		"title": "Fine Scimitar", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 40, "two_handed": false,
		"unique": false, "weapon": true, "shield": true,
		"minimum": 3, "maximum": 5, "interval": 2.4,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "shield_pair",
	},
	"70001": {
		"title": "Patrol Amulet", "quality": 1, "slot": "neck",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"stamina": 1, "haste": 2.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70002": {
		"title": "Steady Band", "quality": 1, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"strength": 1, "crit": 1.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70003": {
		"title": "Quick Band", "quality": 1, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"agility": 1, "haste": 2.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70011": {
		"title": "Amber Amulet", "quality": 2, "slot": "neck",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"stamina": 2, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70012": {
		"title": "Wolfstone Ring", "quality": 2, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"strength": 2, "crit": 2.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70013": {
		"title": "Leafstone Ring", "quality": 2, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"agility": 2, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70021": {
		"title": "Oakheart Staff", "quality": 2, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 30, "armor": 0, "two_handed": true,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 7, "maximum": 11, "interval": 2.9,
		"stats": {"strength": 2, "crit": 1.0, "haste": 4.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "two_hand",
	},
	"70022": {
		"title": "Sentinel Sword and Shield", "quality": 2, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 30, "armor": 70, "two_handed": false,
		"unique": false, "weapon": true, "shield": true,
		"minimum": 6, "maximum": 9, "interval": 2.4,
		"stats": {"strength": 2, "crit": 1.0, "haste": 4.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "shield_pair",
	},
	"70023": {
		"title": "Briar Daggers", "quality": 2, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 30, "armor": 0, "two_handed": false,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 3, "maximum": 6, "interval": 1.6,
		"stats": {"strength": 2, "crit": 1.0, "haste": 4.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "dual_wield", "off_minimum": 3,
		"off_maximum": 6, "off_interval": 1.6,
	},
}


static func hotbar_id(item_id: int) -> StringName:
	for identifier in HOTBAR_ITEMS:
		if HOTBAR_ITEMS[identifier] == item_id:
			return identifier
	return &""


static func is_consumable_hotbar(identifier: StringName) -> bool:
	return (HOTBAR_ITEMS.has(identifier)
		and get_item(HOTBAR_ITEMS[identifier]).use in ["food", "health"])


static func ancestral_totem_action() -> SkillDefinition:
	var item := get_item(ANCESTRAL_TOTEM_ID)
	var action := SkillDefinition.new(ANCESTRAL_TOTEM_HOTBAR_ID, item.title, &"", 1,
		item.note, SkillDefinition.Effect.SUMMON)
	action.family = &"ancestral_totem"
	action.minimum = item.summon_health
	action.range_tiles = item.taunt_range
	return action


static func war_horn_action() -> SkillDefinition:
	var item := get_item(WAR_HORN_ID)
	var action := SkillDefinition.new(WAR_HORN_HOTBAR_ID, item.title, &"", 1,
		item.note, SkillDefinition.Effect.TOOLKIT)
	action.family = &"war_horn"
	action.cast_seconds = item.cast_turns
	action.cooldown_seconds = item.cooldown
	action.minimum = 1
	return action


static func get_item(identifier: int) -> Dictionary:
	return ITEMS.get(str(identifier), NorthshireItems.ITEMS.get(str(identifier),
		ClassItems.ITEMS.get(str(identifier), MerchantItems.ITEMS.get(str(identifier),
		LootItems.ITEMS.get(str(identifier), {})))))


static func instance(identifier: int, quantity: int = 1, starter: bool = false) -> Dictionary:
	return {"id": identifier, "quantity": quantity, "starter": starter}


static func describe(identifier: int) -> String:
	var item := get_item(identifier)
	var detail := "%s / %s" % [item.title,
		slot_name(item.slot) if item.slot != "" else "Item"]
	if int(item.armor) != 0:
		detail += " / armor %d" % item.armor
	if item.weapon:
		detail += " / " + String(item.weapon_style).replace("_", " ")
		detail += " / %.0f–%.0f damage, %.1fs" % [item.minimum, item.maximum, item.interval]
		if item.weapon_style == "dual_wield":
			detail += " / off-hand %.0f–%.0f damage, %.1fs" % [
				item.off_minimum, item.off_maximum, item.off_interval]
	for stat in item.stats:
		if float(item.stats[stat]) == 0.0:
			continue
		if stat in ["crit", "haste"]:
			detail += " / +%.2f%% %s" % [item.stats[stat], stat]
		else:
			detail += " / +%d %s" % [item.stats[stat], stat]
	if item.two_handed:
		detail += " / two hands"
	if item.use != "" and item.use not in ["war_horn", "ancestral_totem", "war_banner"]:
		detail += " / restores " + String(item.use)
	if item.has("note"):
		detail += " / " + String(item.note)
	return detail


static func slot_name(slot: String) -> String:
	return "Outfit" if slot == "armor" else slot.replace("_", " ").capitalize()


static func color_name(text: String, identifier: int) -> String:
	var item := get_item(identifier)
	return text.replace(String(item.title), "[color=#%s]%s[/color]" % [
		quality_color(int(item.quality)).to_html(false), item.title])


static func describe_rich(identifier: int, equipped_id: int = 0) -> String:
	var item := get_item(identifier)
	var parts := describe(identifier).split(" / ")
	parts[0] = color_name(parts[0], identifier)
	if equipped_id == 0:
		return " / ".join(parts)
	var equipped := get_item(equipped_id)
	if item.slot != equipped.slot or item.slot == "":
		return " / ".join(parts)
	var stats: Dictionary = item.stats.duplicate()
	for stat in equipped.stats:
		if not stats.has(stat):
			stats[stat] = 0
	for stat in stats:
		var value := float(item.stats.get(stat, 0))
		var baseline := float(equipped.stats.get(stat, 0))
		var delta := value - baseline
		if is_zero_approx(delta):
			continue
		var percentage: bool = stat in ["crit", "haste"]
		var difference := _difference(delta, percentage,
			String(stat) if is_zero_approx(value) or is_zero_approx(baseline) else "")
		var found := false
		for index in range(2, parts.size()):
			if parts[index].ends_with(" " + String(stat)):
				parts[index] += " " + difference
				found = true
				break
		if not found:
			parts.append(difference)
	var armor_delta := int(item.armor) - int(equipped.armor)
	if armor_delta != 0:
		var difference := _difference(armor_delta, false,
			"armor" if item.armor == 0 or equipped.armor == 0 else "")
		if item.armor == 0:
			parts.append(difference)
		else:
			parts[2] += " " + difference
	return " / ".join(parts)


static func _difference(value: float, percentage: bool, stat: String) -> String:
	var amount := "%+.2f%%" % value if percentage else "%+d" % int(value)
	if stat != "":
		amount += " " + stat
	return "[color=#%s](%s)[/color]" % ["66ee88" if value > 0 else "ff6464", amount]


static func quality_name(quality: int) -> String:
	return ["Poor (gray)", "Common (white)", "Uncommon (green)"][quality]


static func quality_color(quality: int) -> Color:
	return [Color("9d9d9d"), Color.WHITE, Color("1eff00")][quality]
