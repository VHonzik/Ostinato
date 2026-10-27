extends GridWorld
## Experiment-local stats; Fel Breath and weapon timing remain production behavior.

var profile: Dictionary = {}


func _spawn_stalker(entry: Vector2i) -> void:
	super._spawn_stalker(entry)
	apply_profile(actors.back(), profile)


static func apply_profile(actor: GridActor, stats: Dictionary) -> void:
	actor.max_health = int(stats.health)
	actor.health = actor.max_health
	actor.melee.damage_min = float(stats.minimum)
	actor.melee.damage_max = float(stats.maximum)
