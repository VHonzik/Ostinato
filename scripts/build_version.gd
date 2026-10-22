class_name BuildVersion
extends RefCounted


static func display_text(metadata_path: String = "res://build_info.json") -> String:
	if FileAccess.file_exists(metadata_path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(metadata_path)) == OK:
			if json.data is Dictionary:
				var metadata: Dictionary = json.data
				var version: Variant = metadata.get("version")
				var commit: Variant = metadata.get("commit")
				if (version is String and not version.is_empty() and commit is String
					and commit.length() == 40 and commit.is_valid_hex_number()):
					return "%s (%s)" % [version, commit.left(7)]
	return "0.1." + short_commit()


static func short_commit() -> String:
	# Editor and wrapper launches both show the checked-out commit, including after a commit.
	var head_path := "res://.git/HEAD"
	if not FileAccess.file_exists(head_path):
		return "xxx"
	var head := FileAccess.get_file_as_string(head_path).strip_edges()
	if head.begins_with("ref: "):
		var reference := head.trim_prefix("ref: ")
		var path := "res://.git/" + reference
		if FileAccess.file_exists(path):
			head = FileAccess.get_file_as_string(path).strip_edges()
		elif FileAccess.file_exists("res://.git/packed-refs"):
			for line in FileAccess.get_file_as_string("res://.git/packed-refs").split("\n"):
				if line.ends_with(" " + reference):
					head = line.get_slice(" ", 0)
					break
	return head.left(7) if head.is_valid_hex_number() else "xxx"
