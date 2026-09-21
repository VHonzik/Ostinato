class_name GridView
extends Node2D

const TILE_SIZE: int = 16
const CHARACTERS: Texture2D = preload(
	"res://assets/spritesheets/scroolospritescharacters_nobg.png"
)
const ENVIRONMENT: Texture2D = preload(
	"res://assets/spritesheets/scroolospritesenvironment_nobg.png"
)

var world: GridWorld
var selected: GridActor
var alternate_palette: bool = false


static func tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE_SIZE) + Vector2.ONE * (TILE_SIZE / 2.0)


func _draw() -> void:
	if world == null:
		return
	for y in range(world.bounds.position.y, world.bounds.end.y):
		for x in range(world.bounds.position.x, world.bounds.end.x):
			var tile := Vector2i(x, y)
			var rectangle := Rect2(Vector2(tile * TILE_SIZE), Vector2.ONE * TILE_SIZE)
			var shade := Color("#243b35") if (x + y) % 2 == 0 else Color("#263e37")
			if x in range(18, 23) or y in range(13, 16):
				shade = Color("#494637") if (x + y) % 2 == 0 else Color("#454333")
			draw_rect(rectangle, shade)
			if x in range(22, 33) and y in range(15, 24):
				draw_rect(rectangle.grow(-1), Color("#314e3d"))
			if world.blocked_tiles.has(tile):
				draw_rect(rectangle.grow(-1), Color("#172923"))
				var source := Vector2i(0, 0) if x < 15 and y < 13 else Vector2i(3, 4)
				draw_texture_rect_region(
					ENVIRONMENT, rectangle, Rect2(Vector2(source * 16), Vector2(16, 16)),
					Color("#9baf8b")
				)
	# Corpses remain visible under living occupants.
	for actor in world.actors:
		if not actor.alive and actor.corpse_visible:
			var center := tile_center(actor.tile)
			draw_line(center + Vector2(-5, 2), center + Vector2(5, 2), Color("#a09a81"), 2)
			draw_line(center + Vector2(-2, -1), center + Vector2(2, 5), Color("#a09a81"), 2)
	for actor in world.actors:
		if actor.alive:
			var color: Color = [Color("#9acd95"), Color("#e8c979"), Color("#ee7871")][actor.relationship]
			if alternate_palette:
				color = [Color("#56B4E9"), Color("#F0E442"), Color("#D55E00")][actor.relationship]
			_draw_character(actor.tile, Vector2i(0, 0), color)
			var center := tile_center(actor.tile)
			draw_line(center, center + Vector2(actor.facing) * 6, color, 1)
			if actor.health < actor.max_health:
				draw_rect(Rect2(center + Vector2(-7, -9), Vector2(14, 2)), Color("#382524"))
				draw_rect(Rect2(center + Vector2(-7, -9),
					Vector2(14.0 * actor.health / actor.max_health, 2)), color)
	if selected != null:
		var selection := Rect2(Vector2(selected.tile * TILE_SIZE), Vector2(16, 16))
		draw_rect(selection.grow(2), Color.WHITE, false, 1)
	var player_rect := Rect2(Vector2(world.player_tile * TILE_SIZE), Vector2(16, 16))
	draw_rect(player_rect.grow(1), Color("#83c5cf"), false, 1)
	_draw_character(world.player_tile,
		Vector2i(4, 0) if world.hero.selected_class == &"Druid" else Vector2i(3, 0),
		Color("#d8f2ef"))


func _draw_character(tile: Vector2i, source: Vector2i, color: Color) -> void:
	var rectangle := Rect2(Vector2(tile * TILE_SIZE), Vector2(16, 16))
	draw_rect(Rect2(rectangle.position + Vector2(3, 13), Vector2(10, 2)), Color("#12251f"))
	draw_texture_rect_region(
		CHARACTERS, rectangle, Rect2(Vector2(source * 16), Vector2(16, 16)), color
	)
