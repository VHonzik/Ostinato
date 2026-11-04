class_name QuestData
extends RefCounted

## Offer, unfinished and completed dialogue for the playable valley quests.
const DIALOGUE: Dictionary = {
	"valley_training_shaman": ["You seek shaman training? Just speak to me, always happy to help. For the right price of course.","Speak to me if you wish to train, shaman.","Put these new skills to good use and come back anytime."],
	"valley_training_rogue": ["You seek rogue training? Just speak to me, always happy to help. For the right price of course.","Speak to me if you wish to train, rogue.","Put these new skills to good use and come back anytime."],
	"valley_training_paladin": ["You seek paladin training? Just speak to me, always happy to help. For the right price of course.","Speak to me if you wish to train, paladin.","Put these new skills to good use and come back anytime."],
	"valley_training_warrior": ["You seek warrior training? Just speak to me, always happy to help. For the right price of course.","Speak to me if you wish to train, warrior.","Put these new skills to good use and come back anytime."],
	"valley_fresh_start": ["You look like you had rough day my friend. Give me a second, I can find something suitable for you.","","This should do nicely!"],
	"valley_wolves": ["The wolves are encroaching the western woods. We need to thin their number.","Are the western paths safer? Watch for the larger timber wolves.","Nicely done. Here, take these supplies."],
	"valley_camp": ["Kobolds are flooding from the north. Clear their camps before they grow bolder.","Have you cleared the kobolds from the northern camp?","That will show them, here is your reward."],
	"valley_mine": ["With the camp cleared, the kobolds far north in the Echo Ridge mine are our next target. Enter the mine and drive out their workers and laborers.","What news from Echo Ridge? We need those kobolds driven out.","You have bought us some breathing room. Take this weapon; you have earned it."],
	"valley_vineyard": ["Garrick and his thugs have taken my vineyard. Drive them out so we can harvest grapes.","Is Garrick gone? His thugs will stay while he leads them.","Thank you my dear. Please take this, it was my late husband."],
	"valley_explore": ["I need fresh eyes on the valley. Scout Echo Ridge to north, the vineyard to south-east and the western woods, then report back.","Have you seen all three places? I need the whole picture.","Kobolds, thieves and wolves. Trouble on every side—but now we know where we stand. Thank you."],
}

