class_name NpcConversation
extends RefCounted

enum Action { QUEST, SELECT_CLASS, REFERRAL, SPARE_GEAR, TRADE, TRAIN, WAR_HORN, LUCKY_CHARM, ANCESTRAL_TOTEM, WAR_BANNER }

const TRAINER_GIFT_DIALOGUE: String = "I have nothing to teach you anymore you have to venture forth. Here is a small something for your journey..."

static var _services: Dictionary[StringName, Service] = {
	&"Marshal": Marshal.new(),
	&"Trader": Trader.new(),
}
static var _trainer := Trainer.new()

var greeting: String
var lines: PackedStringArray = []
var choices: Array[Choice] = []
var keep_open: bool = false


## Building or refreshing choices is read-only. Interaction entry records talking separately.
static func build(session: GameSession, actor: GridActor) -> NpcConversation:
	var world := session.world
	if actor == null or not QuestRules.in_range(world, actor, actor.npc_id):
		return null
	var conversation := NpcConversation.new()
	conversation.greeting = NpcDefinition.greeting_for(actor.npc_id)
	if world.valley_route and not world.class_selected:
		conversation.keep_open = true
		if actor.npc_id == NpcDefinition.MARSHAL_ID:
			_services[&"Marshal"].append_choices(conversation, session, actor)
		else:
			conversation.greeting = "Hello stranger, you should go say hi to Marshal in front of the abbey."
		return conversation
	for identifier in QuestData.QUESTS:
		var quest: Dictionary = QuestData.QUESTS[identifier]
		var prefix := ""
		if QuestRules.available(world, identifier) and int(quest.giver) == actor.npc_id:
			prefix = "! "
		elif (world.quests.has(identifier) and not world.quests[identifier].handed_in
			and int(quest.receiver) == actor.npc_id):
			prefix = "? "
		if prefix != "":
			var choice := Choice.new(quest.title, Action.QUEST)
			choice.quest_id = identifier
			choice.quest_prefix = prefix
			conversation.choices.append(choice)
			conversation.keep_open = true
	var service: Service = _services.get(actor.service)
	if service == null and actor.service in ClassSkillData.PLAYABLE_CLASSES:
		service = _trainer
	if service != null:
		conversation.keep_open = true
		service.append_choices(conversation, session, actor)
	return conversation


func offers(choice: Choice) -> bool:
	for current in choices:
		if (current.action == choice.action and current.quest_id == choice.quest_id
			and current.category == choice.category):
			return true
	return false


class Choice:
	extends RefCounted

	var title: String
	var action: Action
	var tooltip: String = ""
	var quest_id: String = ""
	var quest_prefix: String = ""
	var category: StringName = &""

	func _init(text: String, command: Action) -> void:
		title = text
		action = command


class Service:
	extends RefCounted

	func append_choices(_conversation: NpcConversation, _session: GameSession,
		_actor: GridActor) -> void:
		pass


class Marshal extends Service:
	func append_choices(conversation: NpcConversation, session: GameSession,
		_actor: GridActor) -> void:
		var world := session.world
		if session.loop_count == 1 and not world.starter_gear_received:
			conversation.lines.append("Janos Hammerknuckle inside the abbey can give you spare arms and armor for free.")
		if session.loop_count > 1 and (world.class_selected or world.ever_accepted_quest):
			conversation.lines.append("Advancing %s this Loop. Class choice is locked until death."
				% world.hero.selected_class)
		elif session.loop_count > 1 and not session.can_select_class():
			conversation.lines.append("Return outside combat to choose your class before accepting a quest.")
		if session.can_select_class():
			for category: StringName in session.selectable_classes():
				var title := "I am %s" % String(category).to_lower()
				if not world.chosen_classes.has(category):
					title = "I am .... %s" % String(category).to_lower()
				var choice := Choice.new(title, Action.SELECT_CLASS)
				choice.category = category
				conversation.choices.append(choice)
		elif (not world.class_selected and not world.ever_accepted_quest
			and world.hero.selected_class == &"Warrior" and not world.trainer_referral_received):
			conversation.choices.append(Choice.new(
				"It's been a long journey, is there a warrior master?", Action.REFERRAL))


class Trader extends Service:
	func append_choices(conversation: NpcConversation, session: GameSession,
		actor: GridActor) -> void:
		if session.world.can_receive_starter_gear(actor):
			conversation.choices.append(Choice.new("Do you have any spare gear for %s?" %
				String(session.world.hero.selected_class).to_lower(),
				Action.SPARE_GEAR))
		conversation.choices.append(Choice.new("Trade", Action.TRADE))


class Trainer extends Service:
	func append_choices(conversation: NpcConversation, session: GameSession,
		actor: GridActor) -> void:
		if session.world.can_receive_war_horn(actor):
			conversation.choices.append(Choice.new(TRAINER_GIFT_DIALOGUE, Action.WAR_HORN))
		elif session.world.can_receive_lucky_charm(actor):
			conversation.choices.append(Choice.new(TRAINER_GIFT_DIALOGUE, Action.LUCKY_CHARM))
		elif session.world.can_receive_ancestral_totem(actor):
			conversation.choices.append(Choice.new(TRAINER_GIFT_DIALOGUE, Action.ANCESTRAL_TOTEM))
		elif session.world.can_receive_war_banner(actor):
			conversation.choices.append(Choice.new(TRAINER_GIFT_DIALOGUE, Action.WAR_BANNER))
		for skill in SkillDefinition.trainer_skills(actor.service):
			if session.world.hero.find_skill(skill.id) == null:
				var choice := Choice.new("Train", Action.TRAIN)
				choice.category = actor.service
				conversation.choices.append(choice)
				break
