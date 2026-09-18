# GDScript coding style

Use the [official GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) as the style authority and the [official Godot demo projects](https://github.com/godotengine/godot-demo-projects) as examples. Select documentation and samples matching the pinned Godot version. Use this document for explicit project conventions.

## Formatting and naming

- Use UTF-8, LF line endings, a final newline, and tabs for indentation.
- Use `snake_case` for script filenames, functions, variables, and signals.
- Use `PascalCase` for class and node names; use `CONSTANT_CASE` for constants and enum values.
- Use double-quoted strings unless single quotes avoid escaping.
- Keep lines readable; the official guide recommends 100 characters as the normal limit.
- Follow the guide's declaration order: annotations and class declaration; signals, enums and constants; variables; initialization and lifecycle callbacks; other methods; inner classes. Put public members before private members within the appropriate group.
- Prefix internal members with `_`. Use concise comments to explain intent or constraints.

## Project conventions

Use typed GDScript by default. Declare parameter and return types, including `void`. Use inference when the type is clear at the declaration; otherwise name the type explicitly. Keep `Variant` where the API or data actually requires it.

Prefer clear domain names such as `experience_to_next_level` over abbreviations. Name units where ambiguity matters, for example `cooldown_seconds`.

Follow existing scene organization. Introduce a helper, Resource type, signal, or additional node only when it makes the current behaviour easier to express or maintain. Do not add a global manager or event bus by default.

Keep gameplay calculations easy to test without introducing a framework for testing. Use named constants or existing data resources for gameplay values where that improves readability and tuning.

Avoid unrelated formatting changes. Keep GUT test names descriptive of the behaviour under test.

## Small example

The numbers and behaviour here illustrate style only; they are not game requirements.

```gdscript
class_name ExperienceProgress
extends RefCounted

var current_experience: int = 0


func add_experience(amount: int) -> void:
	current_experience += amount


func has_enough_experience(required_experience: int) -> bool:
	return current_experience >= required_experience
```
