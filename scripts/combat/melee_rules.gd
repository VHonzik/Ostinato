class_name MeleeRules
extends RefCounted

## Physical attack outcomes and weapon damage.
const LEVEL_MISS_PERCENT: float = 2.0
const LEVEL_CRITICAL_PERCENT: float = 1.0
const LEVEL_DAMAGE_STEP: float = 0.12
const MAX_LEVEL_DAMAGE_ADJUSTMENT: float = 0.9


static func miss_chance(attacker: MeleeProfile, defender: MeleeProfile) -> float:
	if attacker.cannot_miss:
		return 0.0
	var base := minf(95.0, 5.0 + maxi(0, defender.level - attacker.level) * LEVEL_MISS_PERCENT)
	return clampf(base - attacker.hit, 0.0, 100.0)


static func critical_chance(attacker: MeleeProfile, defender: MeleeProfile) -> float:
	return clampf(attacker.critical + (attacker.level - defender.level)
		* LEVEL_CRITICAL_PERCENT, 0.0, 100.0)


static func level_damage_multiplier(attacker_level: int, defender_level: int) -> float:
	var gap := attacker_level - defender_level
	# Equal percentage increases and reductions; bound both before damage can turn negative.
	var adjustment := clampf(gap * LEVEL_DAMAGE_STEP,
		-MAX_LEVEL_DAMAGE_ADJUSTMENT, MAX_LEVEL_DAMAGE_ADJUSTMENT)
	return 1.0 + adjustment


static func outcome(
	attacker: MeleeProfile, defender: MeleeProfile, roll: float,
	critical_bonus: int = 0
) -> StringName:
	var miss := miss_chance(attacker, defender)
	var dodge := 0.0 if attacker.ignores_dodge else defender.dodge
	var critical := critical_chance(attacker, defender) + critical_bonus
	var threshold := 0.0
	var chances: Array[float] = [miss, dodge, critical]
	var outcomes: Array[StringName] = [&"miss", &"dodge", &"critical"]
	for index in range(chances.size()):
		threshold += clampf(chances[index], 0.0, 100.0)
		if roll < threshold:
			return outcomes[index]
	return &"hit"


static func damage(
	attacker: MeleeProfile, defender: MeleeProfile, result: StringName,
	weapon_roll: float, weapon_multiplier: float = 1.0, flat_bonus: int = 0,
	damage_multiplier: float = 1.0
) -> int:
	if result in [&"miss", &"dodge"]:
		return 0
	var raw := weapon_damage(attacker, weapon_roll)
	var armor := maxf(0.0, defender.armor)
	var reduction := minf(0.75, armor / (armor + 400.0 + 85.0 * attacker.level))
	var adjusted := maxf(1.0, (raw * weapon_multiplier + flat_bonus)
		* attacker.damage_multiplier * damage_multiplier * (1.0 - reduction)
		* level_damage_multiplier(attacker.level, defender.level))
	var amount := round_weapon_damage(adjusted, attacker, weapon_roll)
	if result == &"critical":
		amount *= 2
	return amount


static func weapon_damage(attacker: MeleeProfile, roll: float) -> float:
	var bands := floori(attacker.damage_max - attacker.damage_min) + 1
	var band := mini(bands - 1, floori(clampf(roll, 0.0, 1.0) * bands))
	return attacker.damage_min + band + attacker.attack_power / 14.0 * attacker.interval


static func round_weapon_damage(amount: float, attacker: MeleeProfile, roll: float) -> int:
	# Within-band position is uniform and independent of the chosen weapon damage.
	# Reuse it for unbiased rounding without consuming extra combat randomness.
	var bands := floori(attacker.damage_max - attacker.damage_min) + 1
	var rounding_roll := fposmod(clampf(roll, 0.0, 0.999999999) * bands, 1.0)
	var result := floori(amount)
	if rounding_roll < amount - result:
		result += 1
	return result


static func kill_experience(player_level: int, npc_level: int) -> int:
	var gray := 0
	if player_level > 5 and player_level <= 39:
		gray = player_level - 5 - floori(player_level / 10.0)
	elif player_level <= 59 and player_level > 39:
		gray = player_level - 1 - floori(player_level / 5.0)
	elif player_level >= 60:
		# Pre-expansion level-60 boundary; continue the final band beyond it.
		gray = player_level - 13
	if npc_level <= gray:
		return 0
	var base := 45.0 + 5.0 * player_level
	if npc_level >= player_level:
		return roundi(base * (1.0 + 0.05 * mini(4, npc_level - player_level)))
	var zero_difference := 17
	var limits := [8, 10, 12, 16, 20, 30, 40, 45, 50, 55, 60]
	var differences := [5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16]
	for index in range(limits.size()):
		if player_level < limits[index]:
			zero_difference = differences[index]
			break
	return roundi(base * (1.0 - float(player_level - npc_level) / zero_difference))


static func direction_toward(offset: Vector2i) -> Vector2i:
	if offset == Vector2i.ZERO:
		return Vector2i.DOWN
	# Clockwise ties at half-sector boundaries; no random consumption.
	var sector := posmod(floori(Vector2(offset).angle() / (PI / 4.0) + 0.5), 8)
	return GridWorld.DIRECTIONS[(sector + 2) % 8]
