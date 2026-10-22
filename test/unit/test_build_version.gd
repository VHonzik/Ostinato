extends GutTest

var _path: String


func before_each() -> void:
	_path = "user://test_build_version_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func test_exported_version_uses_embedded_tag_and_commit_without_git() -> void:
	_write(JSON.stringify({"version": "v0.1.0-rc.1", "commit": "0123456789abcdef0123456789abcdef01234567"}))
	assert_eq(BuildVersion.display_text(_path), "v0.1.0-rc.1 (0123456)")


func test_missing_or_invalid_metadata_preserves_development_version() -> void:
	var development := "0.1." + BuildVersion.short_commit()
	assert_eq(BuildVersion.display_text(_path), development)
	for contents in ["{invalid", "[]", '{"version": 3, "commit": "broken"}',
		'{"version": "v0.1.0", "commit": ""}']:
		_write(contents)
		assert_eq(BuildVersion.display_text(_path), development)


func _write(contents: String) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
