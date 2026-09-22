class_name MeleeRules
extends RefCounted

## DATA-002: mage versus unshielded beasts, one physical white-attack table.
static func outcome(
	attacker: MeleeProfile, defender: MeleeProfile, behind: bool, roll: float
) -> StringName:
	var difference := 5 * (defender.level - attacker.level)
	var miss := 5.0 + difference * 0.04
	if not defender.player and difference > 0:
		miss = 5.0 + mini(difference, 10) * 0.1 + maxi(0, difference - 10) * 0.6
	miss -= attacker.hit
	var parry := 0.0 if behind or defender.parry <= 0 else defender.parry + difference * 0.04
	var block := 0.0 if behind or defender.block <= 0 else defender.block + difference * 0.04
	var dodge := defender.dodge + difference * (
		0.1 if not defender.player and difference > 0 else 0.04
	)
	if defender.player and behind:
		dodge = 0.0
	var glance := 0.0
	if attacker.player and not defender.player and defender.level > 10:
		glance = mini(attacker.level, 30) + difference * 2.0
	var critical := attacker.critical - difference * (0.04 if defender.player else 0.2)
	var crush := 0.0
	if not attacker.player and difference <= -15:
		crush = -2.0 * difference - 15.0
	var threshold := 0.0
	var chances: Array[float] = [miss, dodge, parry, block, glance, critical, crush]
	var outcomes: Array[StringName] = [&"miss", &"dodge", &"parry", &"block", &"glancing", &"critical", &"crushing"]
	for index in range(chances.size()):
		threshold += clampf(chances[index], 0.0, 100.0)
		if roll < threshold:
			return outcomes[index]
	return &"hit"


static func damage(
	attacker: MeleeProfile, defender: MeleeProfile, result: StringName,
	weapon_roll: float, glance_roll: float
) -> int:
	if result in [&"miss", &"dodge", &"parry"]:
		return 0
	var bonus := attacker.attack_power / 14.0 * attacker.interval
	var minimum := floori(attacker.damage_min + bonus)
	var maximum := floori(attacker.damage_max + bonus)
	var raw := minimum + mini(maximum - minimum, floori(weapon_roll * (maximum - minimum + 1)))
	var armor := maxf(0.0, defender.armor)
	var reduction := minf(0.75, armor / (armor + 400.0 + 85.0 * attacker.level))
	var amount := maxi(1, floori(raw * (1.0 - reduction)))
	match result:
		&"critical":
			amount *= 2
		&"crushing":
			amount = floori(amount * 1.5)
		&"glancing":
			var difference := 5 * (defender.level - attacker.level)
			var high := clampf(0.9 - 0.03 * difference, 0.2, 0.99)
			var low := clampf(0.6 - 0.05 * difference, 0.01, minf(0.6, high))
			amount = floori(amount * lerpf(low, high, glance_roll))
	if result == &"block":
		amount = maxi(0, amount - defender.block_value)
	return amount


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


static func facing_toward(offset: Vector2i) -> Vector2i:
	if offset == Vector2i.ZERO:
		return Vector2i.DOWN
	# Clockwise ties at half-sector boundaries; no random consumption.
	var sector := posmod(floori(Vector2(offset).angle() / (PI / 4.0) + 0.5), 8)
	return GridWorld.DIRECTIONS[(sector + 2) % 8]


static func is_behind(facing: Vector2i, offset: Vector2i) -> bool:
	return Vector2(facing).dot(Vector2(facing_toward(offset))) < 0
