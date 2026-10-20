class_name SkillButton
extends Button

## Shared readable skill tooltip and Godot drag source for the spell book.
var skill: SkillDefinition
var hero: HeroState
var drag_enabled: bool = false
var highlight_colors: Array[Color] = []


func set_highlights(colors: Array[Color], hints: PackedStringArray) -> void:
	highlight_colors.assign(colors)
	if not hints.is_empty():
		tooltip_text += "\n" + "\n".join(hints)
	queue_redraw()


func describe(skill_data: SkillDefinition, owner_hero: HeroState) -> void:
	skill = skill_data
	hero = owner_hero
	tooltip_text = "" if skill == null else "%s · %d %s\n%s" % [
		skill.title, skill.cost(hero), skill.resource_name(), skill.description]
	if skill != null and skill.family == &"lava_burst":
		var stacks := ClassToolkitRules.maelstrom_stacks(hero)
		var passive := hero.find_skill(&"maelstrom_weapon_1")
		tooltip_text += "\nNow: %s / %d Maelstrom / +%d percentage points crit." % [
			"instant (one action)" if passive != null and stacks == passive.maximum else
				"%d-turn cast" % int(ClassToolkitRules.cast_duration(hero, skill)),
			stacks, stacks * (passive.critical_percent if passive != null else 0)]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or disabled or skill == null:
		return null
	var preview := Label.new()
	preview.text = skill.title
	preview.add_theme_font_size_override("font_size", 18)
	set_drag_preview(preview)
	return {"skill_id": skill.id, "hero": hero}


func _make_custom_tooltip(for_text: String) -> Object:
	var label := RichTextLabel.new()
	label.text = for_text
	label.custom_minimum_size.x = 420
	label.size.x = 420
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	return label


func _draw() -> void:
	if highlight_colors.is_empty():
		return
	# Two-pixel inside border; split its edges when both crit and cost are ready.
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var first := highlight_colors[0]
	var last := highlight_colors[-1]
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), first, 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, first, 2.0)
	draw_line(rect.end, Vector2(rect.position.x, rect.end.y), last, 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.position, last, 2.0)
