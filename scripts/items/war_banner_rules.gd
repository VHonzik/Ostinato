class_name WarBannerRules
extends RefCounted


static func active(world: GridWorld) -> bool:
	return not world.war_banner.is_empty() and int(world.war_banner.until) > world.turn_count


static func placement(world: GridWorld) -> Vector2i:
	for direction in GridWorld.DIRECTIONS:
		var tile := world.player_tile + direction
		if world.is_open(tile):
			return tile
	return Vector2i(-1, -1)


static func protects(world: GridWorld, target: GridActor = null) -> bool:
	if not active(world):
		return false
	if target != null and (not target.alive or target.summon_kind == ""
		or target.relationship != GridActor.Relationship.FRIENDLY):
		return false
	var tile := world.player_tile if target == null else target.tile
	return GridWorld.tile_distance(world.war_banner.tile, tile) <= int(
		ItemData.get_item(ItemData.WAR_BANNER_ID).radius)
