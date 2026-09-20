class_name MeleeProfile
extends RefCounted

## Single-weapon physical subset; provenance in docs/data/melee-baseline.md.
var level: int = 1
var player: bool = false
var armor: int = 0
var attack_power: int = 0
var damage_min: float = 1.0
var damage_max: float = 2.0
var interval: float = 2.0
var critical: float = 5.0
var dodge: float = 5.0
