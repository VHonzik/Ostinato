extends GutTest

var _viewport: SubViewport
var _main: Control


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 540)
	add_child_autofree(_viewport)
	var main_scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	assert_not_null(main_scene, "The configured startup scene must load.")
	if main_scene == null:
		return
	_main = main_scene.instantiate() as Control
	_viewport.add_child(_main)
	await get_tree().process_frame


func test_startup_shows_the_game_title() -> void:
	assert_not_null(_main, "Startup must create the main scene.")
	if _main == null:
		return
	var title := _main.get_node("Title") as Label
	assert_true(_main.is_node_ready(), "The main scene must finish initialization.")
	assert_true(title.is_visible_in_tree(), "The player must see the title.")
	assert_eq(title.text, "Ostinato")


func test_title_fits_after_resizing_to_a_smaller_window() -> void:
	assert_not_null(_main)
	if _main == null:
		return
	_viewport.size = Vector2i(640, 360)
	await get_tree().process_frame
	var title := _main.get_node("Title") as Label
	var visible_area := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	assert_true(title.is_visible_in_tree(), "The resized title stays visible.")
	assert_true(visible_area.encloses(title.get_global_rect()), "The title stays inside the window.")
	assert_true(title.size.x >= title.get_minimum_size().x, "The title text must not be clipped.")
