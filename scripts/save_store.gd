class_name SaveStore
extends RefCounted

## FR-039/040/041 and NFR-010/011/012: validate before replacing either file or world.
const SLOT_COUNT: int = 5
const MAX_BYTES: int = 8 * 1024 * 1024

var directory: String
var last_error: String = ""


func _init(save_directory: String = "user://saves") -> void:
	directory = save_directory


func slot_path(slot: int) -> String:
	return directory.path_join("slot_%d.json" % slot)


func metadata(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"status": "Invalid"}
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		var damaged := _damaged_file(slot)
		return {"status": "Empty"} if damaged == "" else {"status": "Damaged", "file": damaged}
	var record := _read(path)
	if record.is_empty():
		return {"status": "Damaged"}
	if not record.has_all(["family", "revision"]):
		return {"status": "Damaged"}
	if record.get("family") != "demo" or record.get("revision") != 1:
		return {"status": "Incompatible"}
	if (not record.get("timestamp") is String or not record.timestamp.ends_with("Z")
		or not record.get("data") is Dictionary
		or not SaveCodec._integer(record.data.get("loop"), 1)):
		return {"status": "Damaged"}
	return {"status": "Occupied", "timestamp": record.get("timestamp", ""),
		"loop": record.data.get("loop", 0)}


func save_slot(session: GameSession, slot: int, confirmed: bool = false) -> bool:
	last_error = ""
	if slot < 1 or slot > SLOT_COUNT or session.world == null:
		return _fail("No active game or invalid slot.")
	if not session.world.can_save():
		return _fail("Saving requires an action boundary outside combat.")
	if metadata(slot).status != "Empty" and not confirmed:
		return _fail("Confirm overwrite before saving to this slot.")
	var state := SaveCodec.capture(session)
	if SaveCodec.restore(state, session.development_build) == null:
		return _fail("Current game could not be validated; previous save preserved.")
	var record := {"family": "demo", "revision": 1,
		"timestamp": Time.get_datetime_string_from_system(true) + "Z", "data": state}
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return _fail("Cannot create save directory. Previous save preserved.")
	var path := slot_path(slot)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write save. Previous save preserved.")
	file.store_string(JSON.stringify(record))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return _fail("Save write failed. Previous save preserved.")
	var check := _read(temporary)
	if check.is_empty() or SaveCodec.restore(check.get("data"), session.development_build) == null:
		return _fail("Save verification failed. Previous save preserved.")
	# Godot's Windows rename replaces an existing destination in one OS operation.
	if DirAccess.rename_absolute(temporary, path) != OK:
		return _fail("Cannot replace save. Previous save preserved.")
	return true


func load_slot(session: GameSession, slot: int) -> bool:
	last_error = ""
	if slot < 1 or slot > SLOT_COUNT:
		return _fail("Invalid save slot.")
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return _fail("No save in this slot.")
	var record := _read(path)
	if record.has_all(["family", "revision"]) and (record.family != "demo" or record.revision != 1):
		return _fail("Incompatible save family or revision; file unchanged.")
	if (not record.has_all(["family", "revision", "timestamp"])
		or not record.timestamp is String
		or not record.timestamp.ends_with("Z")):
		return _preserve_damaged(path)
	var world := SaveCodec.restore(record.get("data"), session.development_build)
	if world == null:
		return _preserve_damaged(path)
	session.restore(world, int(record.data.seed), int(record.data.loop))
	return true


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _preserve_damaged(path: String) -> bool:
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var suffix := Crypto.new().generate_random_bytes(8).hex_encode()
	var retained := path + ".damaged-" + stamp + "-" + suffix
	if DirAccess.rename_absolute(path, retained) != OK:
		return _fail("Damaged save could not be renamed; original file left in place.")
	return _fail("Damaged save preserved as " + retained.get_file())


func _damaged_file(slot: int) -> String:
	if not DirAccess.dir_exists_absolute(directory):
		return ""
	var prefix := "slot_%d.json.damaged-" % slot
	for file in DirAccess.get_files_at(directory):
		if file.begins_with(prefix):
			return file
	return ""


func _fail(message: String) -> bool:
	last_error = message
	return false
