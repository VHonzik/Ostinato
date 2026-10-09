class_name SkillButton
extends Button

## Shared readable rank tooltip and Godot drag source for the spell book.
var skill: SkillRank
var hero: HeroState
var drag_enabled: bool = false


func describe(rank_data: SkillRank, owner_hero: HeroState) -> void:
	skill = rank_data
	hero = owner_hero
	tooltip_text = "" if skill == null else "%s · Rank %d · %d mana\n%s" % [
		skill.title, skill.rank, skill.cost(hero), skill.description]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or disabled or skill == null:
		return null
	var preview := Label.new()
	preview.text = "%s · Rank %d" % [skill.title, skill.rank]
	preview.add_theme_font_size_override("font_size", 12)
	set_drag_preview(preview)
	return {"skill_id": skill.id, "hero": hero}


func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 300
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	return label
