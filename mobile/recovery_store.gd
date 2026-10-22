class_name MobileRecoveryStore
extends RefCounted

var store: SaveStore
var last_error: String = ""
var _snapshot: String = ""


func _init(directory: String = "user://recovery") -> void:
	store = SaveStore.new(directory)


func path() -> String:
	return store.directory.path_join("recovery.json")


func checkpoint(session: GameSession) -> bool:
	if session.world == null or not session.world.can_save():
		return true
	var snapshot := JSON.stringify(SaveCodec.capture(session))
	if snapshot == _snapshot:
		return true
	if not store.save_path(session, path()):
		last_error = store.last_error
		return false
	_snapshot = snapshot
	last_error = ""
	return true


func metadata(session: GameSession) -> Dictionary:
	if not FileAccess.file_exists(path()):
		return {"status": "Empty"}
	var record := store._read(path())
	if record.get("family") != "demo" or record.get("revision") != SaveStore.REVISION:
		return {"status": "Incompatible" if record.has("family") else "Damaged"}
	if (not record.get("timestamp") is String or not record.timestamp.ends_with("Z")
		or SaveCodec.restore(record.get("data"), session.development_build) == null):
		return {"status": "Damaged"}
	return {"status": "Occupied", "loop": record.data.loop, "turn": record.data.world.turn_count}


func restore(session: GameSession) -> bool:
	if not store.load_path(session, path()):
		last_error = store.last_error
		_snapshot = ""
		return false
	_snapshot = JSON.stringify(SaveCodec.capture(session))
	last_error = ""
	return true


func invalidate() -> bool:
	_snapshot = ""
	if FileAccess.file_exists(path()) and DirAccess.remove_absolute(path()) != OK:
		last_error = "Could not clear completed recovery save."
		return false
	last_error = ""
	return true