## Valley objectives and fixed common gear rewards; historical fixture quests below.
static var QUESTS: Dictionary = {
	"valley_training_warrior": {
		"title": "Warrior Training", "level": 2, "minimum": 1, "previous": [],
		"giver": 911, "receiver": 911, "category": "Warrior",
		"objectives": [QuestObjective.train(&"Warrior")],
		"xp": 50, "copper": 0, "rewards": [], "choices": [], "source_item": 0,
	},
	"valley_training_paladin": {
		"title": "Paladin Training", "level": 2, "minimum": 1, "previous": [],
		"giver": 925, "receiver": 925, "category": "Paladin",
		"objectives": [QuestObjective.train(&"Paladin")],
		"xp": 50, "copper": 0, "rewards": [], "choices": [], "source_item": 0,
	},
	"valley_training_rogue": {
		"title": "Rogue Training", "level": 2, "minimum": 1, "previous": [],
		"giver": 915, "receiver": 915, "category": "Rogue",
		"objectives": [QuestObjective.train(&"Rogue")],
		"xp": 50, "copper": 0, "rewards": [], "choices": [], "source_item": 0,
	},
	"valley_training_shaman": {
		"title": "Shaman Training", "level": 2, "minimum": 1, "previous": [],
		"giver": 900002, "receiver": 900002, "category": "Shaman",
		"objectives": [QuestObjective.train(&"Shaman")],
		"xp": 50, "copper": 0, "rewards": [], "choices": [], "source_item": 0,
	},
	"valley_fresh_start": {
		"title": "Fresh Start", "level": 1, "minimum": 1, "previous": [],
		"giver": 900003, "receiver": 900003, "category": "",
		"objectives": [], "xp": 50, "copper": 0, "rewards": [], "choices": [], "source_item": 0,
	},
	"valley_wolves": {
		"title": "Wolves of the Western Woods", "level": 2, "minimum": 1, "previous": [],
		"giver": 197, "receiver": 197, "category": "",
		"objectives": [QuestObjective.kill(299, 8), QuestObjective.kill(69, 5)],
		"xp": 800, "copper": 0, "rewards": [85, 70001], "choices": [], "source_item": 0,
	},
	# Keep existing revision-28 quest records finishable without converting their progress.
	"valley_patrol": {
		"title": "The Western Path", "level": 1, "minimum": 1, "previous": [],
		"giver": 197, "receiver": 197, "category": "",
		"objectives": [QuestObjective.kill(299, 8)],
		"xp": 300, "copper": 0, "rewards": [85], "choices": [], "source_item": 0,
	},
	"valley_timber_wolves": {
		"title": "Timber Wolves of the Western Woods", "level": 2, "minimum": 1,
		"previous": ["valley_patrol"], "giver": 197, "receiver": 197, "category": "",
		"objectives": [QuestObjective.kill(69, 5)],
		"xp": 500, "copper": 0, "rewards": [70001], "choices": [], "source_item": 0,
	},
	"valley_camp": {
		"title": "The Northern Camp", "level": 2, "minimum": 1, "previous": [],
		"giver": 197, "receiver": 197, "category": "",
		"objectives": [QuestObjective.kill(6, 4)],
		"xp": 750, "copper": 50, "rewards": [70002, 2224], "choices": [], "source_item": 0,
	},
	"valley_mine": {
		"title": "Into Echo Ridge", "level": 3, "minimum": 2, "previous": [],
		"giver": 197, "receiver": 197, "category": "",
		"objectives": [QuestObjective.kill(257, 2),
			QuestObjective.kill(80, 1)],
		"xp": 1200, "copper": 100, "rewards": [5579], "choices": [], "source_item": 0,
	},
	"valley_vineyard": {
		"title": "Milly's Vineyard", "level": 4, "minimum": 2, "previous": [],
		"giver": 9296, "receiver": 9296, "category": "",
		"objectives": [QuestObjective.kill(38, 4),
			QuestObjective.kill(103, 1)],
		"xp": 800, "copper": 100, "rewards": [5580], "choices": [], "source_item": 0,
	},
	"valley_explore": {
		"title": "Around the Valley", "level": 3, "minimum": 2, "previous": [],
		"giver": 823, "receiver": 823, "category": "",
		"objectives": [QuestObjective.location(&"mine", 1),
			QuestObjective.location(&"vineyard", 1),
			QuestObjective.location(&"wolf_woods", 1)],
		"xp": 1100, "copper": 0, "rewards": [70003], "choices": [], "source_item": 0,
	},
	"6": {
		"title": "Bounty on Garrick Padfoot",
		"level": 5,
		"minimum": 2,
		"previous": [
			"18"
		],
		"giver": 823,
		"receiver": 823,
		"category": "",
		"objectives": [
			QuestObjective.loot(182, 1)
		],
		"xp": 340,
		"copper": 0,
		"choices": [
			6076,
			60,
			3070
		],
		"source_item": 0
	},
	"7": {
		"title": "Kobold Camp Cleanup",
		"level": 2,
		"minimum": 1,
		"previous": [
			"783"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			QuestObjective.kill(6, 10)
		],
		"xp": 170,
		"copper": 25,
		"choices": [],
		"source_item": 0
	},
	"15": {
		"title": "Investigate Echo Ridge",
		"level": 3,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			QuestObjective.kill(257, 10)
		],
		"xp": 250,
		"copper": 40,
		"choices": [],
		"source_item": 0
	},
	"18": {
		"title": "Brotherhood of Thieves",
		"level": 4,
		"minimum": 2,
		"previous": [
			"783"
		],
		"giver": 823,
		"receiver": 823,
		"category": "",
		"objectives": [
			QuestObjective.loot(752, 12)
		],
		"xp": 360,
		"copper": 0,
		"choices": [
			2224,
			5580,
			1161,
			5579,
			1159
		],
		"source_item": 0
	},
	"21": {
		"title": "Skirmish at Echo Ridge",
		"level": 5,
		"minimum": 1,
		"previous": [
			"15"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			QuestObjective.kill(80, 12)
		],
		"xp": 450,
		"copper": 0,
		"choices": [
			2186,
			2691,
			11192
		],
		"source_item": 0
	},
	"wolves": {
		"title": "Wolves Across the Border",
		"level": 2,
		"minimum": 1,
		"previous": [
			"5261"
		],
		"giver": 196,
		"receiver": 196,
		"category": "",
		"objectives": [
			QuestObjective.loot(750, 8)
		],
		"xp": 170,
		"copper": 0,
		"choices": [
			80,
			6070
		],
		"source_item": 0
	},
	"783": {
		"title": "A Threat Within",
		"level": 1,
		"minimum": 1,
		"previous": [],
		"giver": 823,
		"receiver": 197,
		"category": "",
		"objectives": [
			QuestObjective.talk(197, 1)
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3903": {
		"title": "Milly Osworth",
		"level": 4,
		"minimum": 2,
		"previous": [
			"wolves"
		],
		"giver": 823,
		"receiver": 9296,
		"category": "",
		"objectives": [
			QuestObjective.talk(9296, 1)
		],
		"xp": 35,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3904": {
		"title": "Milly's Harvest",
		"level": 4,
		"minimum": 2,
		"previous": [
			"3903"
		],
		"giver": 9296,
		"receiver": 9296,
		"category": "",
		"objectives": [
			QuestObjective.loot(11119, 8)
		],
		"xp": 180,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3905": {
		"title": "Grape Manifest",
		"level": 4,
		"minimum": 2,
		"previous": [
			"3904"
		],
		"giver": 9296,
		"receiver": 952,
		"category": "",
		"objectives": [
			QuestObjective.loot(11125, 1),
			QuestObjective.talk(952, 1)
		],
		"xp": 360,
		"copper": 0,
		"choices": [
			11475,
			2690
		],
		"source_item": 11125
	},
	"5261": {
		"title": "Eagan Peltskinner",
		"level": 2,
		"minimum": 1,
		"previous": [
			"783"
		],
		"giver": 823,
		"receiver": 196,
		"category": "",
		"objectives": [
			QuestObjective.talk(196, 1)
		],
		"xp": 85,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"gate_survey": {
		"title": "Watch the Northshire Gate",
		"level": 2,
		"minimum": 1,
		"previous": [
			"783"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			QuestObjective.location(&"gate_overlook", 1),
			QuestObjective.talk(823, 1)
		],
		"xp": 85,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3101": {
		"title": "Consecrated Letter",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 925,
		"category": "Paladin",
		"objectives": [
			QuestObjective.talk(925, 1)
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 9570
	},
	"shaman_referral": {
		"title": "A Shaman at the Abbey",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 900002,
		"category": "Shaman",
		"objectives": [
			QuestObjective.talk(900002, 1)
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 0
	}
}


static func dialogue(identifier: String, stage: int) -> String:
	if DIALOGUE.has(identifier):
		return DIALOGUE[identifier][stage]
	# Historical fixture quests retain their objective-driven detail screens.
	return ""
