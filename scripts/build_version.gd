class_name BuildVersion
extends RefCounted


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
