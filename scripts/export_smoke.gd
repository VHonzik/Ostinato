class_name ExportSmoke
extends RefCounted

## Explicit packaged-game check; ordinary launches never enter this path.
static func run(main: Node) -> void:
	var tree := main.get_tree()
	var expected_root := OS.get_environment("OSTINATO_SMOKE_ROOT").replace("\\", "/")
	var user_directory := OS.get_user_data_dir().replace("\\", "/")
	if (expected_root.is_empty() or not user_directory.begins_with(expected_root + "/")
		or DisplayServer.get_name() != "headless"):
		_fail(main, "Smoke checks require headless mode and isolated user data.")
		return
	if OS.is_debug_build():
		_fail(main, "The package is a debug build.")
		return
	var expected_version := "%s (%s)" % [OS.get_environment("OSTINATO_EXPECTED_VERSION"),
		OS.get_environment("OSTINATO_EXPECTED_COMMIT").left(7)]
	if BuildVersion.display_text() != expected_version:
		_fail(main, "Exported version metadata is missing or incorrect.")
		return
	for excluded in ["res://test", "res://bench", "res://tools", "res://addons", "res://.git", "res://mobile"]:
		if DirAccess.dir_exists_absolute(excluded):
			_fail(main, "Development content included: " + excluded)
			return
	var game := main.get_node("GameContainer/GameViewport/Gameplay") as Gameplay
	if game == null or not game.menu.visible:
		_fail(main, "Exported main menu did not open.")
		return
	game.start_new_game()
	await tree.process_frame
	if not game.active_game or game.world.actors.is_empty() or game.session.development_build:
		_fail(main, "New Game did not create the release valley.")
		return
	for skill in game.world.hero.learned_skills:
		if skill.development_only:
			_fail(main, "Development abilities are available in the release package.")
			return
	var saves := SaveStore.new()
	if not saves.save_slot(game.session, 1) or not saves.load_slot(game.session, 1):
		_fail(main, "Exported save/load failed: " + saves.last_error)
		return
	main.free()
	await tree.process_frame
	print("PASS: exported Windows game.")
	tree.quit()


static func _fail(main: Node, message: String) -> void:
	var tree := main.get_tree()
	printerr(message)
	main.free()
	tree.quit(1)
