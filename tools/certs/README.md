# Validation certificates

`ca-bundle.crt` is an unmodified copy of the Mozilla CA bundle shipped in the pinned
Godot source. Its source URL and SHA-256 are in [versions.json](../versions.json).
Validation verifies the hash before launching Godot and requires no download.

Copyright Mozilla Contributors; licensed under MPL-2.0. The license text is included
in [Godot's copyright notices](../../licenses/GODOT-COPYRIGHT.txt).

Validation uses this bundle for both import and game startup, avoiding Windows'
certificate store. The `ostinato_validation` custom feature is enabled only in
validation child processes. Normal editor launches and exported games use their
usual certificate settings. Update this bundle and its pin deliberately alongside
the engine, preserving its upstream notices and LF line endings.
