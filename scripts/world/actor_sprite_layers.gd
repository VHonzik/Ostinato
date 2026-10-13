class_name ActorSpriteLayers
extends Resource

@export var base_sprite: Texture2D
@export var faction_sprite: Texture2D


func _init(base: Texture2D = null, faction: Texture2D = null) -> void:
	base_sprite = base
	faction_sprite = faction
