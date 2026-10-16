extends "res://bench/paladin_sim.gd"


func _initialize() -> void:
	builds = ["Rogue", "Warrior+Rogue", "All"]
	selected_class = &"Rogue"
	super._initialize()
